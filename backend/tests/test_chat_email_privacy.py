"""Exercise the actual email enqueue policy without sending or accessing a DB."""
import ast
from pathlib import Path
from types import SimpleNamespace
import unittest

class ChatEmailPrivacyTests(unittest.TestCase):
    def setUp(self):
        source = Path(__file__).resolve().parents[1] / "app/services/email_delivery_service.py"
        tree = ast.parse(source.read_text(encoding="utf-8"))
        function = next(n for n in tree.body if isinstance(n, ast.FunctionDef)
                        and n.name == "enqueue_notification_email")
        module = ast.Module(body=[function], type_ignores=[])
        module.body.insert(0, ast.ImportFrom(module="__future__", names=[
            ast.alias(name="annotations")], level=0))
        ast.fix_missing_locations(module)
        self.captured = {}
        def enqueue(db, **kwargs):
            self.captured.update(kwargs)
            return kwargs
        namespace = {"enqueue_email_delivery": enqueue,
                     "APP_URL": "https://enactspace.kerunjombor.net"}
        exec(compile(module, str(source), "exec"), namespace)
        self.enqueue = namespace["enqueue_notification_email"]
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
        self.assertEqual(self.captured["text_body"], notification.message)

if __name__ == "__main__":
    unittest.main()

