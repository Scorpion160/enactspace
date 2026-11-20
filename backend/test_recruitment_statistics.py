"""Unit and boundary checks for reusable recruitment statistics."""
import unittest
from datetime import datetime, timezone
from types import SimpleNamespace as NS

from app.services.recruitment_statistics import internal_campaign_statistics

NOW = datetime(2026, 11, 12, 12, 0, 0)


def application(identifier, department="GC", status="under_review", **fields):
    data = dict(
        id=identifier, department=department, study_level="DIC1",
        class_name="2026-2027", known_enactus_from="Réseaux sociaux",
        gender="femme", status=status, phone="77", motivation="test",
        availability="semaine", questionnaire_answers={"a": "b"},
        interview_at=None, converted_user_id=None, created_at=NOW,
    )
    data.update(fields)
    return NS(**data)


def review(application_id, reviewer, score, recommendation="reserve"):
    return NS(
        application_id=application_id, reviewer_id=reviewer, score=score,
        recommendation=recommendation, created_at=NOW, updated_at=NOW,
    )


class RecruitmentStatisticsTests(unittest.TestCase):
    def test_empty_campaign_is_safe_and_has_no_fabricated_average(self):
        info = internal_campaign_statistics([], [])
        self.assertEqual(info["overview"]["completed"], 0)
        self.assertEqual(info["overview"]["missing_reviews"], 0)
        self.assertIsNone(info["scoring"]["candidate_average"])
        self.assertIsNone(info["scoring"]["median"])
        self.assertIsNone(info["disagreements"]["max_spread"])
        self.assertEqual(info["recommendations"]["votes"]["favorable"], 0)
        self.assertEqual(info["groups"]["department"], [])

    def test_completion_scoring_majorities_and_disagreement_union(self):
        candidates = [
            application("a", department="GE"),
            application("b", department="GE", known_enactus_from=""),
            application("c", department="GI"),
            application("d", department="GI"),
        ]
        reviews = [
            review("a", "u1", 10, "favorable"),
            review("a", "u2", 15, "defavorable"),
            review("a", "u3", 20, "reserve"),
            review("b", "u1", 16, "favorable"),
            review("b", "u2", 16, "favorable"),
            review("b", "u3", 16, "favorable"),
            review("c", "u1", 0, "defavorable"),
            review("c", "u2", 10, "reserve"),
        ]
        info = internal_campaign_statistics(candidates, reviews)
        overview = info["overview"]
        self.assertEqual(overview["reviews"], 8)
        self.assertEqual(overview["scored_reviews"], 8)
        self.assertEqual(overview["completed"], 2)
        self.assertEqual(overview["missing_reviews"], 4)
        self.assertEqual(overview["distribution"][0]["count"], 1)
        self.assertEqual(overview["distribution"][2]["count"], 1)
        self.assertEqual(overview["distribution"][3]["count"], 2)
        self.assertEqual(info["scoring"]["candidate_average"], 12)
        self.assertEqual(info["scoring"]["median"], 15)
        self.assertEqual(info["scoring"]["at_least_14"], 2)
        self.assertEqual(info["disagreements"]["spread_ge_5"], 2)
        self.assertEqual(info["disagreements"]["opposite_opinions"], 1)
        self.assertEqual(info["disagreements"]["sensitive_total"], 2)
        self.assertEqual(info["recommendations"]["majority"]["favorable"], 1)
        self.assertEqual(info["recommendations"]["majority"]["egalite"], 2)
        self.assertEqual(info["missing_fields"]["known_enactus_from"], 1)
        self.assertEqual(
            next(row for row in info["groups"]["department"] if row["label"] == "Génie électrique")["missing_reviews"],
            0,
        )

    def test_missing_scores_do_not_count_as_zero_or_as_completion(self):
        candidates = [application("a")]
        reviews = [
            review("a", "u1", 0),
            review("a", "u2", None),
            review("a", "u3", 10),
        ]
        info = internal_campaign_statistics(candidates, reviews)
        self.assertEqual(info["overview"]["scored_reviews"], 2)
        self.assertEqual(info["overview"]["completed"], 0)
        self.assertEqual(info["overview"]["missing_reviews"], 1)
        self.assertEqual(info["scoring"]["candidate_average"], 5)
        self.assertEqual(info["scoring"]["at_least_14"], 0)

    def test_future_campaign_uses_new_applications_only(self):
        first = internal_campaign_statistics(
            [application("a")],
            [review("a", f"u{i}", 18) for i in range(3)],
        )
        next_campaign = internal_campaign_statistics(
            [application("b", status="submitted")], []
        )
        self.assertEqual(first["overview"]["completed"], 1)
        self.assertEqual(next_campaign["overview"]["completed"], 0)
        self.assertEqual(next_campaign["statuses"], {"submitted": 1})
        self.assertEqual(next_campaign["overview"]["missing_reviews"], 3)
        self.assertIsNone(next_campaign["scoring"]["candidate_average"])
        self.assertEqual(next_campaign["overview"]["reviews"], 0)


if __name__ == "__main__":
    unittest.main()
