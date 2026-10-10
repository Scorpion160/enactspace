"""Human rubric: authenticated journeys, evidence, legacy preservation, and no inferred ranking."""
import unittest
from types import SimpleNamespace
from copy import deepcopy
import test_attachments_lifecycle as fixture
from app.models.recruitment import ApplicationReview, RecruitmentCampaign
from app.services.recruitment_rubric import VERSION, RUBRIC, assess_ratings, structured_summary

def assessment(rating=3):
    return {"rubric_version":VERSION, "ratings":[
        {"criterion_id":c["id"], "rating":rating, "evidence":"Exemple concret de la réponse, à discuter avec le jury."}
        for c in RUBRIC["criteria"]]}

class RubricUnitTests(unittest.TestCase):
    def test_equal_weights_with_observations(self):
        snapshot, score = assess_ratings(assessment()["ratings"])
        self.assertEqual(score,15)
        self.assertEqual(structured_summary([SimpleNamespace(criteria_assessment=snapshot)])["screening_score"],75)
        self.assertEqual(len(RUBRIC["criteria"]),5)
        self.assertTrue(all(len(c["anchors"])==5 for c in RUBRIC["criteria"]))

    def test_missing_information_is_not_zero(self):
        for invalid in [[], assessment()["ratings"][:-1], [{**r,"rating":None} for r in assessment()["ratings"]]]:
            with self.assertRaises(ValueError): assess_ratings(invalid)
        self.assertIsNone(structured_summary([])["screening_score"])

    def test_rejects_duplicate_unknown_boolean_fraction_and_missing_evidence(self):
        for mutate in [
            lambda rows: rows.__setitem__(4,deepcopy(rows[0])),
            lambda rows: rows[0].update(criterion_id="appearance"),
            lambda rows: rows[0].update(criterion_id={"invalid":1}),
            lambda rows: rows[0].update(rating=True),
            lambda rows: rows[0].update(rating=2.5),
            lambda rows: rows[0].update(rating=5),
            lambda rows: rows[0].update(evidence="   "),
        ]:
            rows=assessment()["ratings"];mutate(rows)
            with self.assertRaises(ValueError): assess_ratings(rows)

    def test_legacy_scores_and_other_versions_do_not_enter_the_new_index(self):
        rows=[SimpleNamespace(score=20,criteria_assessment=None),
              SimpleNamespace(score=20,criteria_assessment={**assessment(4),"rubric_version":"other"}),
              SimpleNamespace(score=0,criteria_assessment=assessment(2))]
        result=structured_summary(rows)
        self.assertEqual((result["screening_score"],result["screening_review_count"]),(50,1))

    def test_spread_exposes_disagreement_without_deciding_admission(self):
        result=structured_summary([SimpleNamespace(criteria_assessment=assessment(v)) for v in [1,4]])
        self.assertEqual(result,{"screening_score":62.5,"screening_review_count":2,"screening_spread":75})
        self.assertNotIn("recommendation",result)
        self.assertNotIn("status",result)

