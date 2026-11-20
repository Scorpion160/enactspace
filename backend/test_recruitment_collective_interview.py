"""Regression tests for the single collective jury score and separate English indicator."""
import unittest
from pydantic import ValidationError
from app.services.recruitment_collective_interview import (
    CollectiveEvaluationSave, collective_score, WEIGHTS, ENGLISH, _current_jury,
)
from types import SimpleNamespace
from unittest.mock import MagicMock
from uuid import uuid4


def payload(**overrides):
    data = {
        "ratings": {key: 3 for key in WEIGHTS},
        "recommendation": "a_discuter",
        "strengths": "Une expérience concrète",
    }
    data.update(overrides)
    return data


class CollectiveJuryEvaluationTests(unittest.TestCase):
    def test_weights_match_excel_and_total_is_one_hundred(self):
        self.assertEqual(list(WEIGHTS.values()), [20, 15, 15, 15, 15, 10, 10])
        self.assertEqual(sum(WEIGHTS.values()), 100)

    def test_all_three_is_sixty_out_of_one_hundred(self):
        validated = CollectiveEvaluationSave.model_validate(payload())
        self.assertEqual(collective_score(validated.ratings), 60)

    def test_all_five_is_hundred(self):
        validated = CollectiveEvaluationSave.model_validate(
            payload(ratings={key: 5 for key in WEIGHTS})
        )
        self.assertEqual(collective_score(validated.ratings), 100)

    def test_mixed_ratings_are_weighted(self):
        grades = dict(zip(WEIGHTS, [5, 4, 3, 2, 1, 4, 5]))
        self.assertEqual(collective_score(grades), 68)

    def test_unassessed_criterion_is_saved_without_fake_score(self):
        partial={key:3 for key in WEIGHTS}
        partial["communication"]=None
        valid=CollectiveEvaluationSave.model_validate(
            payload(ratings=partial,recommendation="reserve")
        )
        self.assertIsNone(collective_score(valid.ratings))
        self.assertIsNone(valid.ratings["communication"])

    def test_partial_english_has_no_fictitious_total(self):
        english={key:3 for key in ENGLISH}
        english["grammaire"]=None
        valid=CollectiveEvaluationSave.model_validate(
            payload(english=english)
        )
        self.assertIsNone(valid.english["grammaire"])
        self.assertNotIn(None, [valid.ratings[key] for key in WEIGHTS])

    def test_english_never_increases_general_score(self):
        english = {key: 5 for key in ENGLISH}
        validated = CollectiveEvaluationSave.model_validate(payload(english=english))
        self.assertEqual(sum(validated.english.values()), 25)
        self.assertEqual(collective_score(validated.ratings), 60)

    def test_no_fake_score_when_criterion_missing(self):
        grades = {key: 3 for key in list(WEIGHTS)[:-1]}
        with self.assertRaises(ValidationError):
            CollectiveEvaluationSave.model_validate(payload(ratings=grades))

    def test_out_of_range_criterion_is_invalid(self):
        for invalid in (0, 6, 2.5, True):
            with self.subTest(invalid=invalid):
                grades = {key: 3 for key in WEIGHTS}
                grades["motivation"] = invalid
                with self.assertRaises(ValidationError):
                    CollectiveEvaluationSave.model_validate(payload(ratings=grades))

    def test_partial_english_is_invalid(self):
        with self.assertRaises(ValidationError):
            CollectiveEvaluationSave.model_validate(
                payload(english={"fluidite": 4})
            )

    def test_unknown_criteria_cannot_change_coefficient(self):
        grades = {key: 3 for key in WEIGHTS}
        grades["unknown"] = 5
        with self.assertRaises(ValidationError):
            CollectiveEvaluationSave.model_validate(payload(ratings=grades))

    def test_completed_jury_uses_actual_replacements(self):
        old, present = uuid4(), uuid4()
        db = MagicMock()
        db.get.return_value = SimpleNamespace(jury_member_ids=[str(old)])
        event = SimpleNamespace(
            action="entretien_reel_confirme_par_organisateur",
            new_value={"status": "completed_pending_score",
                       "actual_jury_member_ids": [str(present)]},
        )
        self.assertEqual(
            _current_jury(db, SimpleNamespace(id=uuid4()), event),
            [present],
        )

    def test_postponed_jury_uses_latest_private_draft(self):
        old, replacement = uuid4(), uuid4()
        db = MagicMock()
        db.get.return_value = SimpleNamespace(
            jury_member_ids=[str(replacement)]
        )
        event = SimpleNamespace(
            action="entretien_report_replanifie_interne",
            new_value={"status": "postponed",
                       "actual_jury_member_ids": [str(old)]},
        )
        self.assertEqual(
            _current_jury(db, SimpleNamespace(id=uuid4()), event),
            [replacement],
        )

    def test_new_uncommunicated_jury_uses_updated_draft(self):
        changed = uuid4()
        db = MagicMock()
        db.get.return_value = SimpleNamespace(
            jury_member_ids=[str(changed)]
        )
        event = SimpleNamespace(
            action="reorganisation_jury_indisponibilite_17nov",
            new_value={"jury_member_ids": [str(changed)]},
        )
        self.assertEqual(
            _current_jury(db, SimpleNamespace(id=uuid4()), event),
            [changed],
        )

    def test_duplicate_real_jurors_is_invalid(self):
        from uuid import uuid4
        one = uuid4()
        with self.assertRaises(ValidationError):
            CollectiveEvaluationSave.model_validate(
                payload(actual_jury_member_ids=[one, one], exception_reason="Remplacement")
            )


if __name__ == "__main__":
    unittest.main()
