"""Campaign CRUD, closure and retention through HTTP on isolated fixture data."""
from datetime import date, datetime
from unittest import TestCase
from unittest.mock import patch
from uuid import UUID, uuid4

import test_attachments_lifecycle as fixture
from app.api.routes import recruitment
from app.models.recruitment import Application, ApplicationReview, RecruitmentCampaign


class CampaignLifecycleTests(TestCase):
    setUp = fixture.AttachmentLifecycleTests.setUp
    tearDown = fixture.AttachmentLifecycleTests.tearDown
    make_task = fixture.AttachmentLifecycleTests.make_task
    as_user = fixture.AttachmentLifecycleTests.as_user
    campaign = fixture.AttachmentLifecycleTests.campaign
    application_payload = fixture.AttachmentLifecycleTests.application_payload

    def create(self, **changes):
        self.as_user('sg')
        body = dict(title='Synthetic November campaign', start_date='2026-11-04',
                    end_date='2026-11-08', is_active=True)
        body.update(changes)
        response = self.client.post('/api/recruitment/campaigns', json=body)
        self.assertEqual(response.status_code, 200, response.text)
        return self.db.get(RecruitmentCampaign, UUID(response.json()['id']))

    def test_create_plan_open_close_review_track_and_protect_existing_dossier(self):
        campaign = self.create()
        campaign_id = str(campaign.id)
        with patch.object(recruitment, 'utc_now', return_value=datetime(2026, 11, 3, 12)):
            timeline = self.client.get('/api/recruitment/campaigns/timeline').json()
            self.assertEqual(timeline['campaigns'][0]['id'], campaign_id)
            self.assertEqual(timeline['campaigns'][0]['opens_at'], '2026-11-04T00:00:00Z')
            self.assertEqual(timeline['campaigns'][0]['closes_at'], '2026-11-09T00:00:00Z')
            self.assertEqual(self.client.get('/api/recruitment/campaigns/public').json(), [])
            self.assertEqual(self.client.post('/api/recruitment/applications', json=self.application_payload(campaign)).status_code, 400)
        with patch.object(recruitment, 'utc_now', return_value=datetime(2026, 11, 4, 12)):
            body = self.application_payload(campaign)
            response = self.client.post('/api/recruitment/applications', json=body)
            self.assertEqual(response.status_code, 200, response.text)
            application = response.json()
            self.assertEqual(self.client.post('/api/recruitment/applications', json=body).status_code, 409)
            closed = self.client.patch('/api/recruitment/campaigns/' + campaign_id, json={'is_active': False})
            self.assertEqual(closed.status_code, 200, closed.text)
            self.assertEqual(self.client.get('/api/recruitment/campaigns/timeline').json()['campaigns'], [])
            self.assertEqual(self.client.post('/api/recruitment/applications', json={**body, 'email': 'second@example.org'}).status_code, 400)
        tracking = self.client.post('/api/recruitment/applications/track', json={
            'application_id': application['tracking_code'], 'email': application['email']})
        self.assertEqual(tracking.status_code, 200, tracking.text)
        self.assertEqual(self.client.post('/api/recruitment/applications/' + application['id'] + '/status',
            json={'status': 'under_review'}).status_code, 200)
        review = self.client.post('/api/recruitment/reviews', json={'application_id': application['id'],
            'score': 15, 'recommendation': 'favorable', 'comment': 'Synthetic observation'})
        self.assertEqual(review.status_code, 200, review.text)
        deleted = self.client.delete('/api/recruitment/campaigns/' + campaign_id)
        self.assertEqual(deleted.status_code, 409, deleted.text)
        self.assertEqual(self.db.query(Application).filter_by(campaign_id=campaign.id).count(), 1)
        self.assertEqual(self.db.query(ApplicationReview).count(), 1)

    def test_empty_campaign_delete_is_scoped_and_unknown_delete_is_404(self):
        first, other = self.create(), self.create()
        first_id, other_id = first.id, other.id
        self.assertEqual(self.client.delete('/api/recruitment/campaigns/' + str(first_id)).status_code, 200)
        self.db.expire_all()
        self.assertIsNone(self.db.get(RecruitmentCampaign, first_id))
        self.assertIsNotNone(self.db.get(RecruitmentCampaign, other_id))
        self.assertEqual(self.client.delete('/api/recruitment/campaigns/' + str(first_id)).status_code, 404)
        self.assertEqual(self.client.delete('/api/recruitment/campaigns/' + str(uuid4())).status_code, 404)

    def test_invalid_title_and_reversed_dates_create_no_campaign(self):
        self.as_user('sg')
        for body, code in [({'title': '   '}, 422), ({'title': 'Synthetic', 'start_date': '2026-11-08', 'end_date': '2026-11-04'}, 400)]:
            with self.subTest(body=body):
                response = self.client.post('/api/recruitment/campaigns', json=body)
                self.assertEqual(response.status_code, code, response.text)
        self.assertEqual(self.db.query(RecruitmentCampaign).count(), 0)

    def test_invalid_partial_date_edit_preserves_dates(self):
        campaign = self.create()
        response = self.client.patch('/api/recruitment/campaigns/' + str(campaign.id), json={'start_date': '2026-11-10'})
        self.assertEqual(response.status_code, 400, response.text)
        self.db.refresh(campaign)
        self.assertEqual(campaign.start_date, date(2026, 11, 4))
        self.assertEqual(campaign.end_date, date(2026, 11, 8))

    def test_expired_campaign_can_be_closed_without_changing_dates(self):
        campaign = self.create()
        with patch.object(recruitment, 'utc_now', return_value=datetime(2026, 11, 10)):
            response = self.client.patch('/api/recruitment/campaigns/' + str(campaign.id), json={'is_active': False})
        self.assertEqual(response.status_code, 200, response.text)
        self.db.refresh(campaign)
        self.assertFalse(campaign.is_active)
        self.assertEqual(campaign.end_date, date(2026, 11, 8))

    def test_selected_juror_reads_but_cannot_create_close_or_delete_campaign(self):
        campaign = self.create()
        response = self.client.post(f'/api/recruitment/campaigns/{campaign.id}/jury', json={'user_id': str(self.users['b'].id)})
        self.assertEqual(response.status_code, 200, response.text)
        self.as_user('b')
        self.assertEqual(self.client.get(f'/api/recruitment/campaigns/{campaign.id}').status_code, 200)
        self.assertEqual(self.client.post('/api/recruitment/campaigns', json={'title': 'Forbidden'}).status_code, 403)
        self.assertEqual(self.client.patch(f'/api/recruitment/campaigns/{campaign.id}', json={'is_active': False}).status_code, 403)
        self.assertEqual(self.client.delete(f'/api/recruitment/campaigns/{campaign.id}').status_code, 403)

    def test_closed_campaign_keeps_its_cv_private_and_available_to_staff(self):
        import json
        campaign = self.campaign()
        response = self.client.post('/api/recruitment/applications/with-files',
            data={'payload': json.dumps(self.application_payload(campaign))},
            files={'cv': ('cv.pdf', fixture.PDF, 'application/pdf')})
        self.assertEqual(response.status_code, 200, response.text)
        self.as_user('sg')
        self.assertEqual(self.client.patch(f'/api/recruitment/campaigns/{campaign.id}', json={'is_active': False}).status_code, 200)
        self.assertEqual(self.client.get(response.json()['cv_url']).content, fixture.PDF)
        self.as_user('a')
        self.assertEqual(self.client.get(response.json()['cv_url']).status_code, 403)
