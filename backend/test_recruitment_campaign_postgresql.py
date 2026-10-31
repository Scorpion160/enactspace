"""Campaign closure coordination, only on a guarded disposable PostgreSQL DB."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Event
import time
import unittest
import uuid
from unittest.mock import patch

from sqlalchemy import text
from fastapi import HTTPException

from app.api.routes import recruitment
from app.core.time import utc_now
from app.models.recruitment import Application, RecruitmentCampaign
from app.models.user import User
from app.schemas.recruitment import ApplicationCreate, RecruitmentCampaignUpdate
from app.services.recruitment_questionnaire import effective_questions, questionnaire_version
import test_operational_integrity_postgresql as fixture


class RecruitmentCampaignPostgreSQLTests(unittest.TestCase):
    setUpClass = classmethod(fixture.OperationalIntegrityPostgreSQLTests.setUpClass.__func__)
    tearDownClass = classmethod(fixture.OperationalIntegrityPostgreSQLTests.tearDownClass.__func__)
    _user = fixture.OperationalIntegrityPostgreSQLTests._user

    def campaign(self):
        with self.Session() as db:
            campaign = RecruitmentCampaign(title='Isolated November rehearsal', is_active=True,
                start_date=utc_now().date() - timedelta(days=1), end_date=utc_now().date() + timedelta(days=1))
            db.add(campaign)
            db.commit()
            return campaign.id

    def payload(self, campaign_id):
        return ApplicationCreate(campaign_id=campaign_id, first_name='Synthetic', last_name='Candidate',
            email=f'{uuid.uuid4()}@example.org', phone='+221770000000', gender='non_precise',
            department='Génie Électrique', study_level='DIC1',
            questionnaire_answers={q['id']: 'A synthetic answer for an isolated rehearsal.' for q in effective_questions(None)},
            questionnaire_version=questionnaire_version(None))

    def test_distinct_submissions_can_share_the_campaign_lock(self):
        campaign_id = self.campaign()
        with self.Session() as first, self.Session() as second:
            recruitment.get_campaign_or_404(first, str(campaign_id), submission_lock=True)
            second.execute(text("SET LOCAL lock_timeout = '1s'"))
            recruitment.get_campaign_or_404(second, str(campaign_id), submission_lock=True)
            first.rollback()
            second.rollback()

    def test_manual_closure_waits_for_an_inflight_submission(self):
        campaign_id = self.campaign()
        admin_id = self._user(roles=('administrateur',))
        inflight, release, closing = Event(), Event(), Event()
        closer = {}

        def pause_before_commit(*_):
            inflight.set()
            if not release.wait(10):
                raise RuntimeError('Isolated test handoff timed out')

        def submit():
            with self.Session() as db:
                return recruitment.submit_application(self.payload(campaign_id), db=db)

        def close():
            with self.Session() as db:
                closer['pid'] = db.execute(text('SELECT pg_backend_pid()')).scalar_one()
                closing.set()
                return recruitment.update_campaign(str(campaign_id), RecruitmentCampaignUpdate(is_active=False),
                                                    db=db, current_user=db.get(User, admin_id))

        with patch.object(recruitment, 'notify_recruitment_responsibles', side_effect=pause_before_commit):
            with ThreadPoolExecutor(max_workers=2) as workers:
                submission = workers.submit(submit)
                try:
                    self.assertTrue(inflight.wait(5))
                    closure = workers.submit(close)
                    self.assertTrue(closing.wait(5))
                    observed_lock = False
                    deadline = time.monotonic() + 5
                    while time.monotonic() < deadline:
                        with self.engine.connect() as connection:
                            wait = connection.execute(text('SELECT wait_event_type FROM pg_stat_activity WHERE pid=:pid'),
                                                      {'pid': closer['pid']}).scalar_one_or_none()
                        if wait == 'Lock':
                            observed_lock = True
                            break
                        if closure.done():
                            break
                        time.sleep(0.02)
                    self.assertTrue(observed_lock, 'Closure must wait for the submission transaction')
                finally:
                    release.set()
                self.assertEqual(submission.result(timeout=10)['status'], 'submitted')
                self.assertFalse(closure.result(timeout=10).is_active)
        with self.Session() as db:
            self.assertEqual(db.query(Application).filter_by(campaign_id=campaign_id).count(), 1)

    def test_new_submission_after_manual_closure_creates_nothing(self):
        campaign_id = self.campaign()
        admin_id = self._user(roles=('administrateur',))
        with self.Session() as db:
            recruitment.update_campaign(str(campaign_id), RecruitmentCampaignUpdate(is_active=False),
                                        db=db, current_user=db.get(User, admin_id))
        with self.Session() as db:
            with self.assertRaises(HTTPException) as error:
                recruitment.submit_application(self.payload(campaign_id), db=db)
            self.assertEqual(error.exception.status_code, 400)
            db.rollback()
            self.assertEqual(db.query(Application).filter_by(campaign_id=campaign_id).count(), 0)


if __name__ == '__main__':
    unittest.main()
