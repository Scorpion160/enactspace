"""Interview rooms isolate candidates without requiring member accounts."""
from datetime import timedelta, timezone
import secrets
from unittest import TestCase
from unittest.mock import patch
from uuid import UUID
import jwt

from app.api.routes import meetings
from app.core.config import settings
from app.core.time import utc_now
from app.models.meeting import Meeting
from app.models.recruitment import Application, RecruitmentJuryMember
import test_recruitment_selection as selection_fixture
from app.models.user import User


class RecruitmentMeetingTests(TestCase):
    setUp = selection_fixture.RecruitmentSelectionTests.setUp
    tearDown = selection_fixture.RecruitmentSelectionTests.tearDown
    make_task = selection_fixture.RecruitmentSelectionTests.make_task
    as_user = selection_fixture.RecruitmentSelectionTests.as_user
    campaign = selection_fixture.RecruitmentSelectionTests.campaign
    application_payload = selection_fixture.RecruitmentSelectionTests.application_payload
    prepare = selection_fixture.RecruitmentSelectionTests.prepare
    post = selection_fixture.RecruitmentSelectionTests.post

    def private_meet(self):
        self.secret = secrets.token_urlsafe(48)
        return patch.multiple(settings, MEET_SERVER_URL='https://meet.example.test', MEET_REQUIRE_JWT=True,
                              MEET_JWT_APP_ID='enactspace-tests', MEET_JWT_SECRET=self.secret,
                              MEET_JWT_SUBJECT='meet.example.test')

    def prepare_interview(self):
        self.client.app.include_router(meetings.router, prefix='/api')
        campaign, applications, members = self.prepare(count=2)
        self.db.refresh(campaign)
        campaign.screening_published_at = utc_now() - timedelta(hours=2)
        campaign.identities_revealed_at = utc_now() - timedelta(hours=1)
        for item in applications:
            app = self.db.get(Application, UUID(item['id']))
            app.screening_decision = 'shortlisted'
            app.status = 'under_review'
        self.db.commit()
        self.start = utc_now() - timedelta(minutes=5)
        self.end = self.start + timedelta(minutes=30)
        self.payload = {'interview_at': self.start.isoformat() + 'Z', 'interview_end_at': self.end.isoformat() + 'Z',
                        'interview_mode': 'online', 'use_enactmeet': True,
                        'jury_member_ids': [str(member.id) for member in members[:2]]}
        return campaign, applications, members

    def test_candidate_join_requires_own_code_a_live_jury_and_a_non_moderator_room_token(self):
        campaign, applications, members = self.prepare_interview()
        candidate = applications[0]
        with self.private_meet():
            saved = self.post(f"/applications/{candidate['id']}/interview", self.payload)
            meeting_id = saved['interview_meeting_id']
            self.assertTrue(meeting_id)
            credentials = {'application_id': candidate['tracking_code'], 'email': candidate['email']}
            self.post('/applications/interview/join', credentials, 409)
            entered = self.client.post(f'/api/meetings/{meeting_id}/entered')
            self.assertEqual(entered.status_code, 200, entered.text)
            self.post('/applications/interview/join', dict(credentials, application_id=candidate['id']), 404)
            self.post('/applications/interview/join', dict(credentials, email='wrong@example.org'), 404)
            result = self.post('/applications/interview/join', credentials)
            claims = jwt.decode(result['jwt'], self.secret, algorithms=['HS256'], audience=settings.MEET_JWT_AUDIENCE)
            self.assertFalse(result['moderator'])
            self.assertFalse(claims['context']['user']['moderator'])
            self.assertEqual(claims['context']['user']['affiliation'], 'member')
            self.assertEqual(claims['room'], result['room_key'])
            self.assertTrue(claims['context']['user']['id'].startswith('candidate:'))
            self.assertLessEqual(claims['exp'], int((self.end + timedelta(minutes=15)).replace(tzinfo=timezone.utc).timestamp()))
            self.post('/applications/interview/join', {'application_id': applications[1]['tracking_code'], 'email': applications[1]['email']}, 409)
            with patch('app.services.recruitment_meetings.utc_now', return_value=self.end + timedelta(minutes=16)):
                self.post('/applications/interview/join', credentials, 409)
            self.acting = self.db.get(User, members[2].user_id)
            denied = self.client.post(f'/api/meetings/{meeting_id}/join')
            self.assertEqual(denied.status_code, 403, denied.text)
            self.as_user('sg')
            self.client.delete(f'/api/recruitment/campaigns/{campaign.id}/jury/{members[0].id}')
            self.acting = self.db.get(User, members[0].user_id)
            self.assertEqual(self.client.post(f'/api/meetings/{meeting_id}/join').status_code, 403)

    def test_rescheduling_rotates_the_room_and_external_fallback_cancels_it(self):
        _, applications, _ = self.prepare_interview()
        with self.private_meet():
            first = self.post(f"/applications/{applications[0]['id']}/interview", self.payload)
            changed = dict(self.payload, interview_at=(self.start + timedelta(minutes=10)).isoformat() + 'Z',
                           interview_end_at=(self.end + timedelta(minutes=10)).isoformat() + 'Z')
            second = self.post(f"/applications/{applications[0]['id']}/interview", changed)
            self.assertNotEqual(first['interview_meeting_id'], second['interview_meeting_id'])
            self.assertEqual(self.db.get(Meeting, UUID(first['interview_meeting_id'])).status, 'cancelled')
            fallback = dict(changed, use_enactmeet=False, interview_link='https://example.org/entretien')
            third = self.post(f"/applications/{applications[0]['id']}/interview", fallback)
            self.assertIsNone(third['interview_meeting_id'])
            self.db.expire_all()
            self.assertEqual(self.db.get(Meeting, UUID(second['interview_meeting_id'])).status, 'cancelled')

    def test_private_provider_configuration_is_required_without_saving_a_partial_interview(self):
        _, applications, _ = self.prepare_interview()
        with patch.object(settings, 'MEET_REQUIRE_JWT', False):
            self.post(f"/applications/{applications[0]['id']}/interview", self.payload, 503)
        self.db.expire_all()
        app = self.db.get(Application, UUID(applications[0]['id']))
        self.assertEqual(app.status, 'under_review')
        self.assertIsNone(app.interview_meeting_id)
        self.assertEqual(self.db.query(Meeting).count(), 0)
