"""Regression tests for the single collective jury score and separate English indicator."""
import unittest
from pydantic import ValidationError
from app.services.recruitment_collective_interview import (
    CollectiveEvaluationSave, collective_score, WEIGHTS, ENGLISH,
)


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

    def test_duplicate_real_jurors_is_invalid(self):
        from uuid import uuid4
        one = uuid4()
        with self.assertRaises(ValidationError):
            CollectiveEvaluationSave.model_validate(
                payload(actual_jury_member_ids=[one, one], exception_reason="Remplacement")
            )


if __name__ == "__main__":
    unittest.main()