class RecruitmentRubricHttpTests(unittest.TestCase):
    make_task=fixture.AttachmentLifecycleTests.make_task
    as_user=fixture.AttachmentLifecycleTests.as_user
    call=fixture.AttachmentLifecycleTests.call
    campaign=fixture.AttachmentLifecycleTests.campaign
    application_payload=fixture.AttachmentLifecycleTests.application_payload
    def setUp(self):
        fixture.AttachmentLifecycleTests.setUp(self)
        self.item=self.campaign()
        response=self.client.post('/api/recruitment/applications',json=self.application_payload(self.item))
        self.assertEqual(response.status_code,200,response.text)
        self.id=response.json()['id'];self.path='/api/recruitment/applications/'+self.id
        self.as_user('sg')
    def tearDown(self):fixture.AttachmentLifecycleTests.tearDown(self)
    def review(self,rating=3,**changes):
        payload={"application_id":self.id,"score":20,"recommendation":"reserve","criteria_assessment":assessment(rating)}
        payload.update(changes)
        return self.client.post('/api/recruitment/reviews',json=payload)
    def detail(self):return self.client.get(self.path).json()
    def test_server_computes_score_from_human_criteria_and_freezes_version(self):
        response=self.review(1);self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(response.json()['score'],5)
        self.assertEqual(self.detail()['screening_score'],25)
        self.assertEqual(self.detail()['screening_review_count'],1)
        self.assertEqual(self.detail()['status'],'submitted')
        self.db.refresh(self.item);self.assertEqual(self.item.screening_rubric_version,VERSION)
    def test_two_people_and_repeat_submission_count_distinct_reviewers(self):
        for _ in range(2):self.assertEqual(self.review(2).status_code,200)
        self.as_user('tl')
        response=self.review(4);self.assertEqual(response.status_code,200,response.text)
        body=self.detail();self.assertEqual(body['screening_review_count'],2)
        self.assertEqual(body['screening_score'],75)
        self.assertEqual(body['screening_spread'],50)
        self.assertEqual(body['final_score'],15)
    def test_scalar_legacy_review_stays_identifiable_and_does_not_rank_candidate(self):
        response=self.review(criteria_assessment=None,score=19)
        self.assertEqual(response.status_code,200,response.text)
        body=self.detail();self.assertIsNone(body['screening_score'])
        self.assertEqual(body['final_score'],19)
        self.assertEqual(body['screening_review_count'],0)
        self.as_user('tl');self.assertEqual(self.review(2).status_code,200)
        self.assertEqual(self.detail()['final_score'],10)
        self.assertEqual(self.db.query(ApplicationReview).count(),2)
    def test_incomplete_invalid_or_wrong_version_is_not_saved(self):
        for data in [assessment(),{**assessment(),"rubric_version":"invalid"}]:
            if data['rubric_version']==VERSION:data['ratings'][0]['evidence']=''
            response=self.review(criteria_assessment=data)
            self.assertEqual(response.status_code,422,response.text)
        self.assertEqual(self.db.query(ApplicationReview).count(),0)
        self.assertIsNone(self.detail()['screening_score'])
    def test_old_client_cannot_erase_structured_assessment(self):
        saved=self.review(3).json()
        self.assertEqual(self.review(criteria_assessment=None).status_code,409)
        response=self.client.patch('/api/recruitment/reviews/'+saved['id'],json={"score":20})
        self.assertEqual(response.status_code,409,response.text)
        self.assertEqual(self.detail()['screening_score'],75)
    def test_scalar_nan_and_out_of_range_are_rejected(self):
        for score in [-1,21,"NaN","Infinity"]:
            response=self.review(criteria_assessment=None,score=score)
            self.assertIn(response.status_code,[400,422],response.text)
        self.assertEqual(self.db.query(ApplicationReview).count(),0)
    def test_regular_member_cannot_read_or_write_evaluations(self):
        self.as_user('b')
        self.assertEqual(self.review().status_code,403)
        self.assertEqual(self.client.get(self.path).status_code,403)


    def test_own_review_is_restored_only_for_its_reviewer(self):
        saved=self.review(2).json()
        self.assertEqual(self.detail()['my_review']['id'],saved['id'])
        self.assertEqual(self.detail()['my_review']['criteria_assessment'],assessment(2))
        self.as_user('tl')
        self.assertIsNone(self.detail()['my_review'])

    def test_patch_delete_and_list_use_the_same_human_index(self):
        saved=self.review(1).json()
        changed=self.client.patch('/api/recruitment/reviews/'+saved['id'],
            json={'criteria_assessment':assessment(4),'score':1})
        self.assertEqual(changed.status_code,200,changed.text)
        self.assertEqual(changed.json()['score'],20)
        self.assertEqual(self.detail()['screening_score'],100)
        listed=self.client.get('/api/recruitment/applications').json()
        self.assertEqual(listed[0]['screening_score'],100)
        self.as_user('tl')
        self.assertEqual(self.review(2).status_code,200)
        self.assertEqual(self.detail()['screening_score'],75)
        self.as_user('sg')
        deleted=self.client.delete('/api/recruitment/reviews/'+saved['id'])
        self.assertEqual(deleted.status_code,200,deleted.text)
        self.assertEqual(self.detail()['screening_score'],50)
        self.assertEqual(self.detail()['screening_review_count'],1)

    def test_identity_and_answer_length_do_not_change_entered_judgment(self):
        self.assertEqual(self.review(3).status_code,200)
        before=self.detail()['screening_score']
        from app.models.recruitment import Application
        item=self.db.query(Application).first()
        item.study_level='DIC3';item.gender='autre';item.department='Autre département'
        item.motivation='Très long texte. '*200;item.availability='10';self.db.commit()
        self.assertEqual(self.detail()['screening_score'],before)

class MigrationPreservationTests(unittest.TestCase):
    def test_upgrade_is_idempotent_and_preserves_old_rows_and_downgrade(self):
        import importlib.util
        from pathlib import Path
        import sqlalchemy as sa
        from alembic.migration import MigrationContext
        from alembic.operations import Operations
        path=Path(__file__).parent/'alembic/versions/20261006_0023_recruitment_rubric.py'
        spec=importlib.util.spec_from_file_location('rubric_migration',path)
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        engine=sa.create_engine('sqlite://')
        with engine.begin() as db:
            db.execute(sa.text('CREATE TABLE recruitment_campaigns (id INTEGER PRIMARY KEY, title TEXT)'))
            db.execute(sa.text('CREATE TABLE application_reviews (id INTEGER PRIMARY KEY, score FLOAT, comment TEXT)'))
            db.execute(sa.text("INSERT INTO recruitment_campaigns VALUES (1, 'Campagne historique')"))
            db.execute(sa.text("INSERT INTO application_reviews VALUES (1, 17.5, 'Observation conservée')"))
            with Operations.context(MigrationContext.configure(db)):
                module.upgrade();module.upgrade()
                self.assertEqual(db.execute(sa.text('SELECT score,comment,criteria_assessment FROM application_reviews')).one(),
                                 (17.5,'Observation conservée',None))
                self.assertEqual(db.execute(sa.text('SELECT title,screening_rubric_version FROM recruitment_campaigns')).one(),
                                 ('Campagne historique',None))
                module.downgrade()
                self.assertEqual(db.execute(sa.text('SELECT score,comment FROM application_reviews')).one(),
                                 (17.5,'Observation conservée'))
        engine.dispose()

if __name__ == '__main__':unittest.main()
