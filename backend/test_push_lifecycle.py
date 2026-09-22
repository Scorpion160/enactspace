"""Focused PR-5 encrypted push lifecycle and outbox regressions."""

import os
import unittest
import uuid
from datetime import datetime, timedelta
from unittest.mock import patch

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "pr5-test-auth-secret")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")
os.environ.setdefault(
    "PUSH_TOKEN_ENCRYPTION_KEY",
    "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA=",
)

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.routes import account, auth, product_services
from app.core.config import settings
from app.db.database import Base
from app.main import app
from app.models.account import UserPreference
from app.models.notification import Notification
from app.models.product_services import AppInstallation, PushDelivery
from app.models.user import User
from app.schemas.product_services import PushTokenUpdate
from app.schemas.account import UserPreferenceUpdate
from app.services.account_service import build_user_data_export
from app.services.notification_service import create_notification
from app.services.push_lifecycle import disable_user_push
from app.services.push_provider import (
    FirebaseAdminPushProvider,
    PushFailureKind,
    PushMessage,
    PushProviderError,
)
from app.services.push_tokens import (
    decrypt_push_token,
    encrypt_push_token,
    normalize_push_token,
    push_token_hash,
)
from app.services.push_worker_service import claim_push_deliveries, process_push_delivery


class FakeProvider:
    def __init__(self, failure=None):
        self.failure = failure
        self.messages = []

    def send(self, message):
        self.messages.append(message)
        if self.failure:
            raise self.failure
        return "projects/test/messages/1"


class PushLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.original_encryption_key = settings.PUSH_TOKEN_ENCRYPTION_KEY
        settings.PUSH_TOKEN_ENCRYPTION_KEY = (
            "MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDA="
        )
        self.engine = create_engine(
            "sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.db = self.Session()
        self.user = self._user("member")
        self.other = self._user("other")
        self.preference = UserPreference(
            user_id=self.user.id,
            notification_push_enabled=True,
            notification_in_app_enabled=True,
        )
        self.db.add(self.preference)
        self.installation = AppInstallation(
            user_id=self.user.id,
            installation_key=uuid.uuid4(),
            platform="android",
        )
        self.db.add(self.installation)
        self.db.commit()
        self.original_push = settings.PUSH_ENABLED
        settings.PUSH_ENABLED = True

    def tearDown(self):
        settings.PUSH_ENABLED = self.original_push
        settings.PUSH_TOKEN_ENCRYPTION_KEY = self.original_encryption_key
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def _user(self, label):
        user = User(
            first_name=label,
            last_name="PR5",
            email=f"{label}-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(user)
        self.db.flush()
        return user

    def _register(self, installation=None, token="token-one"):
        target = installation or self.installation
        return product_services.register_push_token(
            str(target.id), PushTokenUpdate(token=token), self.db, self.user
        )

    def _notification(self, *, dedupe=False):
        value = create_notification(
            self.db,
            user_id=self.user.id,
            title="Titre",
            message="Corps",
            type="task",
            related_type="task",
            related_id=uuid.uuid4(),
            dedupe=dedupe,
        )
        self.db.commit()
        return value

    def _claimed(self):
        return claim_push_deliveries(self.db, limit=10)[0]

    def test_01_token_hash_is_deterministic(self):
        self.assertEqual(push_token_hash("abc"), push_token_hash("abc"))

    def test_02_token_normalization_is_explicit(self):
        self.assertEqual(normalize_push_token("  abc  "), "abc")
        self.assertEqual(push_token_hash(" abc "), push_token_hash("abc"))

    def test_03_token_is_encrypted_at_rest(self):
        self._register(token="raw-sensitive-token")
        self.assertNotIn("raw-sensitive-token", self.installation.push_token_ciphertext)

    def test_04_ciphertext_round_trip(self):
        ciphertext = encrypt_push_token("token")
        self.assertEqual(decrypt_push_token(ciphertext), "token")

    def test_05_api_response_never_contains_token_material(self):
        response = self._register()
        self.assertFalse(hasattr(response, "token"))
        self.assertNotIn("hash", response.model_dump())

    def test_06_openapi_response_schema_has_no_secret_fields(self):
        schema = app.openapi()["components"]["schemas"]["PushTokenRead"]
        self.assertTrue({"token", "token_hash", "token_ciphertext"}.isdisjoint(schema["properties"]))

    def test_07_installation_read_has_only_boolean_push_state(self):
        properties = app.openapi()["components"]["schemas"]["InstallationRead"]["properties"]
        self.assertIn("push_registered", properties)
        self.assertNotIn("push_token_hash", properties)

    def test_08_account_export_excludes_token_material(self):
        self._register(token="export-secret-token")
        exported = str(build_user_data_export(self.db, self.user, "test"))
        self.assertNotIn("export-secret-token", exported)
        self.assertNotIn("push_token_ciphertext", exported)

    def test_09_other_user_cannot_register_on_installation(self):
        with self.assertRaises(HTTPException) as raised:
            product_services.register_push_token(
                str(self.installation.id), PushTokenUpdate(token="x"), self.db, self.other
            )
        self.assertEqual(raised.exception.status_code, 404)

    def test_10_revoked_installation_rejects_token(self):
        self.installation.revoked_at = datetime.utcnow()
        self.db.commit()
        with self.assertRaises(HTTPException) as raised:
            self._register()
        self.assertEqual(raised.exception.status_code, 409)

    def test_11_registration_sets_only_fcm_material(self):
        result = self._register()
        self.assertTrue(result.registered)
        self.assertEqual(self.installation.push_provider, "fcm")

    def test_12_rotation_cancels_old_snapshot(self):
        self._register(token="old")
        self._notification()
        old = self.db.query(PushDelivery).one()
        self._register(token="new")
        self.db.refresh(old)
        self.assertEqual(old.status, "cancelled")

    def test_13_duplicate_current_token_is_db_enforced(self):
        self._register(token="duplicate")
        second = AppInstallation(
            user_id=self.user.id, installation_key=uuid.uuid4(), platform="ios",
            push_provider="fcm", push_token_hash=self.installation.push_token_hash,
            push_token_ciphertext=encrypt_push_token("duplicate"),
            push_token_updated_at=datetime.utcnow(),
        )
        self.db.add(second)
        with self.assertRaises(IntegrityError):
            self.db.commit()
        self.db.rollback()

    def test_14_revoke_clears_token_and_cancels(self):
        self._register(); self._notification()
        product_services.revoke_installation(str(self.installation.id), self.db, self.user)
        self.assertIsNone(self.installation.push_token_hash)
        self.assertEqual(self.db.query(PushDelivery).one().status, "cancelled")

    def test_15_reregister_does_not_restore_revoked_token(self):
        self._register(); product_services.revoke_installation(str(self.installation.id), self.db, self.user)
        payload = product_services.InstallationUpsert(
            installation_key=self.installation.installation_key, platform="android"
        )
        product_services.register_installation(payload, self.db, self.user)
        self.assertIsNone(self.installation.push_token_hash)

    def test_16_disabled_preference_creates_no_outbox(self):
        self._register(); self.preference.notification_push_enabled = False
        self._notification()
        self.assertEqual(self.db.query(PushDelivery).count(), 0)

    def test_17_enabled_preference_creates_one_outbox(self):
        self._register(); self._notification()
        self.assertEqual(self.db.query(PushDelivery).count(), 1)

    def test_18_two_installations_create_independent_deliveries(self):
        self._register()
        second = AppInstallation(user_id=self.user.id, installation_key=uuid.uuid4(), platform="ios")
        self.db.add(second); self.db.commit(); self._register(second, "second-token")
        self._notification()
        self.assertEqual(self.db.query(PushDelivery).count(), 2)

    def test_19_in_app_disabled_still_queues_push(self):
        self._register(); self.preference.notification_in_app_enabled = False
        notification = self._notification()
        self.assertTrue(notification.in_app_suppressed)
        self.assertEqual(self.db.query(PushDelivery).count(), 1)

    def test_20_notification_dedupe_does_not_duplicate_delivery(self):
        self._register()
        related = uuid.uuid4()
        for _ in range(2):
            create_notification(self.db, user_id=self.user.id, title="D", message="M", type="task", related_id=related)
        self.db.commit()
        self.assertEqual(self.db.query(Notification).count(), 1)
        self.assertEqual(self.db.query(PushDelivery).count(), 1)

    def test_21_account_disable_clears_tokens_and_pending(self):
        self._register(); self._notification(); disable_user_push(self.db, self.user.id); self.db.commit()
        self.assertIsNone(self.installation.push_token_hash)
        self.assertEqual(self.db.query(PushDelivery).one().status, "cancelled")

    def test_22_logout_all_revoke_semantics_cover_every_installation(self):
        self._register(); disable_user_push(self.db, self.user.id, revoke=True); self.db.commit()
        self.assertIsNotNone(self.installation.revoked_at)
        self.assertIsNone(self.installation.push_token_ciphertext)

    def test_23_fake_provider_success_marks_sent(self):
        self._register(); self._notification(); provider = FakeProvider()
        self.assertEqual(process_push_delivery(self.db, self._claimed(), provider), "sent")
        self.assertEqual(len(provider.messages), 1)

    def test_24_transient_failure_schedules_retry(self):
        self._register(); self._notification()
        provider = FakeProvider(PushProviderError(PushFailureKind.transient, "temporary"))
        self.assertEqual(process_push_delivery(self.db, self._claimed(), provider), "retry")

    def test_25_max_retry_becomes_dead(self):
        self._register(); self._notification(); delivery = self.db.query(PushDelivery).one()
        delivery.attempt_count = 4; self.db.commit()
        provider = FakeProvider(PushProviderError(PushFailureKind.transient, "temporary"))
        self.assertEqual(process_push_delivery(self.db, self._claimed(), provider), "dead")

    def test_26_invalid_token_clears_generation(self):
        self._register(); self._notification()
        provider = FakeProvider(PushProviderError(PushFailureKind.invalid_token, "invalid_registration"))
        self.assertEqual(process_push_delivery(self.db, self._claimed(), provider), "dead")
        self.assertIsNone(self.installation.push_token_hash)

    def test_27_stale_snapshot_is_cancelled_without_send(self):
        self._register(); self._notification(); delivery_id = self._claimed()
        self.installation.push_token_hash = "0" * 64; self.db.commit(); provider = FakeProvider()
        self.assertEqual(process_push_delivery(self.db, delivery_id, provider), "cancelled")
        self.assertEqual(provider.messages, [])

    def test_28_global_disable_cancels_before_send(self):
        self._register(); self._notification(); delivery_id = self._claimed(); settings.PUSH_ENABLED = False
        provider = FakeProvider()
        self.assertEqual(process_push_delivery(self.db, delivery_id, provider), "cancelled")
        self.assertEqual(provider.messages, [])

    def test_29_transaction_rollback_removes_outbox(self):
        self._register(); create_notification(
            self.db, user_id=self.user.id, title="R", message="R", dedupe=False
        ); self.db.rollback()
        self.assertEqual(self.db.query(PushDelivery).count(), 0)

    def test_30_provider_data_is_string_only_and_whitelisted(self):
        self._register(); self._notification(); provider = FakeProvider()
        process_push_delivery(self.db, self._claimed(), provider)
        data = provider.messages[0].data
        self.assertEqual(set(data), {"notification_id", "type", "related_type", "related_id"})
        self.assertTrue(all(isinstance(value, str) for value in data.values()))

    def test_31_preference_route_false_clears_every_token(self):
        self._register(); self._notification()
        account.update_preferences(
            UserPreferenceUpdate(notification_push_enabled=False), self.db, self.user
        )
        self.assertFalse(self.preference.notification_push_enabled)
        self.assertIsNone(self.installation.push_token_hash)
        self.assertEqual(self.db.query(PushDelivery).one().status, "cancelled")

    def test_32_logout_all_route_revokes_installations_and_push(self):
        self._register(token="never-audit-this-token"); self._notification()
        result = auth.logout_all(self.db, self.user)
        self.assertTrue(result["ok"])
        self.assertIsNotNone(self.installation.revoked_at)
        self.assertIsNone(self.installation.push_token_ciphertext)
        self.assertNotIn("never-audit-this-token", str(result))

    def test_33_abandoned_processing_lease_is_reclaimed(self):
        self._register(); self._notification()
        delivery = self.db.query(PushDelivery).one()
        delivery.status = "processing"
        delivery.processing_started_at = datetime.utcnow() - timedelta(minutes=6)
        self.db.commit()
        claimed = claim_push_deliveries(self.db, now=datetime.utcnow())
        self.assertEqual(claimed, [delivery.id])
        self.db.refresh(delivery)
        self.assertGreater(
            delivery.processing_started_at,
            datetime.utcnow() - timedelta(minutes=1),
        )

    def test_34_fresh_processing_lease_is_not_reclaimed(self):
        self._register(); self._notification()
        delivery = self.db.query(PushDelivery).one()
        delivery.status = "processing"
        delivery.processing_started_at = datetime.utcnow()
        self.db.commit()
        self.assertEqual(claim_push_deliveries(self.db), [])

    def test_35_due_pending_and_retry_remain_claimable(self):
        self._register(); first = self._notification()
        second = create_notification(
            self.db,
            user_id=self.user.id,
            title="Retry",
            message="Retry",
            dedupe=False,
        )
        self.db.flush()
        retry = self.db.query(PushDelivery).filter(
            PushDelivery.notification_id == second.id
        ).one()
        retry.status = "retry"
        retry.next_attempt_at = datetime.utcnow() - timedelta(seconds=1)
        self.db.commit()
        claimed = claim_push_deliveries(self.db, limit=10)
        self.assertEqual(set(claimed), {
            self.db.query(PushDelivery).filter(
                PushDelivery.notification_id == first.id
            ).one().id,
            retry.id,
        })

    def test_36_reclaimed_row_is_protected_by_refreshed_lease(self):
        self._register(); self._notification()
        delivery = self.db.query(PushDelivery).one()
        delivery.status = "processing"
        delivery.processing_started_at = datetime.utcnow() - timedelta(minutes=6)
        self.db.commit()
        self.assertEqual(claim_push_deliveries(self.db), [delivery.id])
        self.assertEqual(claim_push_deliveries(self.db), [])

    def test_37_sender_mismatch_is_typed_as_provider_configuration(self):
        class FakeMessaging:
            class UnregisteredError(Exception): pass
            class SenderIdMismatchError(Exception): pass
            class QuotaExceededError(Exception): pass
            class ThirdPartyAuthError(Exception): pass
            class Message:
                def __init__(self, **kwargs): self.kwargs = kwargs
            class Notification:
                def __init__(self, **kwargs): self.kwargs = kwargs
            class AndroidConfig:
                def __init__(self, **kwargs): self.kwargs = kwargs
            class AndroidNotification:
                def __init__(self, **kwargs): self.kwargs = kwargs
            @staticmethod
            def send(*args, **kwargs):
                raise FakeMessaging.SenderIdMismatchError()

        class FakeExceptions:
            class UnavailableError(Exception): pass
            class InternalError(Exception): pass

        provider = FirebaseAdminPushProvider.__new__(FirebaseAdminPushProvider)
        provider._messaging = FakeMessaging
        provider._exceptions = FakeExceptions
        provider._app = object()
        with self.assertRaises(PushProviderError) as raised:
            provider.send(PushMessage(token="token", title="T", body="B", data={}))
        self.assertEqual(raised.exception.kind, PushFailureKind.unavailable)
        self.assertEqual(raised.exception.code, "sender_id_mismatch")

    def test_38_sender_mismatch_retry_preserves_valid_token(self):
        self._register(); self._notification()
        provider = FakeProvider(
            PushProviderError(PushFailureKind.unavailable, "sender_id_mismatch")
        )
        self.assertEqual(process_push_delivery(self.db, self._claimed(), provider), "retry")
        self.db.refresh(self.installation)
        self.assertIsNotNone(self.installation.push_token_hash)


if __name__ == "__main__":
    unittest.main()
