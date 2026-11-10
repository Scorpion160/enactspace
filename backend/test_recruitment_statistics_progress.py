"""Manager-only anonymous progress metrics in the recruitment statistics API."""
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from app.api.routes import recruitment


class RecruitmentStatisticsProgressTests(unittest.TestCase):
    def setUp(self):
        self.db = MagicMock()
        self.user = SimpleNamespace(id="user-1")
        self.campaign = SimpleNamespace(
            id="campaign-1",
            title="Recrutement annuel",
            is_active=True,
            created_at=None,
            selection_policy_version="blind-selection-v1",
            screening_disagreement_threshold=20,
        )
        self.db.query.return_value.order_by.return_value.all.return_value = [
            self.campaign
        ]

    def test_ordinary_member_never_receives_jury_workload_metrics(self):
        with (
            patch.object(recruitment, "can_manage_jury", return_value=False),
            patch.object(recruitment, "can_access_recruitment", return_value=False),
            patch(
                "app.services.recruitment_statistics.campaign_statistics",
                return_value={"total": 3, "breakdowns": {}},
            ),
            patch(
                "app.services.recruitment_selection.selection_overview",
                side_effect=AssertionError("Must not load private progress"),
            ),
        ):
            response = recruitment.recruitment_statistics(
                db=self.db, current_user=self.user
            )
        self.assertIsNone(response["selection_progress"])
        self.assertFalse(response["can_access_applications"])
        self.assertEqual(response["total"], 3)

    def test_manager_receives_counts_without_candidate_identifiers(self):
        overview = {
            "rows": [
                {
                    "application_id": "secret-1", "anonymous_code": "A001",
                    "ready": True, "review_count": 3,
                    "required_reviews": 3, "spread": 5, "decision": None,
                },
                {
                    "application_id": "secret-2", "anonymous_code": "A002",
                    "ready": False, "review_count": 2,
                    "required_reviews": 4, "spread": 35,
                    "decision": "shortlisted",
                },
                {
                    "application_id": "secret-3", "anonymous_code": "A003",
                    "ready": False, "review_count": 0,
                    "required_reviews": 3, "spread": None, "decision": None,
                },
            ],
            "stage": "screening",
            "minimum_reviews": 3,
            "disagreement_threshold": 20,
            "screening_published_at": None,
        }
        with (
            patch.object(recruitment, "can_manage_jury", return_value=True),
            patch.object(recruitment, "can_access_recruitment", return_value=True),
            patch(
                "app.services.recruitment_statistics.campaign_statistics",
                return_value={"total": 3, "breakdowns": {}},
            ),
            patch(
                "app.services.recruitment_selection.selection_overview",
                return_value=overview,
            ),
        ):
            response = recruitment.recruitment_statistics(
                db=self.db, current_user=self.user
            )
        progress = response["selection_progress"]
        self.assertEqual(progress["ready"], 1)
        self.assertEqual(progress["not_ready"], 2)
        self.assertEqual(progress["not_reviewed"], 1)
        self.assertEqual(progress["reviewed_at_least_once"], 2)
        self.assertEqual(progress["reviews_recorded"], 5)
        self.assertEqual(progress["additional_reviews"], 5)
        self.assertEqual(progress["high_disagreement"], 1)
        self.assertEqual(progress["decisions_prepared"], 1)
        self.assertNotIn("rows", progress)
        self.assertNotIn("application_id", str(progress))


if __name__ == "__main__":
    unittest.main()
