"""Focused durable email outbox regressions."""

import os
import unittest
import uuid
from datetime import timedelta

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "email-test-secret")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.core.config import settings
from app.core.time import utc_now
from app.db.database import Base
from app.models.account import UserPreference
from app.models.email_delivery import EmailDelivery
from app.models.user import User
from app.services.email_delivery_service import (
    claim_email_deliveries,
    enqueue_email_delivery,
    process_email_delivery,
)
from app.services.email_provider import EmailFailureKind, EmailProviderError
from app.services.notification_service import create_notification


class FakeProvider:
    def __init__(self, failure=None):
        self.failure = failure
        self.messages = []

    def send(self, message):
        self.messages.append(message)
        if self.failure:
            raise self.failure
        return message.message_id


class EmailDeliveryTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.db = self.Session()
        self.original_email_enabled = settings.EMAIL_ENABLED
        self.original_smtp_host = settings.SMTP_HOST
        settings.EMAIL_ENABLED = True
        settings.SMTP_HOST = "smtp.test"
        self.user = User(
            first_name="Email",
            last_name="Test",
            email=f"email-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(self.user)
        self.db.flush()
        self.preference = UserPreference(
            user_id=self.user.id,
            notification_email_enabled=True,
        )
        self.db.add(self.preference)
        self.db.commit()

    def tearDown(self):
        settings.EMAIL_ENABLED = self.original_email_enabled
        settings.SMTP_HOST = self.original_smtp_host
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def _delivery(self, **kwargs):
        delivery = enqueue_email_delivery(
            self.db,
            recipient_email=self.user.email,
            user_id=self.user.id,
            subject="Sujet",
            text_body="Corps",
            **kwargs,
        )
        self.db.commit()
        return delivery

    def _claim_one(self):
        return claim_email_deliveries(self.db, limit=1)[0]

    def test_01_enqueue_and_dedupe(self):
        first = self._delivery(dedupe_key="same")
        second = enqueue_email_delivery(
            self.db,
            recipient_email=self.user.email,
            subject="Autre",
            text_body="Autre",
            dedupe_key="same",
        )
        self.assertEqual(first.id, second.id)
        self.assertEqual(self.db.query(EmailDelivery).count(), 1)

    def test_02_notification_preference_false_creates_no_email(self):
        self.preference.notification_email_enabled = False
        create_notification(
            self.db,
            user_id=self.user.id,
            title="Titre",
            message="Corps",
            dedupe=False,
        )
        self.db.commit()
        self.assertEqual(self.db.query(EmailDelivery).count(), 0)

    def test_03_notification_preference_true_creates_one_email(self):
        create_notification(
            self.db,
            user_id=self.user.id,
            title="Titre",
            message="Corps",
            dedupe=False,
        )
        self.db.commit()
        self.assertEqual(self.db.query(EmailDelivery).count(), 1)

    def test_04_abandoned_processing_lease_is_reclaimed(self):
        delivery = self._delivery()
        delivery.status = "processing"
        delivery.processing_started_at = utc_now() - timedelta(minutes=6)
        self.db.commit()
        self.assertEqual(claim_email_deliveries(self.db), [delivery.id])

    def test_05_success_marks_sent(self):
        delivery = self._delivery()
        provider = FakeProvider()
        result = process_email_delivery(self.db, self._claim_one(), provider)
        self.assertEqual(result, "sent")
        self.db.refresh(delivery)
        self.assertIsNotNone(delivery.sent_at)
        self.assertEqual(delivery.provider_message_id, provider.messages[0].message_id)

    def test_06_transient_failure_schedules_retry(self):
        delivery = self._delivery()
        provider = FakeProvider(
            EmailProviderError(EmailFailureKind.transient, "temporary")
        )
        result = process_email_delivery(self.db, self._claim_one(), provider)
        self.assertEqual(result, "retry")
        self.db.refresh(delivery)
        self.assertGreater(delivery.next_attempt_at, utc_now())

    def test_07_max_retry_becomes_dead(self):
        delivery = self._delivery()
        delivery.attempt_count = 4
        self.db.commit()
        provider = FakeProvider(
            EmailProviderError(EmailFailureKind.transient, "temporary")
        )
        result = process_email_delivery(self.db, self._claim_one(), provider)
        self.assertEqual(result, "dead")

    def test_08_permanent_failure_becomes_dead(self):
        self._delivery()
        provider = FakeProvider(
            EmailProviderError(EmailFailureKind.permanent, "recipient_rejected")
        )
        self.assertEqual(
            process_email_delivery(self.db, self._claim_one(), provider),
            "dead",
        )

    def test_09_global_disable_cancels_before_send(self):
        self._delivery()
        delivery_id = self._claim_one()
        settings.EMAIL_ENABLED = False
        provider = FakeProvider()
        self.assertEqual(process_email_delivery(self.db, delivery_id, provider), "cancelled")
        self.assertEqual(provider.messages, [])

    def test_10_notification_preference_can_cancel_queued_email(self):
        notification = create_notification(
            self.db,
            user_id=self.user.id,
            title="Titre",
            message="Corps",
            dedupe=False,
        )
        self.db.commit()
        delivery = self.db.query(EmailDelivery).filter(
            EmailDelivery.notification_id == notification.id
        ).one()
        delivery_id = self._claim_one()
        self.preference.notification_email_enabled = False
        self.db.commit()
        provider = FakeProvider()
        self.assertEqual(process_email_delivery(self.db, delivery_id, provider), "cancelled")
        self.assertEqual(provider.messages, [])
        self.db.refresh(delivery)
        self.assertEqual(delivery.status, "cancelled")


if __name__ == "__main__":
    unittest.main()
