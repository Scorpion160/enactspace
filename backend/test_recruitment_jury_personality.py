"""Campaign boundaries and candidate privacy, using only an isolated SQLite DB."""
from datetime import timedelta
from unittest import TestCase
from unittest.mock import patch
import uuid

import test_attachments_lifecycle as fixture
from app.core.config import settings
from app.core.time import utc_now
from app.models.pole import PoleMember
from app.models.recruitment import Application, ApplicationPersonality, ApplicationReview
from app.models.role import UserRole
from app.services.recruitment_personality import instrument, score


class RecruitmentJuryPersonalityTests(TestCase):
    setUp = fixture.AttachmentLifecycleTests.setUp
    tearDown = fixture.AttachmentLifecycleTests.tearDown
    as_user = fixture.AttachmentLifecycleTests.as_user
    make_task = fixture.AttachmentLifecycleTests.make_task
    campaign = fixture.AttachmentLifecycleTests.campaign
    application_payload = fixture.AttachmentLifecycleTests.application_payload

    def post(self, url, payload, code=200):
        response = self.client.post('/api/recruitment' + url, json=payload)
        self.assertEqual(response.status_code, code, response.text)
        return response.json()

    def application(self, campaign=None, **extra):
        campaign = campaign or self.campaign()
        body = dict(self.application_payload(campaign), **extra)
        return self.post('/applications', body)

    def appoint(self, campaign, who='b'):
        self.as_user('sg')
        return self.post(f'/campaigns/{campaign.id}/jury', {'user_id': str(self.users[who].id)})

    def prepare_assessment(self):
        app = self.application()
        self.as_user('sg')
        self.post(f"/applications/{app['id']}/status", {'status': 'under_review'})
        self.post(f"/applications/{app['id']}/personality/invite", {})
        credentials = {'application_id': app['tracking_code'], 'email': app['email']}
        return app, credentials, self.post('/personality/load', credentials)

    def answers(self, state, **extra):
        return dict(version=state['version'], revision=state['revision'], consent=True,
                    answers={item['id']: 4 for item in state['instrument']['items']},
                    scenario_answers={item['id']: 'Je vérifie les faits avec l’équipe et les personnes concernées.'
                                      for item in state['instrument']['scenarios']}, **extra)

    def test_uuid_shaped_tracking_code_can_load_and_save_candidate_questionnaire(self):
        app, credentials, state = self.prepare_assessment()
        row = self.db.get(Application, app['id'])
        row.tracking_code = uuid.uuid4().hex
        self.db.commit()
        credentials = dict(credentials, application_id=row.tracking_code.lower(), email=app['email'].upper())
        loaded = self.post('/personality/load', credentials)
        self.assertEqual(loaded['version'], state['version'])
        saved = self.post('/personality/save', dict(credentials, **self.answers(loaded)))
        self.assertEqual(saved['revision'], 1)
        self.assertEqual(self.db.query(ApplicationPersonality).count(), 1)
        self.post('/personality/load', dict(credentials, email='someone-else@example.org'), 404)

    def test_normal_tracking_and_legacy_identifiers_keep_the_same_email_boundary(self):
        app = self.application()
        for reference in (app['tracking_code'].lower(), app['id'], uuid.UUID(app['id']).hex):
            with self.subTest(reference=reference):
                tracked = self.post('/applications/track', {'application_id': ' ' + reference + ' ', 'email': app['email'].upper()})
                self.assertEqual(tracked['application_id'], app['id'])
                self.post('/applications/track', {'application_id': reference, 'email': 'someone-else@example.org'}, 404)

    def test_ambiguous_public_reference_does_not_choose_an_arbitrary_campaign(self):
        first = self.application()
        second = self.application(self.campaign())
        other = self.db.get(Application, second['id'])
        other.tracking_code = uuid.UUID(first['id']).hex
        self.db.commit()
        self.post('/applications/track', {'application_id': other.tracking_code, 'email': first['email']}, 404)
        # The explicit historical UUID still identifies only the first record.
        tracked = self.post('/applications/track', {'application_id': first['id'], 'email': first['email']})
        self.assertEqual(tracked['application_id'], first['id'])

    def test_alumni_only_assigned_campaign_is_visible_and_no_role_is_granted(self):
        one, two = self.campaign(), self.campaign()
        app, hidden = self.application(one), self.application(two, email='other@example.org')
        self.users['b'].status = 'alumni'
        self.db.commit()
        roles_before = self.db.query(UserRole).count()
        self.appoint(one)
        self.assertEqual(self.db.query(UserRole).count(), roles_before)
        self.as_user('b')
        self.assertEqual([row['id'] for row in self.client.get('/api/recruitment/campaigns').json()], [str(one.id)])
        self.assertEqual([row['id'] for row in self.client.get('/api/recruitment/applications').json()], [app['id']])
        for suffix in ('', '/reviews', '/personality'):
            self.assertEqual(self.client.get(f"/api/recruitment/applications/{hidden['id']}" + suffix).status_code, 403)
        self.assertEqual(self.client.get(f'/api/recruitment/campaigns/{two.id}').status_code, 403)
        self.assertEqual(self.client.get('/api/recruitment/applications/export.csv').status_code, 403)
        self.post(f"/applications/{app['id']}/status", {'status': 'under_review'}, 403)
        self.post('/campaigns', {'title': 'Unauthorized'}, 403)

    def test_revoke_immediately_blocks_detail_review_and_private_cv_preserves_history(self):
        campaign = self.campaign()
        created = self.client.post('/api/recruitment/applications/with-files',
            data={'payload': __import__('json').dumps(self.application_payload(campaign))},
            files={'cv': ('cv.pdf', fixture.PDF, 'application/pdf')})
        self.assertEqual(created.status_code, 200, created.text)
        app = created.json()
        member = self.appoint(campaign)
        self.as_user('b')
        self.assertEqual(self.client.get(app['cv_url']).status_code, 200)
        review = self.post('/reviews', {'application_id': app['id'], 'score': 15})
        self.as_user('sg')
        self.assertEqual(self.client.delete(f"/api/recruitment/campaigns/{campaign.id}/jury/{member['id']}").status_code, 200)
        self.as_user('b')
        self.assertEqual(self.client.get(app['cv_url']).status_code, 403)
        self.assertEqual(self.client.get(f"/api/recruitment/applications/{app['id']}").status_code, 403)
        self.assertEqual(self.client.patch(f"/api/recruitment/reviews/{review['id']}", json={'score': 20}).status_code, 403)
        self.assertEqual(self.db.query(ApplicationReview).count(), 1)
        reappointed = self.appoint(campaign)
        self.assertEqual(member['id'], reappointed['id'])
        self.as_user('b')
        self.assertEqual(self.client.get(app['cv_url']).status_code, 200)

    def test_cross_campaign_private_cv_stays_private(self):
        one, two = self.campaign(), self.campaign()
        created = self.client.post('/api/recruitment/applications/with-files',
            data={'payload': __import__('json').dumps(self.application_payload(two))},
            files={'cv': ('cv.pdf', fixture.PDF, 'application/pdf')})
        self.appoint(one)
        self.as_user('b')
        self.assertEqual(self.client.get(created.json()['cv_url']).status_code, 403)

    def test_only_named_management_and_actual_veille_leaders_can_manage_jury(self):
        campaign = self.campaign()
        for who in ('a', 'b', 'lead', 'veille'):
            self.as_user(who)
            self.post(f'/campaigns/{campaign.id}/jury', {'user_id': str(self.users['b'].id)}, 403)
        for who in ('admin', 'tl', 'sg'):
            self.as_user(who)
            self.post(f'/campaigns/{campaign.id}/jury', {'user_id': str(self.users['b'].id)})
        membership = self.db.query(PoleMember).filter_by(user_id=self.users['veille'].id).one()
        for position in ('chef_pole', 'adjoint_chef_pole'):
            membership.position = position
            self.db.commit()
            self.as_user('veille')
            self.post(f'/campaigns/{campaign.id}/jury', {'user_id': str(self.users['a'].id)})
        self.users['sg'].status = 'alumni'
        self.db.commit()
        self.as_user('admin')
        self.post(f'/campaigns/{campaign.id}/jury', {'user_id': str(self.users['sg'].id)})
        self.as_user('sg')
        self.assertFalse(self.client.get('/api/recruitment/access').json()['can_manage_jury'])
        self.post(f'/campaigns/{campaign.id}/jury', {'user_id': str(self.users['a'].id)}, 403)

    def test_unverified_disabled_pending_people_cannot_be_appointed(self):
        campaign = self.campaign()
        self.as_user('sg')
        for attribute, value in (('email_verified', False), ('is_active', False), ('status', 'pending')):
            previous = getattr(self.users['b'], attribute)
            setattr(self.users['b'], attribute, value)
            self.db.commit()
            self.post(f'/campaigns/{campaign.id}/jury', {'user_id': str(self.users['b'].id)}, 422)
            setattr(self.users['b'], attribute, previous)
            self.db.commit()

    def test_campus_and_preferences_round_trip_and_csv_without_score_change(self):
        app = self.application(campus_resident=False, interview_preferences=['online', 'in_person'],
                               interview_availability='Pause de midi ; mardi soir après les cours.')
        self.assertIs(app['campus_resident'], False)
        self.assertIsNone(app['final_score'])
        self.as_user('sg')
        detail = self.client.get(f"/api/recruitment/applications/{app['id']}").json()
        self.assertEqual(detail['interview_preferences'], ['online', 'in_person'])
        csv = self.client.get('/api/recruitment/applications/export.csv').text
        self.assertIn('Résidence au campus', csv)
        self.assertIn('Pause de midi', csv)

    def test_interview_allows_evening_online_hybrid_and_detects_shared_juror_conflict(self):
        campaign = self.campaign()
        first = self.application(campaign)
        second = self.application(campaign, email='second@example.org')
        member = self.appoint(campaign)
        for app in (first, second):
            self.post(f"/applications/{app['id']}/status", {'status': 'under_review'})
        date = (utc_now() + timedelta(days=3)).replace(hour=19, minute=0, second=0, microsecond=0)
        payload = {'interview_at': date.isoformat() + 'Z',
                   'interview_end_at': (date + timedelta(minutes=30)).isoformat() + 'Z',
                   'interview_mode': 'online', 'interview_link': 'https://example.org/meet',
                   'jury_member_ids': [member['id']]}
        self.post(f"/applications/{first['id']}/interview", payload)
        self.post(f"/applications/{second['id']}/interview", payload, 409)
        payload.update(interview_at=(date + timedelta(minutes=30)).isoformat() + 'Z',
                       interview_end_at=(date + timedelta(minutes=50)).isoformat() + 'Z',
                       interview_mode='hybrid', interview_location='ESP, salle confirmée')
        self.post(f"/applications/{second['id']}/interview", payload)
        removed = self.client.delete(f"/api/recruitment/campaigns/{campaign.id}/jury/{member['id']}").json()
        self.assertEqual(len(removed['interviews_to_reassign']), 2)
        detail = self.client.get(f"/api/recruitment/applications/{first['id']}").json()
        self.assertTrue(detail['interview_needs_reassignment'])
        roster = self.client.get(f'/api/recruitment/campaigns/{campaign.id}/jury').json()
        self.assertEqual(len(roster['interviews_needing_reassignment']), 2)

    def test_questionnaire_has_five_dimensions_four_items_each_and_reverse_keys(self):
        snapshot = instrument()
        positive = {row['id']: 1 if row['reverse'] else 5 for row in snapshot['items']}
        results = score(snapshot, positive)
        self.assertEqual(len(results['dimensions']), 5)
        self.assertTrue(all(row['mean'] == 5 for row in results['dimensions']))
        self.assertNotIn('admission_score', results)
        self.assertNotIn('personality_type', results)

    def test_draft_is_private_resume_and_stale_revision_rejected(self):
        app, credentials, state = self.prepare_assessment()
        body = dict(credentials, **self.answers(state))
        saved = self.post('/personality/save', body)
        self.assertEqual(saved['revision'], 1)
        self.assertEqual(self.post('/personality/load', credentials)['answers'], body['answers'])
        internal = self.client.get(f"/api/recruitment/applications/{app['id']}/personality").json()
        self.assertNotIn('answers', internal)
        self.assertIsNone(internal['results'])
        self.post('/personality/save', body, 409)
        self.post('/personality/load', dict(credentials, email='wrong@example.org'), 404)

    def test_complete_submission_scores_server_side_and_retry_is_idempotent(self):
        app, credentials, state = self.prepare_assessment()
        body = dict(credentials, **self.answers(state), results={'admission_score': 100})
        first = self.post('/personality/submit', body)
        second = self.post('/personality/submit', dict(body, answers={}))
        self.assertEqual(first, second)
        self.assertEqual(self.db.query(ApplicationPersonality).count(), 1)
        self.assertNotIn('admission_score', first['results'])
        self.db.expire_all()
        self.assertEqual(self.db.get(Application, app['id']).status, 'under_review')
        self.assertIsNone(self.db.get(Application, app['id']).final_score)

    def test_partial_invalid_unknown_answers_and_missing_consent_block_completion(self):
        _, credentials, state = self.prepare_assessment()
        body = dict(credentials, **self.answers(state))
        for changes in ({'consent': False}, {'answers': {'p01': True}}, {'answers': {'p01': 6}},
                        {'answers': {'unknown': 3}}, {'scenario_answers': {}}, {'answers': {}}):
            self.post('/personality/submit', dict(body, **changes), 422)
        self.assertIsNone(self.db.query(ApplicationPersonality).one().submitted_at)

    def test_decline_erases_draft_and_does_not_reject_candidate(self):
        app, credentials, state = self.prepare_assessment()
        self.post('/personality/save', dict(credentials, **self.answers(state)))
        self.assertEqual(self.post('/personality/decline', credentials)['status'], 'declined')
        stored = self.db.query(ApplicationPersonality).one()
        self.assertEqual(stored.answers, {})
        self.assertIsNone(stored.results)
        self.assertEqual(self.db.get(Application, app['id']).status, 'under_review')

    def test_deadline_can_be_extended_and_uninvited_candidates_get_no_questionnaire(self):
        app, credentials, state = self.prepare_assessment()
        row = self.db.query(ApplicationPersonality).one()
        row.due_at = utc_now() - timedelta(minutes=1)
        self.db.commit()
        body = dict(credentials, **self.answers(state))
        self.post('/personality/save', body, 409)
        self.post(f"/applications/{app['id']}/personality/invite", {'due_at': (utc_now() + timedelta(days=1)).isoformat() + 'Z'})
        self.post('/personality/save', body)
        other = self.application(email='uninvited@example.org')
        self.post('/personality/load', {'application_id': other['tracking_code'], 'email': other['email']}, 404)

    def test_jury_cannot_invite_or_read_another_campaign_results(self):
        app, _, _ = self.prepare_assessment()
        another = self.campaign()
        self.appoint(another)
        self.as_user('b')
        self.assertEqual(self.client.get(f"/api/recruitment/applications/{app['id']}/personality").status_code, 403)
        self.post(f"/applications/{app['id']}/personality/invite", {}, 403)
