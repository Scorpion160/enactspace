import unittest

from app.services.email_templates import render_email_html


class EmailTemplateSafetyTests(unittest.TestCase):
    def test_untrusted_notification_text_is_escaped(self):
        html = render_email_html("<Avis>", "<script>alert(1)</script>\nLigne 2")
        self.assertNotIn("<script>", html)
        self.assertNotIn("<Avis>", html)
        self.assertIn("&lt;script&gt;", html)
        self.assertIn("Ligne 2", html)

    def test_template_is_responsive_and_branded(self):
        html = render_email_html("Invitation · Réunion", "Votre réunion est prête.")
        self.assertIn('name="viewport"', html)
        self.assertIn("EnactSpace", html)
        self.assertIn("Enactus ESP", html)
        self.assertIn("#ffc222", html)
        self.assertIn("#070d0d", html)
        self.assertNotIn("#176b3a", html)
        self.assertIn("Ouvrir EnactSpace", html)
        self.assertNotIn("envoyÃ", html)
        self.assertNotIn("Â·", html)

    def test_otp_is_visually_highlighted_without_changing_it(self):
        html = render_email_html(
            "EnactSpace - Code de réinitialisation",
            "Votre code est 123456. Il expire bientôt.",
        )
        self.assertIn("123456", html)
        self.assertIn("letter-spacing:7px", html)
        self.assertNotIn("Accéder à EnactSpace", html)


if __name__ == "__main__":
    unittest.main()