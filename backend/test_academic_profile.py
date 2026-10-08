import unittest

from pydantic import ValidationError

from app.schemas.academic import AcademicProfileConfirm
from app.services.academic_profile import progression_for, validate_academic_path


class AcademicProfileTests(unittest.TestCase):
    def test_progression_and_terminal_level(self):
        self.assertEqual(progression_for("DIC", "DIC2").suggested_next_level, "DIC3")
        self.assertTrue(progression_for("DIC", "DIC3").terminal)

    def test_invalid_department_cursus_and_level(self):
        for values in [("Autre", "DIC", "DIC1"), ("Gestion", "DIC", "DIC1"),
                       ("Génie Électrique", "DIC", "Master1")]:
            with self.subTest(values=values), self.assertRaises(ValueError):
                validate_academic_path(*values)

    def test_required_text_is_cleaned(self):
        payload = AcademicProfileConfirm(department="  GCBA  ", cursus=" DUT ", level=" DUT1 ")
        self.assertEqual((payload.department, payload.cursus, payload.level),
                         ("GCBA", "DUT", "DUT1"))
        with self.assertRaises(ValidationError):
            AcademicProfileConfirm(department=" ", cursus="DUT", level="DUT1")


if __name__ == "__main__":
    unittest.main()
