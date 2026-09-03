"""Run only against an explicitly named, isolated local PR-2B test database."""
import os
import secrets
import unittest
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch

from test_auth_sessions import SessionLifecycleScenarios
from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from fastapi import HTTPException, Request
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

from app.api.routes import auth
from app.core.config import settings
from app.models.account import AuthSession
from app.models.user import User
from app.schemas.auth import RefreshTokenRequest
from app.services.session_service import hash_refresh_token


class PostgreSQLSessionTests(SessionLifecycleScenarios, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw_url = os.environ.get("TEST_DATABASE_URL")
        if not raw_url:
            raise unittest.SkipTest("TEST_DATABASE_URL missing: real PostgreSQL tests NOT RUN")
        url = make_url(raw_url)
        if (url.get_backend_name() != "postgresql" or
                url.host not in {"localhost", "127.0.0.1", "::1"} or
                not (url.database or "").startswith("enactspace_pr2b_test")):
            raise RuntimeError("Refusing a non-local or non-PR-2B test database")
        cls.schema = "pr2b_" + secrets.token_hex(12)
        cls.admin_engine = create_engine(url, connect_args={"connect_timeout": 5})
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA "{cls.schema}"'))
        cls.addClassCleanup(cls._cleanup)
        isolated = url.update_query_dict({"options": f"-csearch_path={cls.schema}"})
        cls.engine = create_engine(isolated, connect_args={"connect_timeout": 5})
        cls.addClassCleanup(cls.engine.dispose)
        cls.Session = sessionmaker(bind=cls.engine, autoflush=False)
        config = Config("alembic.ini")
        heads = ScriptDirectory.from_config(config).get_heads()
        if len(heads) != 1:
            raise AssertionError(f"Expected one Alembic head, got {heads}")
        with patch.object(settings, "DATABASE_URL", isolated.render_as_string(hide_password=False)):
            command.upgrade(config, "head")
        with cls.engine.connect() as connection:
            if connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one() != heads[0]:
                raise AssertionError("Fresh PostgreSQL migration did not reach head")

    @classmethod
    def _cleanup(cls):
        # Only this run's generated schema is ever dropped, never public/the DB.
        if not cls.schema.startswith("pr2b_") or len(cls.schema) != 29:
            raise RuntimeError("Unsafe test schema cleanup target")
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{cls.schema}" CASCADE'))
        cls.admin_engine.dispose()

    def test_real_concurrent_transactions_allow_exactly_one_rotation(self):
        for _ in range(5):
            pair = self.login()
            row_id = self.sessions().filter(AuthSession.refresh_token_hash == hash_refresh_token(pair.refresh_token)).one().id
            self.db.rollback()
            ready = Barrier(3, timeout=10)

            def compete():
                with self.Session() as db:
                    pid = db.execute(text("SELECT pg_backend_pid()")).scalar_one()
                    self.assertEqual(db.execute(text("SHOW transaction_isolation")).scalar_one(), "read committed")
                    ready.wait()
                    try:
                        result = auth.refresh_access_token(
                            RefreshTokenRequest(refresh_token=pair.refresh_token), db=db,
                        )
                        return pid, result
                    except HTTPException as failure:
                        db.rollback()
                        self.assertEqual(failure.status_code, 401)
                        return pid, None

            with ThreadPoolExecutor(max_workers=3) as pool:
                results = list(pool.map(lambda _: compete(), range(3)))
            self.assertEqual(len({pid for pid, _ in results}), 3)
            winners = [result for _, result in results if result is not None]
            self.assertEqual(len(winners), 1)
            self.db.expire_all()
            row = self.db.get(AuthSession, row_id)
            self.assertIsNone(row.revoked_at)
            self.assertEqual(row.refresh_token_hash, hash_refresh_token(winners[0].refresh_token))
            self.assertEqual(self.sessions().filter(AuthSession.id == row_id).count(), 1)
            self.reject(pair.refresh_token)

    def test_postgresql_constraints_indexes_and_timezone(self):
        pair = self.login()
        row = self.sessions().one()
        inspector = inspect(self.engine)
        indexes = {index["name"] for index in inspector.get_indexes("auth_sessions")}
        self.assertTrue({"ix_auth_sessions_user_id", "ix_auth_sessions_expires_at",
                         "ix_auth_sessions_revoked_at"}.issubset(indexes))
        self.db.add(AuthSession(user_id=self.user.id, refresh_token_hash=row.refresh_token_hash,
                                expires_at=row.expires_at))
        with self.assertRaises(IntegrityError):
            self.db.flush()
        self.db.rollback()
        self.db.add(AuthSession(user_id=self.user.id, refresh_token_hash=secrets.token_hex(32),
                                expires_at=row.expires_at, platform="invalid-platform"))
        with self.assertRaises(IntegrityError):
            self.db.flush()
        self.db.rollback()
        self.db.execute(text("SET TIME ZONE 'Pacific/Auckland'"))
        self.refresh(pair.refresh_token)

    def test_concurrent_revocation_and_rotation_do_not_deadlock_or_resurrect(self):
        for mode in ("current", "all", "session"):
            with self.subTest(mode=mode):
                pair = self.login()
                user_id = self.user.id
                session_id = self.sessions().filter(
                    AuthSession.refresh_token_hash == hash_refresh_token(pair.refresh_token),
                ).one().id
                self.db.rollback()
                ready = Barrier(2, timeout=10)

                def compete(operation):
                    with self.Session() as db:
                        db.execute(text("SET LOCAL lock_timeout = '5s'"))
                        actor = db.get(User, user_id)
                        ready.wait()
                        if operation == "revoke":
                            if mode == "all":
                                auth.logout_all(db=db, current_user=actor)
                            elif mode == "session":
                                auth.revoke_session(str(session_id), db=db, current_user=actor)
                            else:
                                auth.logout(
                                    RefreshTokenRequest(refresh_token=pair.refresh_token),
                                    Request({"type": "http", "headers": [
                                        (b"authorization", f"Bearer {pair.access_token}".encode()),
                                    ]}), db=db,
                                )
                            return None
                        try:
                            return auth.refresh_access_token(
                                RefreshTokenRequest(refresh_token=pair.refresh_token), db=db,
                            )
                        except HTTPException as failure:
                            db.rollback()
                            self.assertEqual(failure.status_code, 401)
                            return None

                with ThreadPoolExecutor(max_workers=2) as pool:
                    results = list(pool.map(compete, ("revoke", "rotate")))
                self.db.expire_all()
                self.assertIsNotNone(self.db.get(AuthSession, session_id).revoked_at)
                self.reject(pair.refresh_token)
                for rotated in results:
                    if rotated is not None:
                        self.reject(rotated.refresh_token)


if __name__ == "__main__":
    unittest.main()
