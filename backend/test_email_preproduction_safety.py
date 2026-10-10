"""Preproduction email recipient containment regressions."""

import os
import unittest

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "email-preproduction-test-secret")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.core.config import settings
from app.db.database import Base
from app.models.email_delivery import EmailDelivery
from app.services.email_delivery_service import enqueue_email_delivery


class EmailPreproductionSafetyTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.db = self.Session()
        self.previous = (
            settings.EMAIL_ENABLED,
            settings.SMTP_HOST,
            settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT,
            settings.EMAIL_TEST_RECIPIENT,
        )
        settings.EMAIL_ENABLED = True
        settings.SMTP_HOST = "smtp.example.test"
        settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT = True
        settings.EMAIL_TEST_RECIPIENT = "dioppylsci@gmail.com"

    def tearDown(self):
        (
            settings.EMAIL_ENABLED,
            settings.SMTP_HOST,
            settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT,
            settings.EMAIL_TEST_RECIPIENT,
        ) = self.previous
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def test_every_recipient_is_redirected_to_the_test_mailbox(self):
        original_recipients = (
            "member-one@example.test",
            "member-two@example.test",
            "member-three@example.test",
        )
        for index, recipient in enumerate(original_recipients):
            enqueue_email_delivery(
                self.db,
                recipient_email=recipient,
                subject="Invitation EnactMeet",
                text_body="Une réunion est disponible.",
                dedupe_key=f"preproduction:{index}",
            )
        self.db.commit()
        deliveries = self.db.query(EmailDelivery).all()
        self.assertEqual(len(deliveries), 3)
        self.assertEqual(
            {delivery.recipient_email for delivery in deliveries},
            {"dioppylsci@gmail.com"},
        )
        self.assertTrue(all(row.subject.startswith("[TEST]") for row in deliveries))
        for recipient in original_recipients:
            self.assertTrue(any(recipient in row.text_body for row in deliveries))


if __name__ == "__main__":
    unittest.main()