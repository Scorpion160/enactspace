"""Ensure the mail templates used by publication ship with the backend source."""
import unittest
from pathlib import Path
from types import SimpleNamespace

from app.services.recruitment_mail_copy import MAIL_COPY, application_mail, render_mail


class RecruitmentMailCopyBundleTests(unittest.TestCase):
    def test_source_contains_the_publication_templates(self):
        asset = Path(__file__).parent / "app" / "services" / "recruitment_mail_copy.json"
        self.assertTrue(asset.is_file())
        expected = {
            "screening_shortlisted",
            "screening_not_shortlisted",
            "questionnaire",
            "interview_scheduled",
        }
        self.assertTrue(expected.issubset(MAIL_COPY.keys()))

    def test_all_templates_render_without_unresolved_placeholders(self):
        for kind in MAIL_COPY:
            with self.subTest(kind=kind):
                subject, body = render_mail(
                    kind,
                    first_name="Candidat",
                    code="CODE-TEST",
                    username="TEST",
                    details="Essai fictif",
                )
                self.assertTrue(subject.strip())
                self.assertIn("Candidat", body)
                self.assertNotIn("{first_name}", body)
                self.assertNotIn("{details}", body)

    def test_publication_and_questionnaire_use_same_tracking_link(self):
        fake = SimpleNamespace(
            first_name="Candidat",
            tracking_code="CODE-TEST",
            id="00000000-0000-0000-0000-000000000000",
        )
        for kind in ("screening_shortlisted", "screening_not_shortlisted", "questionnaire"):
            with self.subTest(kind=kind):
                _, body = application_mail(kind, fake)
                self.assertIn("CODE-TEST", body)
                self.assertIn("/application-tracking", body)
                self.assertIn("Enactus ESP", body)


if __name__ == "__main__":
    unittest.main()
