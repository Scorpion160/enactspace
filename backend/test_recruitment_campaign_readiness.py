"""November campaign boundaries exercised through HTTP on synthetic SQLite data."""
import csv
import io
import unittest
from datetime import date, datetime
from unittest.mock import patch

import test_attachments_lifecycle as fixture
from app.api.routes import recruitment
from app.core.config import settings
from app.models.email_delivery import EmailDelivery
from app.models.notification import Notification
from app.models.recruitment import Application, RecruitmentCampaign


class CampaignReadinessTests(unittest.TestCase):
    setUp = fixture.AttachmentLifecycleTests.setUp
    tearDown = fixture.AttachmentLifecycleTests.tearDown
    make_task = fixture.AttachmentLifecycleTests.make_task
    as_user = fixture.AttachmentLifecycleTests.as_user
    call = fixture.AttachmentLifecycleTests.call
    campaign = fixture.AttachmentLifecycleTests.campaign
    application_payload = fixture.AttachmentLifecycleTests.application_payload

    def submit(self, campaign, **changes):
        body = self.application_payload(campaign)
        body.update(changes)
        return self.client.post('/api/recruitment/applications', json=body)

    def test_november_opening_and_inclusive_closing_use_utc_clock(self):
        campaign = self.campaign()
        campaign.start_date, campaign.end_date = date(2026, 11, 4), date(2026, 11, 8)
        self.db.commit()
        cases = [
            (datetime(2026, 11, 3, 23, 59, 59), False),
            (datetime(2026, 11, 4), True),
            (datetime(2026, 11, 8, 23, 59, 59), True),
            (datetime(2026, 11, 9), False),
        ]
        for instant, expected in cases:
            with self.subTest(instant=instant), patch.object(recruitment, 'utc_now', return_value=instant):
                self.assertEqual(recruitment.campaign_is_open(campaign), expected)
                response = self.client.get('/api/recruitment/campaigns/public')
                self.assertEqual(bool(response.json()), expected)

    def test_closed_campaign_refuses_json_without_creating_a_dossier(self):
        campaign = self.campaign()
        campaign.is_active = False
        self.db.commit()
        self.assertEqual(self.submit(campaign).status_code, 400)
        self.assertEqual(self.db.query(Application).count(), 0)

    def test_form_post_obeys_the_opening_and_last_day_boundaries(self):
        campaign = self.campaign()
        campaign.start_date, campaign.end_date = date(2026, 11, 4), date(2026, 11, 8)
        self.db.commit()
        cases = [(datetime(2026, 11, 3, 23, 59, 59), 400), (datetime(2026, 11, 4), 200),
                 (datetime(2026, 11, 8, 23, 59, 59), 200), (datetime(2026, 11, 9), 400)]
        for i, (instant, status) in enumerate(cases):
            with self.subTest(instant=instant), patch.object(recruitment, 'utc_now', return_value=instant):
                self.assertEqual(self.submit(campaign, email=f'boundary{i}@example.org').status_code, status)
        self.assertEqual(self.db.query(Application).count(), 2)

    def test_tracking_remains_available_after_registration_closes(self):
        campaign = self.campaign()
        result = self.submit(campaign).json()
        campaign.is_active = False
        self.db.commit()
        response = self.client.post('/api/recruitment/applications/track', json={
            'email': result['email'], 'application_id': result['tracking_code']})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(response.json()['status'], 'submitted')
        for field in ['interview_note', 'interview_jury', 'final_score', 'questionnaire_answers', 'cv_url']:
            self.assertNotIn(field, response.json())

    def test_oversized_identity_is_rejected_before_database_write(self):
        campaign = self.campaign()
        for field, maximum in [('first_name', 100), ('last_name', 100), ('phone', 30),
                               ('department', 150), ('study_level', 100), ('class_name', 120)]:
            with self.subTest(field=field):
                response = self.submit(campaign, email=field + '@example.org', **{field: 'x' * (maximum + 1)})
                self.assertEqual(response.status_code, 422, response.text)
        self.assertEqual(self.db.query(Application).count(), 0)

    def test_legacy_required_mapped_answers_cannot_be_omitted(self):
        campaign = self.campaign()
        body = self.application_payload(campaign)
        body.pop('questionnaire_answers')
        body.pop('questionnaire_version')
        body['project_ideas'] = 'Une solution construite avec les communautés.'
        for field in ['motivation', 'availability']:
            with self.subTest(field=field):
                response = self.client.post('/api/recruitment/applications', json=dict(body, **{field: ' '}))
                self.assertEqual(response.status_code, 422, response.text)
        self.assertEqual(self.db.query(Application).count(), 0)
        self.assertEqual(self.client.post('/api/recruitment/applications', json=body).status_code, 200)

    def test_case_insensitive_repeat_keeps_one_application_and_one_receipt(self):
        campaign = self.campaign()
        with patch.object(settings, 'EMAIL_ENABLED', True):
            first = self.submit(campaign, email='Candidate@example.org')
            self.assertEqual(first.status_code, 200, first.text)
            repeat = self.submit(campaign, email='candidate@example.org')
        self.assertEqual(repeat.status_code, 409)
        self.assertEqual(self.db.query(Application).count(), 1)
        self.assertEqual(self.db.query(EmailDelivery).filter(
            EmailDelivery.dedupe_key.like('recruitment-submission:%')).count(), 1)

    def test_submission_queues_mail_without_contacting_smtp(self):
        campaign = self.campaign()
        with patch.object(settings, 'EMAIL_ENABLED', True), patch('smtplib.SMTP') as smtp:
            result = self.submit(campaign)
        self.assertEqual(result.status_code, 200, result.text)
        smtp.assert_not_called()
        receipt = self.db.query(EmailDelivery).filter(
            EmailDelivery.dedupe_key.like('recruitment-submission:%')).one()
        self.assertEqual(receipt.status, 'pending')
        self.assertIn(result.json()['tracking_code'], receipt.text_body)

    def test_recruitment_notifications_exclude_former_leaders_and_include_veille_members(self):
        campaign = self.campaign()
        self.users['tl'].status = 'alumni'
        self.db.commit()
        self.assertEqual(self.submit(campaign).status_code, 200)
        recipients = {row.user_id for row in self.db.query(Notification).filter_by(type='application_received')}
        self.assertNotIn(self.users['tl'].id, recipients)
        self.assertIn(self.users['veille'].id, recipients)
        self.assertIn(self.users['sg'].id, recipients)
        self.assertNotIn(self.users['a'].id, recipients)

    def test_revoked_recruiter_does_not_receive_already_queued_candidate_mail(self):
        from app.services.email_delivery_service import claim_email_deliveries, process_email_delivery
        campaign = self.campaign()
        with patch.object(settings, 'EMAIL_ENABLED', True):
            self.assertEqual(self.submit(campaign).status_code, 200)
            notification = self.db.query(Notification).filter_by(
                type='application_received', user_id=self.users['tl'].id).one()
            delivery = self.db.query(EmailDelivery).filter_by(notification_id=notification.id).one()
            self.users['tl'].status = 'alumni'
            self.db.commit()
            claim_email_deliveries(self.db, limit=100)
            from unittest.mock import Mock
            provider = Mock()
            self.assertEqual(process_email_delivery(self.db, delivery.id, provider), 'cancelled')
            provider.send.assert_not_called()

    def test_campaign_with_applications_must_be_closed_instead_of_deleted(self):
        campaign = self.campaign()
        self.assertEqual(self.submit(campaign).status_code, 200)
        self.as_user('tl')
        response = self.client.delete('/api/recruitment/campaigns/' + str(campaign.id))
        self.assertEqual(response.status_code, 409, response.text)
        self.db.expire_all()
        self.assertIsNotNone(self.db.get(RecruitmentCampaign, campaign.id))
        self.assertEqual(self.db.query(Application).count(), 1)

    def test_empty_campaign_can_still_be_deleted(self):
        campaign = self.campaign()
        self.as_user('tl')
        self.assertEqual(self.client.delete('/api/recruitment/campaigns/' + str(campaign.id)).status_code, 200)

    def test_spreadsheet_formulas_are_escaped_and_discovery_is_exported(self):
        campaign = self.campaign()
        result = self.submit(campaign, last_name='=HYPERLINK("https://example.org")',
                             class_name='2025-2026', known_enactus_from='Instagram')
        self.assertEqual(result.status_code, 200, result.text)
        self.as_user('sg')
        response = self.client.get('/api/recruitment/applications/export.csv')
        self.assertEqual(response.status_code, 200)
        rows = list(csv.DictReader(io.StringIO(response.text)))
        self.assertTrue(rows[0]['Nom'].startswith("'="))
        self.assertEqual(rows[0]['Promotion'], '2025-2026')
        self.assertEqual(rows[0]['Canal de découverte'], 'Instagram')
        self.assertEqual(rows[0]['Niveau d’études'], 'DIC1')

    def test_export_can_be_limited_to_the_requested_campaign(self):
        first, second = self.campaign(), self.campaign()
        self.assertEqual(self.submit(first, email='one@example.org').status_code, 200)
        self.assertEqual(self.submit(second, email='two@example.org').status_code, 200)
        self.as_user('sg')
        response = self.client.get('/api/recruitment/applications/export.csv?campaign_id=' + str(first.id))
        rows = list(csv.DictReader(io.StringIO(response.text)))
        self.assertEqual([row['Email'] for row in rows], ['one@example.org'])


if __name__ == '__main__':
    unittest.main()
