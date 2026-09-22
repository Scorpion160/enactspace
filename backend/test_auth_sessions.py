"""Session lifecycle regression tests; PostgreSQL reuses these same scenarios."""
import json
import os
import runpy
import secrets
import unittest
from datetime import timedelta, timezone
from unittest.mock import patch

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", secrets.token_urlsafe(48))
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException, Request
from alembic import context
from alembic.config import Config
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.deps import get_current_user
from app.api.routes import auth
from app.core.security import decode_access_token_payload, hash_password
from app.core.config import settings
from app.db.database import Base
from app.models.account import AuthSession
from app.models.audit import AuditLog
from app.models.user import User
from app.schemas.auth import LoginRequest, RefreshTokenRequest
from app.services.session_service import (
    hash_refresh_token, revoke_user_sessions, rotate_refresh_token,
    session_seconds_remaining, utc_now,
)


class SessionLifecycleScenarios:
    def setUp(self):
        self.db = self.Session()
        self.password = secrets.token_urlsafe(24)
        self.user = User(
            first_name="Session", last_name="Test",
            email=f"{secrets.token_hex(12)}@example.test",
            password_hash=hash_password(self.password),
            status="active", is_active=True, email_verified=True,
        )
        self.db.add(self.user)
        self.db.commit()

    def tearDown(self):
        self.db.rollback()
        self.db.close()

    def login(self):
        return auth.login(
            LoginRequest(email=self.user.email, password=self.password, platform="android"),
            Request({"type": "http", "headers": []}), db=self.db,
        )

    def refresh(self, credential):
        return auth.refresh_access_token(RefreshTokenRequest(refresh_token=credential), db=self.db)

    def sessions(self):
        return self.db.query(AuthSession).filter(AuthSession.user_id == self.user.id)

    def reject(self, credential):
        with self.assertRaises(HTTPException) as failure:
            self.refresh(credential)
        self.assertEqual(failure.exception.status_code, 401)
        self.assertEqual(failure.exception.detail, "Session invalide ou expirée")
        self.db.rollback()

    def logout(self, pair, *, bearer=True):
        headers = [(b"authorization", f"Bearer {pair.access_token}".encode())] if bearer else []
        return auth.logout(RefreshTokenRequest(refresh_token=pair.refresh_token),
                           Request({"type": "http", "headers": headers}), db=self.db)

    def test_login_creates_hashed_session_and_compatible_claims(self):
        pair = self.login()
        row = self.sessions().one()
        self.assertEqual(row.refresh_token_hash, hash_refresh_token(pair.refresh_token))
        self.assertNotEqual(row.refresh_token_hash, pair.refresh_token)
        self.assertGreaterEqual(len(pair.refresh_token), 80)
        claims = decode_access_token_payload(pair.access_token)
        self.assertEqual(claims["sub"], str(self.user.id))
        self.assertEqual(claims["sid"], str(row.id))
        self.assertTrue(claims["jti"])
        self.assertEqual(pair.token_type, "bearer")

    def test_rotation_and_replay_keep_one_session(self):
        pair = self.login()
        expiry = self.sessions().one().expires_at
        rotated = self.refresh(pair.refresh_token)
        self.assertNotEqual(pair.refresh_token, rotated.refresh_token)
        self.assertNotEqual(pair.access_token, rotated.access_token)
        self.reject(pair.refresh_token)
        self.assertEqual(self.sessions().count(), 1)
        self.assertEqual(self.sessions().one().expires_at, expiry)
        self.assertEqual(self.sessions().one().refresh_token_hash, hash_refresh_token(rotated.refresh_token))
        self.refresh(rotated.refresh_token)

    def test_failed_transaction_does_not_consume_credential(self):
        pair = self.login()
        rotate_refresh_token(self.db, pair.refresh_token)
        self.db.rollback()
        self.refresh(pair.refresh_token)

    def test_current_logout_is_idempotent_and_preserves_other_device(self):
        first, second = self.login(), self.login()
        self.assertEqual(self.logout(first).status_code, 204)
        self.assertEqual(self.logout(first).status_code, 204)
        self.reject(first.refresh_token)
        self.refresh(second.refresh_token)
        with self.assertRaises(HTTPException):
            get_current_user(token=first.access_token, db=self.db)

    def test_logout_with_refresh_only_and_unknown_credential(self):
        pair = self.login()
        self.assertEqual(self.logout(pair, bearer=False).status_code, 204)
        self.reject(pair.refresh_token)
        response = auth.logout(
            RefreshTokenRequest(refresh_token=secrets.token_urlsafe(64)),
            Request({"type": "http", "headers": []}), db=self.db,
        )
        self.assertEqual(response.status_code, 204)

    def test_logout_valid_access_identifies_rotated_session(self):
        old = self.login()
        new = self.refresh(old.refresh_token)
        self.logout(old)
        self.reject(new.refresh_token)

    def test_logout_all_revokes_independent_sessions_without_erasing_audit(self):
        first, second = self.login(), self.login()
        self.db.add(AuditLog(user_id=self.user.id, action="prior_history"))
        self.db.commit()
        result = auth.logout_all(db=self.db, current_user=self.user)
        self.assertEqual(result["revoked_sessions"], 2)
        self.reject(first.refresh_token)
        self.reject(second.refresh_token)
        logs = self.db.query(AuditLog).filter(AuditLog.user_id == self.user.id).all()
        self.assertTrue({"prior_history", "logout_all"}.issubset({log.action for log in logs}))
        serialized = json.dumps([log.new_value for log in logs], default=str)
        for credential in (first.access_token, first.refresh_token, second.refresh_token):
            self.assertNotIn(credential, serialized)

    def test_expired_revoked_and_unknown_tokens_share_generic_failure(self):
        for field in ("expires_at", "revoked_at"):
            pair = self.login()
            row = self.sessions().filter(AuthSession.refresh_token_hash == hash_refresh_token(pair.refresh_token)).one()
            setattr(row, field, utc_now() - timedelta(seconds=2))
            self.db.commit()
            self.reject(pair.refresh_token)
        self.reject(secrets.token_urlsafe(64))

    def test_ineligible_accounts_cannot_refresh(self):
        pair = self.login()
        for field, value in (
            ("is_active", False), ("email_verified", False),
            ("status", "pending"), ("status", "rejected"),
            ("status", "suspended"), ("status", "inactive"), ("status", "deleted"),
        ):
            with self.subTest(field=field, value=value):
                previous = getattr(self.user, field)
                setattr(self.user, field, value)
                self.db.commit()
                self.reject(pair.refresh_token)
                setattr(self.user, field, previous)
                self.db.commit()
        self.user.status = "alumni"
        self.db.commit()
        self.refresh(pair.refresh_token)

    def test_remaining_expiry_is_not_reset_and_is_timezone_safe(self):
        pair = self.login()
        row = self.sessions().one()
        row.expires_at = utc_now() + timedelta(minutes=5)
        self.db.commit()
        rotated = self.refresh(pair.refresh_token)
        self.assertLessEqual(rotated.refresh_expires_in, 300)
        self.assertGreater(rotated.refresh_expires_in, 290)
        row.expires_at = (utc_now() + timedelta(minutes=5)).replace(tzinfo=timezone.utc).astimezone(
            timezone(timedelta(hours=7)),
        )
        self.assertTrue(290 <= session_seconds_remaining(row) <= 300)

    def test_revocation_preserves_a_pending_password_change(self):
        pair = self.login()
        self.password = secrets.token_urlsafe(24)
        updated_hash = hash_password(self.password)
        self.user.password_hash = updated_hash
        self.assertEqual(revoke_user_sessions(self.db, self.user.id), 1)
        self.db.commit()
        self.assertEqual(self.user.password_hash, updated_hash)
        self.reject(pair.refresh_token)
        self.login()


