"""PR-5 PostgreSQL 16 migration, lease, and lock-fencing acceptance."""

import os
import secrets
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from threading import Barrier, Event, Lock
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from fastapi import HTTPException
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

import app.api.routes.product_services as product_services_module
import app.models.base  # noqa: F401
import app.services.push_worker_service as push_worker_service
from app.api.routes import account, auth, product_services
from app.core.config import settings
from app.core.security import create_access_token
from app.models.account import AuthSession, UserPreference
from app.models.notification import Notification
from app.models.product_services import AppInstallation, PushDelivery
from app.models.user import User
from app.schemas.account import UserPreferenceUpdate
from app.schemas.product_services import InstallationUpsert, PushTokenUpdate
from app.services.notification_service import create_notification
from app.services.push_locking import lock_push_preference, lock_push_user
from app.services.push_worker_service import (
    claim_push_deliveries,
    process_push_delivery,
)


class EventProvider:
    def __init__(self):
        self.started = Event()
        self._lock = Lock()
        self.messages = []

    def send(self, message):
        with self._lock:
            self.messages.append(message)
        self.started.set()
        return "projects/test/messages/pg"


class PushLifecyclePostgreSQLTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw_url = os.environ.get("TEST_DATABASE_URL")
        if not raw_url:
            raise unittest.SkipTest("TEST_DATABASE_URL missing: real PostgreSQL tests NOT RUN")
        url = make_url(raw_url)
        if (
            url.get_backend_name() != "postgresql"
            or url.host not in {"localhost", "127.0.0.1", "::1"}
            or not (url.database or "").startswith("enactspace_pr2b_test")
        ):
            raise RuntimeError("Refusing a non-local or non-test PostgreSQL database")
        cls.schema = "pr5_" + secrets.token_hex(12)
        cls.admin = create_engine(url, connect_args={"connect_timeout": 5})
        with cls.admin.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA "{cls.schema}"'))
        isolated = url.update_query_dict({"options": f"-csearch_path={cls.schema}"})
        cls.url = isolated.render_as_string(hide_password=False)
        cls.engine = create_engine(cls.url, connect_args={"connect_timeout": 5})
        cls.Session = sessionmaker(bind=cls.engine, autoflush=False)
        cls.original_key = settings.PUSH_TOKEN_ENCRYPTION_KEY
        cls.original_push_enabled = settings.PUSH_ENABLED
        settings.PUSH_TOKEN_ENCRYPTION_KEY = (
            "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA="
        )
        settings.PUSH_ENABLED = True

        config = Config("alembic.ini")
        with patch.object(settings, "DATABASE_URL", cls.url):
            command.upgrade(config, "20260906_0005")
            command.upgrade(config, "20260906_0006")
        if "processing_started_at" not in {
            column["name"]
            for column in inspect(cls.engine).get_columns("push_deliveries")
        }:
            raise AssertionError("processing lease column missing after upgrade")
        with patch.object(settings, "DATABASE_URL", cls.url):
            command.downgrade(config, "20260906_0005")
        if "push_deliveries" in inspect(cls.engine).get_table_names():
            raise AssertionError("push outbox survived downgrade")
        with patch.object(settings, "DATABASE_URL", cls.url):
            command.upgrade(config, "head")

    @classmethod
    def tearDownClass(cls):
        settings.PUSH_TOKEN_ENCRYPTION_KEY = cls.original_key
        settings.PUSH_ENABLED = cls.original_push_enabled
        cls.engine.dispose()
        if cls.schema.startswith("pr5_") and len(cls.schema) == 28:
            with cls.admin.begin() as connection:
                connection.execute(text(f'DROP SCHEMA "{cls.schema}" CASCADE'))
        cls.admin.dispose()

    def setUp(self):
        # Claim tests operate on the whole outbox, so isolate their rows while
        # retaining the migrated schema for the complete acceptance run.
        with self.engine.begin() as connection:
            connection.execute(text("DELETE FROM push_deliveries"))
            connection.execute(text("DELETE FROM notifications"))

    def _identity(self, *, token=None):
        db = self.Session()
        user = User(
            first_name="Push",
            last_name="Test",
            email=f"push-{uuid.uuid4()}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        db.add(user)
        db.flush()
        preference = UserPreference(
            user_id=user.id,
            notification_push_enabled=True,
        )
        installation = AppInstallation(
            user_id=user.id,
            installation_key=uuid.uuid4(),
            platform="android",
        )
        db.add_all([preference, installation])
        db.commit()
        if token:
            product_services.register_push_token(
                str(installation.id), PushTokenUpdate(token=token), db, user
            )
        ids = (user.id, installation.id)
        db.close()
        return ids

    def _delivery(self, token=None):
        user_id, installation_id = self._identity(
            token=token or f"old-token-{uuid.uuid4()}"
        )
        db = self.Session()
        notification = create_notification(
            db,
            user_id=user_id,
            title="Titre",
            message="Corps",
            type="task",
            dedupe=False,
        )
        db.commit()
        delivery_id = db.query(PushDelivery).filter(
            PushDelivery.notification_id == notification.id
        ).one().id
        db.close()
        return user_id, installation_id, delivery_id

    def _registration_thread(self, user_id, installation_id, attempted):
        original = product_services_module.lock_user_installation

        def observed_lock(db, target_user_id, target_installation_id):
            attempted.set()
            return original(db, target_user_id, target_installation_id)

        db = self.Session()
        try:
            user = db.get(User, user_id)
            with patch.object(
                product_services_module,
                "lock_user_installation",
                observed_lock,
            ):
                return product_services.register_push_token(
                    str(installation_id),
                    PushTokenUpdate(token="stale-registration"),
                    db,
                    user,
                )
        finally:
            db.close()

    def _installation_thread(self, user_id, installation_key, token, attempted):
        original = product_services_module.lock_push_preference

        def observed_lock(db, target_user_id):
            attempted.set()
            return original(db, target_user_id)

        db = self.Session()
        try:
            user = db.get(User, user_id)
            with patch.object(
                product_services_module,
                "lock_push_preference",
                observed_lock,
            ):
                return product_services.register_installation(
                    InstallationUpsert(
                        installation_key=installation_key,
                        platform="android",
                    ),
                    db,
                    user,
                    token,
                )
        finally:
            db.close()

    def _auth_token(self, user_id):
        db = self.Session()
        auth_session = AuthSession(
            user_id=user_id,
            refresh_token_hash=uuid.uuid4().hex + uuid.uuid4().hex,
            expires_at=datetime.utcnow() + timedelta(days=1),
            platform="android",
        )
        db.add(auth_session)
        db.commit()
        token = create_access_token(str(user_id), session_id=str(auth_session.id))
        db.close()
        return token

    def _blocked_worker(self, delivery_id, provider, attempted):
        original = push_worker_service.lock_user_installation

        def observed_lock(db, user_id, installation_id):
            attempted.set()
            return original(db, user_id, installation_id)

        db = self.Session()
        try:
            with patch.object(
                push_worker_service,
                "lock_user_installation",
                observed_lock,
            ):
                return process_push_delivery(db, delivery_id, provider)
        finally:
            db.close()

    def test_01_migration_and_unique_token_constraint(self):
        with self.engine.connect() as connection:
            version = connection.execute(
                text("SELECT version_num FROM alembic_version")
            ).scalar_one()
        self.assertEqual(version, "20260913_0009")
        user_id, installation_id = self._identity(token="unique-token")
        db = self.Session()
        second = AppInstallation(
            user_id=user_id,
            installation_key=uuid.uuid4(),
            platform="ios",
            push_provider="fcm",
            push_token_ciphertext="cipher-2",
            push_token_hash=db.get(AppInstallation, installation_id).push_token_hash,
            push_token_updated_at=datetime.utcnow(),
        )
        db.add(second)
        with self.assertRaises(IntegrityError):
            db.flush()
        db.rollback()
        db.close()

    def test_02_pending_retry_and_lease_boundaries(self):
        user_id, installation_id = self._identity()
        db = self.Session()
        now = datetime.utcnow()
        notifications = [
            Notification(user_id=user_id, title=str(index), message="B", type="task")
            for index in range(4)
        ]
        db.add_all(notifications)
        db.flush()
        pending = PushDelivery(
            notification_id=notifications[0].id,
            installation_id=installation_id,
            token_hash_snapshot="1" * 64,
            next_attempt_at=now - timedelta(seconds=1),
        )
        retry = PushDelivery(
            notification_id=notifications[1].id,
            installation_id=installation_id,
            token_hash_snapshot="2" * 64,
            status="retry",
            next_attempt_at=now - timedelta(seconds=1),
        )
        expired = PushDelivery(
            notification_id=notifications[2].id,
            installation_id=installation_id,
            token_hash_snapshot="3" * 64,
            status="processing",
            processing_started_at=now - timedelta(minutes=6),
        )
        fresh = PushDelivery(
            notification_id=notifications[3].id,
            installation_id=installation_id,
            token_hash_snapshot="4" * 64,
            status="processing",
            processing_started_at=now,
        )
        db.add_all([pending, retry, expired, fresh])
        db.commit()
        claimed = claim_push_deliveries(db, limit=10, now=now)
        self.assertEqual(set(claimed), {pending.id, retry.id, expired.id})
        self.assertNotIn(fresh.id, claimed)
        self.assertEqual(claim_push_deliveries(db, limit=10, now=now), [])
        db.close()

    def test_03_two_workers_claim_one_pending_row_once(self):
        _, _, delivery_id = self._delivery()
        barrier = Barrier(2)

        def claim():
            db = self.Session()
            barrier.wait()
            try:
                return claim_push_deliveries(db, limit=1)
            finally:
                db.close()

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: claim(), range(2)))
        self.assertEqual([item for batch in results for item in batch], [delivery_id])

    def test_04_two_workers_claim_one_expired_lease_once(self):
        _, _, delivery_id = self._delivery()
        db = self.Session()
        delivery = db.get(PushDelivery, delivery_id)
        delivery.status = "processing"
        delivery.processing_started_at = datetime.utcnow() - timedelta(minutes=6)
        db.commit()
        db.close()
        barrier = Barrier(2)

        def reclaim():
            session = self.Session()
            barrier.wait()
            try:
                return claim_push_deliveries(session, limit=1)
            finally:
                session.close()

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: reclaim(), range(2)))
        self.assertEqual([item for batch in results for item in batch], [delivery_id])

    def test_05_logout_all_wins_against_stale_registration(self):
        user_id, installation_id = self._identity()
        owner = self.Session()
        user = owner.get(User, user_id)
        lock_push_user(owner, user_id)
        attempted = Event()
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(
                self._registration_thread, user_id, installation_id, attempted
            )
            self.assertTrue(attempted.wait(5))
            auth.logout_all(owner, user)
            with self.assertRaises(HTTPException):
                future.result(timeout=5)
        owner.close()
        db = self.Session()
        installation = db.get(AppInstallation, installation_id)
        self.assertIsNotNone(installation.revoked_at)
        self.assertIsNone(installation.push_token_hash)
        db.close()

    def test_06_push_false_wins_against_stale_registration(self):
        user_id, installation_id = self._identity()
        owner = self.Session()
        user = owner.get(User, user_id)
        lock_push_preference(owner, user_id)
        attempted = Event()
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(
                self._registration_thread, user_id, installation_id, attempted
            )
            self.assertTrue(attempted.wait(5))
            account.update_preferences(
                UserPreferenceUpdate(notification_push_enabled=False), owner, user
            )
            with self.assertRaises(HTTPException):
                future.result(timeout=5)
        owner.close()
        db = self.Session()
        self.assertFalse(db.get(UserPreference, user_id).notification_push_enabled)
        self.assertIsNone(db.get(AppInstallation, installation_id).push_token_hash)
        db.close()

    def test_07_revoke_wins_against_stale_registration(self):
        user_id, installation_id = self._identity()
        owner = self.Session()
        user = owner.get(User, user_id)
        lock_push_user(owner, user_id)
        attempted = Event()
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(
                self._registration_thread, user_id, installation_id, attempted
            )
            self.assertTrue(attempted.wait(5))
            product_services.revoke_installation(str(installation_id), owner, user)
            with self.assertRaises(HTTPException):
                future.result(timeout=5)
        owner.close()
        db = self.Session()
        installation = db.get(AppInstallation, installation_id)
        self.assertIsNotNone(installation.revoked_at)
        self.assertIsNone(installation.push_token_hash)
        db.close()

    def test_08_logout_fences_worker_before_provider_send(self):
        user_id, _, delivery_id = self._delivery()
        claim_db = self.Session()
        self.assertEqual(claim_push_deliveries(claim_db), [delivery_id])
        claim_db.close()
        owner = self.Session()
        user = owner.get(User, user_id)
        lock_push_user(owner, user_id)
        attempted = Event()
        provider = EventProvider()
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(
                self._blocked_worker, delivery_id, provider, attempted
            )
            self.assertTrue(attempted.wait(5))
            auth.logout_all(owner, user)
            self.assertIn(future.result(timeout=5), {"ignored", "cancelled"})
        owner.close()
        self.assertFalse(provider.started.is_set())
        self.assertEqual(provider.messages, [])

    def test_09_rotation_fences_worker_stale_generation(self):
        user_id, installation_id, delivery_id = self._delivery()
        claim_db = self.Session()
        self.assertEqual(claim_push_deliveries(claim_db), [delivery_id])
        claim_db.close()
        owner = self.Session()
        user = owner.get(User, user_id)
        lock_push_user(owner, user_id)
        attempted = Event()
        provider = EventProvider()
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(
                self._blocked_worker, delivery_id, provider, attempted
            )
            self.assertTrue(attempted.wait(5))
            product_services.register_push_token(
                str(installation_id), PushTokenUpdate(token="new-token"), owner, user
            )
            self.assertIn(future.result(timeout=5), {"ignored", "cancelled"})
        owner.close()
        self.assertFalse(provider.started.is_set())
        self.assertEqual(provider.messages, [])

    def test_10_logout_fences_concurrent_new_installation(self):
        user_id, _ = self._identity()
        access_token = self._auth_token(user_id)
        installation_key = uuid.uuid4()
        owner = self.Session()
        user = owner.get(User, user_id)
        lock_push_user(owner, user_id)
        attempted = Event()
        with ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(
                self._installation_thread,
                user_id,
                installation_key,
                access_token,
                attempted,
            )
            self.assertTrue(attempted.wait(5))
            auth.logout_all(owner, user)
            with self.assertRaises(HTTPException) as raised:
                future.result(timeout=5)
        owner.close()
        self.assertEqual(raised.exception.status_code, 401)
        db = self.Session()
        self.assertIsNone(
            db.query(AppInstallation).filter(
                AppInstallation.installation_key == installation_key
            ).first()
        )
        db.close()


if __name__ == "__main__":
    unittest.main()
