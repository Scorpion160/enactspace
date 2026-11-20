"""Chat notifications never trigger email, including previously queued mail."""
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from app.models.email_delivery import EmailDelivery
from app.models.notification import Notification
from app.services import email_delivery_service, notification_channels
from app.services.email_templates import app_link


CHAT_TYPES = (
    "chat_message",
    "chat_poll",
    "chat_reaction",
    "chat_thread_created",
    "chat_participant_added",
)


class ChatEmailPrivacyTests(unittest.TestCase):
    def setUp(self):
        self.captured = {}

        def enqueue(db, **kwargs):
            self.captured.update(kwargs)
            return kwargs

        self.enterContext(
            patch.object(email_delivery_service, "enqueue_email_delivery", enqueue)
        )
        self.enqueue = email_delivery_service.enqueue_notification_email
        self.db = SimpleNamespace(flush=lambda: None)

    def test_chat_notifications_never_enter_email_outbox(self):
        for kind in CHAT_TYPES:
            with self.subTest(kind=kind):
                self.captured.clear()
                notification = SimpleNamespace(
                    type=kind, id="chat-id",
                    title="Titre privé", message="Message privé",
                )
                result = self.enqueue(
                    self.db, notification, "recipient@example.org", user_id="user-id"
                )
                self.assertIsNone(result)
                self.assertEqual(self.captured, {})

    def test_chat_dispatch_retains_push_without_email(self):
        with patch.object(notification_channels, "_dispatch_email") as email:
            with patch.object(
                notification_channels, "enqueue_push_deliveries", return_value=[1]
            ) as push:
                for kind in CHAT_TYPES:
                    with self.subTest(kind=kind):
                        result = notification_channels.dispatch_notification_channels(
                            self.db,
                            SimpleNamespace(type=kind),
                            SimpleNamespace(email="user@example.org"),
                            None,
                        )
                        self.assertEqual(result, {"email": False, "push": True})
                email.assert_not_called()
                self.assertEqual(push.call_count, len(CHAT_TYPES))

    def test_queued_chat_email_is_cancelled_before_smtp(self):
        delivery = SimpleNamespace(
            id="delivery-id", status="processing", notification_id="chat-id",
            processing_started_at="active", updated_at=None,
        )
        notification = SimpleNamespace(id="chat-id", type="chat_message")
        commits = []
        class Query:
            def __init__(self, row):
                self.row = row
            def filter(self, *args):
                return self
            def first(self):
                return self.row

        db = SimpleNamespace(
            query=lambda model: Query(
                delivery if model is EmailDelivery else notification
                if model is Notification else None
            ),
            rollback=lambda: None,
            commit=lambda: commits.append("commit"),
        )
        provider = SimpleNamespace(send=lambda *args: self.fail("SMTP was called"))
        with patch.object(
            email_delivery_service, "settings",
            SimpleNamespace(email_enabled=True),
        ):
            result = email_delivery_service.process_email_delivery(
                db, "delivery-id", provider
            )
        self.assertEqual(result, "cancelled")
        self.assertEqual(delivery.status, "cancelled")
        self.assertIsNone(delivery.processing_started_at)
        self.assertEqual(commits, ["commit"])

    def test_other_notifications_keep_their_copy(self):
        notification = SimpleNamespace(
            type="task_assigned", id="task-id",
            title="Nouvelle tâche", message="Votre tâche est prête.",
        )
        self.enqueue(self.db, notification, "recipient@example.org")
        self.assertEqual(self.captured["subject"], notification.title)
        self.assertEqual(
            self.captured["text_body"],
            f"{notification.message}\n\nConsulter dans EnactSpace : {app_link('notifications')}",
        )
        self.assertEqual(self.captured["notification_id"], notification.id)

    def test_meeting_email_is_not_suppressed(self):
        notification = SimpleNamespace(
            type="meeting_reminder", id="meeting-id",
            title="Rappel de réunion", message="Rendez-vous prévu.",
        )
        self.enqueue(self.db, notification, "recipient@example.org")
        self.assertEqual(self.captured["subject"], notification.title)
        self.assertIn(app_link("meetings"), self.captured["text_body"])


if __name__ == "__main__":
    unittest.main()
