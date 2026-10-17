"""Concurrent reset attempts in an explicitly disposable PostgreSQL database."""
import os,secrets,unittest,importlib.util
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from pathlib import Path
from unittest.mock import patch
from fastapi import HTTPException
from sqlalchemy import create_engine,text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import sessionmaker
from alembic.migration import MigrationContext
from alembic.operations import Operations
import app.models.base
from app.db.database import Base
from app.models.user import User,PasswordResetOtp
from app.api.routes import auth
from app.schemas.auth import PasswordResetConfirm
from app.services.session_service import utc_now
from app.core.security import hash_password,verify_password

class PostgreSQLResetGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        url=os.environ.get("TEST_DATABASE_URL","")
        if not url:raise unittest.SkipTest("Disposable PostgreSQL URL required")
        if not (make_url(url).database or "").startswith("enactspace_pr2b_test_"):
            raise RuntimeError("Only explicitly named disposable test databases are allowed")
        cls.engine=create_engine(url)
        Base.metadata.create_all(cls.engine)
        cls.Session=sessionmaker(bind=cls.engine,autoflush=False)

    @classmethod
    def tearDownClass(cls):cls.engine.dispose()

    def setUp(self):
        self.email=secrets.token_hex(10)+"@example.org"
        with self.Session() as db:
            user=User(first_name="Reset",last_name="Test",email=self.email,password_hash="unchanged-test-hash",
                      is_active=True,email_verified=True,status="active")
            db.add(user);db.flush();self.user_id=user.id
            db.add(PasswordResetOtp(user_id=user.id,otp_hash=hash_password("123456"),expires_at=utc_now()+timedelta(minutes=15)))
            db.commit()

    def attempt(self,otp):
        with self.Session() as db:
            try:
                auth.confirm_password_reset(PasswordResetConfirm(email=self.email,otp=otp,new_password="New-test-password-2026!"),db=db)
                return 200
            except HTTPException as error:
                db.rollback();return error.status_code

    def test_parallel_wrong_attempts_cannot_exceed_budget(self):
        with ThreadPoolExecutor(max_workers=8) as workers:
            outcomes=list(workers.map(self.attempt,["000000"]*16))
        self.assertEqual(outcomes,[400]*16)
        with self.Session() as db:
            self.assertIsNone(db.query(PasswordResetOtp).filter_by(user_id=self.user_id).first())
            self.assertEqual(db.get(User,self.user_id).password_hash,"unchanged-test-hash")
        self.assertEqual(self.attempt("123456"),400)

    def test_concurrent_valid_code_is_consumed_once(self):
        with ThreadPoolExecutor(max_workers=2) as workers:
            outcomes=list(workers.map(self.attempt,["123456"]*2))
        self.assertEqual(sorted(outcomes),[200,400])
        with self.Session() as db:
            self.assertIsNone(db.query(PasswordResetOtp).filter_by(user_id=self.user_id).first())
            self.assertTrue(verify_password("New-test-password-2026!",db.get(User,self.user_id).password_hash))

    def test_migration_roundtrip_preserves_existing_challenge_and_defaults(self):
        source=Path("alembic/versions/20261007_0026_password_reset_attempts.py")
        spec=importlib.util.spec_from_file_location("reset_guard_migration",source)
        migration=importlib.util.module_from_spec(spec);spec.loader.exec_module(migration)
        with self.engine.begin() as connection:
            before=connection.execute(text("SELECT user_id, otp_hash FROM password_reset_otps ORDER BY user_id")).all()
            ops=Operations(MigrationContext.configure(connection))
            with patch.object(migration,"op",ops):
                migration.downgrade();migration.upgrade()
            after=connection.execute(text("SELECT user_id, otp_hash FROM password_reset_otps ORDER BY user_id")).all()
            self.assertEqual(before,after)
            self.assertEqual(connection.execute(text("SELECT count(*) FROM password_reset_otps WHERE failed_attempts <> 0")).scalar(),0)

if __name__=="__main__":unittest.main()
