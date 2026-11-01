"""Maintenance erases only synthetic recruitment data; accounts stay intact."""
from datetime import date
from pathlib import Path
import sys
from unittest import TestCase
from unittest.mock import patch
from uuid import uuid4

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import test_attachments_lifecycle as fixture
import recruitment_test_campaign_scope as scope
from app.models.audit import AuditLog
from app.models.email_delivery import EmailDelivery
from app.models.notification import Notification
from app.models.product_services import AppInstallation, PushDelivery
from app.models.recruitment import (
    Application, ApplicationInterviewJuror, ApplicationInterviewTeam,
    ApplicationPersonality, RecruitmentCampaign, RecruitmentJuryMember,
    RecruitmentJuryTeam, RecruitmentJuryTeamMember,
)
from app.models.stored_file import StoredFile


TODAY = date(2026, 11, 1)


class TestCampaignCleanupTests(TestCase):
    setUp = fixture.AttachmentLifecycleTests.setUp
    tearDown = fixture.AttachmentLifecycleTests.tearDown
    make_task = fixture.AttachmentLifecycleTests.make_task
    as_user = fixture.AttachmentLifecycleTests.as_user
    campaign = fixture.AttachmentLifecycleTests.campaign
    application_payload = fixture.AttachmentLifecycleTests.application_payload

    def prepare(self):
        campaign = self.campaign()
        response = self.client.post('/api/recruitment/applications', json=self.application_payload(campaign))
        self.assertEqual(response.status_code, 200, response.text)
        campaign.start_date, campaign.end_date = date(2026, 10, 10), date(2026, 10, 17)
        self.db.commit()
        application = self.db.query(Application).one()
        return campaign, application

    def inventory(self, connection):
        return scope.inventory(connection, today=TODAY)

    def test_complete_scoped_erasure_keeps_accounts_and_unrelated_messages(self):
        campaign, app = self.prepare()
        member = RecruitmentJuryMember(campaign_id=campaign.id, user_id=self.users['b'].id)
        team = RecruitmentJuryTeam(campaign_id=campaign.id, name='Synthetic jury', name_key='synthetic jury')
        self.db.add_all([member, team])
        self.db.flush()
        self.db.add_all([
            RecruitmentJuryTeamMember(team_id=team.id, jury_member_id=member.id),
            ApplicationInterviewJuror(application_id=app.id, jury_member_id=member.id),
            ApplicationInterviewTeam(application_id=app.id, team_id=team.id, revision=1, name=team.name),
            ApplicationPersonality(application_id=app.id, instrument_version='synthetic', instrument_snapshot={}),
            AuditLog(action='synthetic_campaign', entity_type='recruitment_campaign', entity_id=campaign.id),
        ])
        unrelated = Notification(user_id=self.users['a'].id, title='Keep', message='Unrelated')
        targeted = Notification(user_id=self.users['a'].id, title='Synthetic', message='Scoped',
                                related_type='application', related_id=app.id)
        installation = AppInstallation(user_id=self.users['a'].id, installation_key=uuid4(), platform='web')
        self.db.add_all([unrelated, targeted, installation])
        self.db.flush()
        self.db.add_all([
            EmailDelivery(notification_id=unrelated.id, recipient_email=app.email,
                subject='Keep even with the same recipient', text_body='Unrelated', dedupe_key='password-reset:keep'),
            EmailDelivery(recipient_email=app.email, subject='Synthetic', text_body='Scoped',
                dedupe_key=f'personality-invite:{app.id}:open'),
            AuditLog(action='unrelated', entity_type=None, entity_id=None),
            PushDelivery(notification_id=unrelated.id, installation_id=installation.id, token_hash_snapshot='a' * 64),
            PushDelivery(notification_id=targeted.id, installation_id=installation.id, token_hash_snapshot='a' * 64),
        ])
        self.db.commit()
        users_before = scope.count(self.db.connection(), scope.tables()['users'])
        with self.db.get_bind().begin() as connection:
            report, selected = self.inventory(connection)
            self.assertTrue(report['campaigns'][0]['eligible_for_authorized_test_cleanup'])
            result = scope.erase(connection, selected, selected['fingerprint'], today=TODAY)
            self.assertTrue(result['unrelated_rows_preserved'])
            self.assertEqual(result['deleted_counts']['application_personality'], 1)
            self.assertEqual(result['deleted_counts']['application_interview_teams'], 1)
            self.assertEqual(result['deleted_counts']['push_deliveries'], 1)
        self.db.expire_all()
        self.assertEqual(self.db.query(RecruitmentCampaign).count(), 0)
        self.assertEqual(self.db.query(Application).count(), 0)
        self.assertEqual(self.db.query(EmailDelivery).count(), 1)
        self.assertEqual(self.db.query(EmailDelivery).one().dedupe_key, 'password-reset:keep')
        self.assertEqual(self.db.query(Notification).count(), 1)
        self.assertEqual(self.db.query(PushDelivery).count(), 1)
        self.assertEqual(self.db.query(AppInstallation).count(), 1)
        self.assertEqual(self.db.query(AuditLog).one().action, 'unrelated')
        self.assertEqual(scope.count(self.db.connection(), scope.tables()['users']), users_before)

    def test_inventory_is_read_only_and_contains_no_candidate_answers(self):
        _, app = self.prepare()
        before = self.db.query(EmailDelivery).count()
        with self.db.get_bind().connect() as connection:
            report, _ = self.inventory(connection)
        import json
        serialized = json.dumps(report)
        self.assertNotIn(app.email, serialized)
        self.assertNotIn(app.tracking_code, serialized)
        self.assertNotIn(app.motivation, serialized)
        self.assertEqual(self.db.query(EmailDelivery).count(), before)

    def test_second_campaign_blocks_automatic_selection(self):
        self.prepare()
        self.campaign()
        with self.db.get_bind().connect() as connection:
            report, selected = self.inventory(connection)
        self.assertIsNone(selected)
        self.assertTrue(all(item['blocker'] == 'Exactly_one_existing_campaign_required' for item in report['campaigns']))

    def test_changed_campaign_invalidates_plan_before_any_deletion(self):
        campaign, _ = self.prepare()
        with self.db.get_bind().connect() as connection:
            _, selected = self.inventory(connection)
        campaign.title = 'Changed after inventory'
        self.db.commit()
        with self.assertRaisesRegex(scope.ScopeError, 'Campaign_changed_since_inventory'):
            with self.db.get_bind().begin() as connection:
                scope.erase(connection, selected, selected['fingerprint'], today=TODAY)
        self.assertEqual(self.db.query(Application).count(), 1)

    def test_converted_account_blocks_without_deleting_user(self):
        _, app = self.prepare()
        app.converted_user_id = self.users['a'].id
        self.db.commit()
        with self.db.get_bind().connect() as connection:
            report, selected = self.inventory(connection)
        self.assertIsNone(selected)
        self.assertEqual(report['campaigns'][0]['blocker'], 'Converted_accounts_require_separate_review')

    def test_stored_files_and_legacy_links_require_a_reviewed_file_plan(self):
        _, app = self.prepare()
        app.cv_url = '/api/files/' + str(uuid4()) + '/download'
        self.db.add(StoredFile(original_filename='cv.pdf', stored_filename='cv.pdf', file_size=10,
            storage_path='recruitment/cv.pdf', storage_scope='recruitment', entity_type='application', entity_id=app.id))
        self.db.commit()
        with self.db.get_bind().connect() as connection:
            report, selected = self.inventory(connection)
        self.assertIsNone(selected)
        self.assertEqual(report['campaigns'][0]['blocker'], 'Attachments_require_separate_file_cleanup_plan')
        self.assertEqual(self.db.query(StoredFile).count(), 1)

    def test_upcoming_campaign_and_changed_volume_are_never_selected(self):
        campaign, _ = self.prepare()
        campaign.end_date = date(2026, 11, 8)
        self.db.commit()
        with self.db.get_bind().connect() as connection:
            report, selected = self.inventory(connection)
        self.assertIsNone(selected)
        self.assertEqual(report['campaigns'][0]['blocker'], 'Only_expired_pre_November_test_allowed')
        campaign.end_date = date(2026, 10, 17)
        self.db.commit()
        with self.db.get_bind().connect() as connection:
            report, selected = scope.inventory(connection, expected_applications=0, today=TODAY)
        self.assertIsNone(selected)
        self.assertEqual(report['campaigns'][0]['blocker'], 'Application_count_differs_from_reviewed_audit')

    def test_late_failure_rolls_back_all_scoped_deletes(self):
        self.prepare()
        emails = self.db.query(EmailDelivery).count()
        real_require = scope.require
        def fail_late(condition, code):
            if code == 'User_accounts_changed':
                raise scope.ScopeError('Synthetic_post_delete_failure')
            real_require(condition, code)
        with self.assertRaisesRegex(scope.ScopeError, 'Synthetic_post_delete_failure'):
            with self.db.get_bind().begin() as connection:
                _, selected = self.inventory(connection)
                with patch.object(scope, 'require', side_effect=fail_late):
                    scope.erase(connection, selected, selected['fingerprint'], today=TODAY)
        self.db.expire_all()
        self.assertEqual(self.db.query(Application).count(), 1)
        self.assertEqual(self.db.query(EmailDelivery).count(), emails)
