"""Recruitment history, discovery source and anonymous detail HTTP journeys."""
import json
import unittest

import test_attachments_lifecycle as fixture
from app.api.deps import get_current_active_validated_user
from app.models.audit import AuditLog
from app.models.recruitment import Application


class RecruitmentHistoryTests(unittest.TestCase):
    make_task = fixture.AttachmentLifecycleTests.make_task
    as_user = fixture.AttachmentLifecycleTests.as_user
    call = fixture.AttachmentLifecycleTests.call
    campaign = fixture.AttachmentLifecycleTests.campaign
    application_payload = fixture.AttachmentLifecycleTests.application_payload

    def setUp(self):
        fixture.AttachmentLifecycleTests.setUp(self)
        campaign = self.campaign()
        payload = self.application_payload(campaign)
        payload['known_enactus_from'] = 'Une présentation du club à l’ESP et Instagram.'
        response = self.client.post('/api/recruitment/applications', json=payload)
        self.assertEqual(response.status_code, 200, response.text)
        self.submission = response.json()
        self.id = self.submission['id']
        self.path = '/api/recruitment/applications/' + self.id
        self.as_user('sg')

    def tearDown(self):
        fixture.AttachmentLifecycleTests.tearDown(self)

    def detail(self, suffix=''):
        response = self.client.get(self.path + suffix)
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def change(self, status):
        response = self.client.post(self.path + '/status', json={'status': status})
        self.assertEqual(response.status_code, 200, response.text)

    def test_submission_date_and_discovery_source_are_readable_privately(self):
        body = self.detail()
        self.assertEqual(body['known_enactus_from'], 'Une présentation du club à l’ESP et Instagram.')
        self.assertIsNone(body['preferred_pole'])
        self.assertIsNone(body['project_interest'])
        self.assertEqual(len(body['history']), 1)
        self.assertEqual(body['history'][0]['kind'], 'submission')
        self.assertEqual(body['history'][0]['to_status'], 'submitted')
        self.assertTrue(body['history'][0]['occurred_at'].endswith('Z'))
        self.assertEqual(self.submission['history'], [])

    def test_status_trail_shows_old_and_new_status_with_actual_actor(self):
        self.change('under_review')
        event = self.detail()['history'][-1]
        self.assertEqual((event['from_status'], event['to_status']), ('submitted', 'under_review'))
        user = self.users['sg']
        self.assertEqual(event['actor_name'], (user.first_name + ' ' + user.last_name).strip())
        self.assertNotIn('ip_address', event)
        self.assertNotIn('user_id', event)

    def test_repeated_or_invalid_changes_do_not_invent_history(self):
        self.assertEqual(self.client.post(self.path + '/status', json={'status': 'accepted'}).status_code, 409)
        self.change('under_review')
        self.change('under_review')
        self.assertEqual(len(self.detail()['history']), 2)
        response = self.client.patch(self.path, json={'status': 'waiting_list'})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(self.detail()['history'][-1]['to_status'], 'waiting_list')

    def test_interview_changes_are_recorded_once_with_their_date(self):
        self.change('under_review')
        first = {'interview_at': '2030-06-12T14:00:00Z', 'interview_location': 'ESP'}
        for _ in range(2):
            response = self.client.post(self.path + '/interview', json=first)
            self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(len(self.detail()['history']), 3)
        second = dict(first, interview_at='2030-06-13T15:00:00Z')
        response = self.client.post(self.path + '/interview', json=second)
        self.assertEqual(response.status_code, 200, response.text)
        events = self.detail()['history']
        self.assertEqual(len(events), 4)
        self.assertEqual(events[-1]['kind'], 'interview')
        self.assertEqual(events[-1]['scheduled_for'], second['interview_at'])

    def test_anonymous_detail_masks_candidate_identity_and_documents(self):
        self.change('under_review')
        body = self.detail('?anonymized=true')
        self.assertTrue(body['is_anonymized'])
        self.assertNotEqual(body['email'], self.submission['email'])
        for key in ('phone', 'known_enactus_from', 'questionnaire_answers', 'cv_url', 'motivation_letter_url', 'attachment_url'):
            self.assertIsNone(body[key], key)
        self.assertFalse(body['can_convert'])
        self.assertEqual(len(body['history']), 2)

    def test_unauthorized_and_unauthenticated_people_cannot_read_history(self):
        self.as_user('b')
        self.assertEqual(self.client.get(self.path).status_code, 403)
        self.client.app.dependency_overrides.pop(get_current_active_validated_user, None)
        self.assertEqual(self.client.get(self.path).status_code, 401)

    def test_history_does_not_expose_unrelated_audits_or_raw_values(self):
        application = self.db.get(Application, self.id)
        self.db.add(AuditLog(action='changement_statut_candidature', entity_type='application', entity_id=application.id,
            old_value={'status': 'received', 'email': 'private@example.org'},
            new_value={'status': 'preselected', 'token': 'private-token'}, ip_address='192.0.2.7'))
        self.db.add(AuditLog(action='other_audit', entity_type='application', entity_id=application.id,
            new_value={'private': 'confidential'}))
        self.db.commit()
        events = self.detail()['history']
        self.assertEqual(len(events), 2)
        self.assertEqual(events[-1]['to_status'], 'under_review')
        serialized = json.dumps(events)
        for text in ('private@example.org', 'private-token', '192.0.2.7', 'confidential'):
            self.assertNotIn(text, serialized)

    def test_conversion_adds_one_human_integration_event(self):
        self.change('under_review')
        self.change('accepted')
        payload = {'password': 'Recruitment-Test-Only-2030', 'profile_type': 'enacteur'}
        response = self.client.post(self.path + '/convert-to-user', json=payload)
        self.assertEqual(response.status_code, 200, response.text)
        event = self.detail()['history'][-1]
        self.assertEqual(event['kind'], 'integration')
        self.assertEqual(event['title'], 'Compte membre créé')
        response = self.client.post(self.path + '/convert-to-user', json=payload)
        self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(len([e for e in self.detail()['history'] if e['kind'] == 'integration']), 1)

    def test_reviews_use_the_reviewers_name_without_replacing_review_identity(self):
        response = self.client.post('/api/recruitment/reviews', json={'application_id': self.id, 'score': 16, 'comment': 'Dossier clair.', 'recommendation': 'favorable'})
        self.assertEqual(response.status_code, 200, response.text)
        response = self.client.get(self.path + '/reviews')
        self.assertEqual(response.status_code, 200, response.text)
        review = response.json()[0]
        self.assertEqual(review['reviewer_id'], str(self.users['sg'].id))
        self.assertEqual(review['reviewer_name'], (self.users['sg'].first_name + ' ' + self.users['sg'].last_name).strip())