class SQLiteSessionLifecycleTests(SessionLifecycleScenarios, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = create_engine("sqlite://", poolclass=StaticPool,
                                   connect_args={"check_same_thread": False})
        Base.metadata.create_all(cls.engine)
        cls.Session = sessionmaker(bind=cls.engine, autoflush=False)

    @classmethod
    def tearDownClass(cls):
        cls.engine.dispose()

    def test_alembic_config_preserves_url_encoded_connection_options(self):
        # This checks URL handling only, not PostgreSQL migrations/transactions.
        url = (
            "postgresql+psycopg://127.0.0.1/enactspace_pr2b_test"
            "?options=-csearch_path%3Dpr2b_validation"
        )
        config = Config("alembic.ini")
        with (
            patch.object(settings, "DATABASE_URL", url),
            patch.object(context, "config", config, create=True),
            patch.object(context, "is_offline_mode", return_value=True),
            patch.object(context, "configure") as configure,
            patch.object(context, "begin_transaction"),
            patch.object(context, "run_migrations"),
            patch("logging.config.fileConfig"),
        ):
            runpy.run_path("alembic/env.py")
        self.assertEqual(config.get_main_option("sqlalchemy.url"), url)
        self.assertEqual(configure.call_args.kwargs["url"], url)


if __name__ == "__main__":
    unittest.main()
