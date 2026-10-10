"""PostgreSQL row-lock and HTTP regressions on a disposable database."""
import os,threading,unittest
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from sqlalchemy import create_engine,select
from sqlalchemy.orm import Session
from fastapi import HTTPException
import test_prelaunch_first_access as fixture
from app.api.routes.first_access import activate,complete_first_access
from app.schemas.first_access import ActivationConfirm,FirstAccessComplete
from app.services import first_access as service
from app.models.user import User
from app.models.audit import AuditLog
from app.models.first_access import ActivationChallenge

class FirstAccessPostgreSQLTests(fixture.FirstAccessTests):
    def make_engine(self):
        url=os.environ["DATABASE_URL"]
        assert "enactspace_pr2b_test_" in url and "@127.0.0.1/" in url
        return create_engine(url,pool_size=6,max_overflow=2)
    def test_concurrent_activation_consumes_code_once(self):
        self.request();barrier=threading.Barrier(2)
        def worker():
            with Session(self.engine,expire_on_commit=False) as db:
                barrier.wait(timeout=8)
                try:
                    activate(ActivationConfirm(identifier=self.user.username,code="12345678",
                        new_password="My own password 2026"),db)
                    return 200
                except HTTPException as exc:
                    db.rollback();return exc.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures=[pool.submit(worker) for _ in range(2)]
            results=[item.result(timeout=15) for item in futures]
        self.assertEqual(sorted(results),[200,400])
        self.db.expire_all()
        self.assertEqual(self.db.query(ActivationChallenge).count(),0)
        self.assertEqual(self.db.query(AuditLog).filter_by(action="account_activated").count(),1)
    def test_suspension_wins_against_waiting_activation(self):
        self.request();attempt=threading.Event();original=service.find_account
        with Session(self.engine) as owner:
            row=owner.execute(select(User).where(User.id==self.user.id).with_for_update()).scalar_one()
            row.status="suspended";owner.flush()
            def observed(db,identifier):attempt.set();return original(db,identifier)
            def worker():
                with Session(self.engine) as db:
                    try:
                        activate(ActivationConfirm(identifier=self.user.username,code="12345678",
                            new_password="My own password 2026"),db)
                        return 200
                    except HTTPException as exc:db.rollback();return exc.status_code
            with patch.object(service,"find_account",side_effect=observed):
                with ThreadPoolExecutor(max_workers=1) as pool:
                    future=pool.submit(worker);self.assertTrue(attempt.wait(8))
                    owner.commit();self.assertEqual(future.result(timeout=15),400)
        self.db.expire_all();self.assertTrue(self.user.credential_setup_required)
    def test_concurrent_profile_completion_records_one_result(self):
        self.prepare_signed();barrier=threading.Barrier(2)
        def worker(name):
            with Session(self.engine,expire_on_commit=False) as db:
                user=db.get(User,self.user.id);barrier.wait(timeout=8)
                return complete_first_access(FirstAccessComplete(**self.profile(first_name=name)),db,user)
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures=[pool.submit(worker,name) for name in ("First","Second")]
            results=[item.result(timeout=15) for item in futures]
        self.assertEqual(results[0]["completed_at"],results[1]["completed_at"])
        self.db.expire_all();self.assertIn(self.user.first_name,{"First","Second"})
        self.assertEqual(self.db.query(AuditLog).filter_by(action="first_access_completed").count(),1)
    def test_year_changed_while_onboarding_waits_is_rejected(self):
        from datetime import date
        from app.models.season import Season
        self.prepare_signed();old=self.current_year()
        new=Season(name="2027–2028",start_date=date(2027,10,1),is_current=False,archived=False)
        self.db.add(new);self.db.commit()
        attempted=threading.Event();original=service.lock_year_transition
        with Session(self.engine) as owner:
            original(owner)
            old_row=owner.get(Season,old.id);old_row.is_current=False;old_row.archived=True;owner.flush()
            owner.get(Season,new.id).is_current=True;owner.flush()
            def observed(db):attempted.set();return original(db)
            def worker():
                with Session(self.engine) as db:
                    try:
                        complete_first_access(FirstAccessComplete(**self.profile(academic_year_id=old.id)),db,db.get(User,self.user.id))
                        return 200
                    except HTTPException as exc:db.rollback();return exc.status_code
            with patch.object(service,"lock_year_transition",side_effect=observed):
                with ThreadPoolExecutor(max_workers=1) as pool:
                    future=pool.submit(worker);self.assertTrue(attempted.wait(8))
                    owner.commit();self.assertEqual(future.result(timeout=15),409)
        self.db.expire_all();self.assertTrue(self.user.onboarding_required)

    def test_concurrent_recoveries_reject_stale_contact(self):
        from app.api.routes.first_access import recover_contact
        from app.schemas.first_access import FirstAccessRecovery
        self.used_account();self.make_admin();barrier=threading.Barrier(2)
        expected_email=self.user.email
        def worker(email):
            with Session(self.engine,expire_on_commit=False) as db:
                actor=db.get(User,self.sg.id);barrier.wait(timeout=8)
                try:
                    recover_contact(self.user.id,FirstAccessRecovery(**self.recovery_payload(email=email,expected_email=expected_email)),db,actor)
                    return 200
                except HTTPException as exc:db.rollback();return exc.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures=[pool.submit(worker,email) for email in ("first@example.com","second@example.com")]
            results=[item.result(timeout=15) for item in futures]
        self.assertEqual(sorted(results),[200,409]);self.db.expire_all()
        self.assertEqual(self.db.query(AuditLog).filter_by(action="account_contact_recovery_prepared").count(),1)

if __name__=="__main__":unittest.main()
