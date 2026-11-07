"""Exercise the actual email enqueue policy without sending or accessing a DB."""
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from app.services import email_delivery_service
from app.services.email_templates import app_link

class ChatEmailPrivacyTests(unittest.TestCase):
    def setUp(self):
        self.captured = {}

        def enqueue(db, **kwargs):
            self.captured.update(kwargs)
            return kwargs

        self.enterContext(patch.object(email_delivery_service, "enqueue_email_delivery", enqueue))
        self.enqueue = email_delivery_service.enqueue_notification_email
        self.db = SimpleNamespace(flush=lambda: None)

    def test_all_chat_content_stays_out_of_subject_and_body(self):
        for kind in ("chat_message", "chat_poll", "chat_reaction"):
            with self.subTest(kind=kind):
                notification = SimpleNamespace(type=kind, id="notification-id",
                    title="SECRET poll question", message="SECRET private message")
                self.enqueue(self.db, notification, "recipient@example.org", user_id="user-id")
                self.assertNotIn("SECRET", self.captured["subject"])
                self.assertNotIn("SECRET", self.captured["text_body"])
                self.assertIn("/chat", self.captured["text_body"])
                self.assertEqual(self.captured["notification_id"], notification.id)
                self.assertEqual(notification.message, "SECRET private message")

    def test_other_notifications_keep_their_copy(self):
        notification = SimpleNamespace(type="task_assigned", id="other",
                                        title="Nouvelle tâche", message="Votre tâche est prête.")
        self.enqueue(self.db, notification, "recipient@example.org")
        self.assertEqual(self.captured["subject"], notification.title)
        self.assertEqual(
            self.captured["text_body"],
            f"{notification.message}\n\nConsulter dans EnactSpace : {app_link('notifications')}",
        )

if __name__ == "__main__":
    unittest.main()
