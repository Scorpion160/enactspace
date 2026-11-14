"""Collective jury decisions resolve disagreements without forging individual ratings."""
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4

from fastapi import APIRouter, HTTPException

from app.services import recruitment_selection as selection


def endpoint():
    router = APIRouter()
    selection.register_recruitment_selection(router)
    return next(
        route.endpoint for route in router.routes
        if route.path.endswith("/selection/collective-deliberation")
    )


class JuryCollectiveDeliberationTests(unittest.TestCase):
    def setUp(self):
        self.campaign = SimpleNamespace(
            id=uuid4(), screening_published_at=None, screening_min_reviews=3,
        )
        self.user = SimpleNamespace(id=uuid4())
        self.db = MagicMock()
        self.rows = [{
            "application_id": str(uuid4()), "review_count": 3,
            "required_reviews": 4, "decision": "shortlisted",
            "ready": False, "review_fingerprint": str(i).zfill(64),
        } for i in range(33)]
        for row in self.rows[20:]:
            row["decision"] = "not_shortlisted"
        self.report = {"revision": "c" * 64, "rows": self.rows}
        self.payload = selection.CollectiveDeliberation(
            revision="c" * 64, confirmation=True, reason="jury_collective",
        )

    def test_33_consensual_decisions_are_recorded_only_in_audit(self):
        with (
            patch.object(selection, "_manager_campaign", return_value=self.campaign),
            patch.object(selection, "review_stage", return_value="screening"),
            patch.object(selection, "selection_overview", return_value=self.report),
            patch.object(selection, "create_audit_log") as audit,
        ):
            response = endpoint()(self.campaign.id, self.payload, self.db, self.user)
        self.assertEqual(response, {"resolved": 33, "published": False, "emails_sent": 0})
        self.assertEqual(audit.call_count, 33)
        self.db.commit.assert_called_once()
        self.assertEqual(audit.call_args_list[0].kwargs["new_value"]["decision"], "shortlisted")
        self.assertEqual(audit.call_args_list[-1].kwargs["new_value"]["decision"], "not_shortlisted")

    def test_missing_personal_review_does_not_get_a_collective_exemption(self):
        self.rows[3]["review_count"] = 2
        with (
            patch.object(selection, "_manager_campaign", return_value=self.campaign),
            patch.object(selection, "review_stage", return_value="screening"),
            patch.object(selection, "selection_overview", return_value=self.report),
            patch.object(selection, "create_audit_log") as audit,
        ):
            with self.assertRaises(HTTPException) as caught:
                endpoint()(self.campaign.id, self.payload, self.db, self.user)
        self.assertEqual(caught.exception.status_code, 409)
        audit.assert_not_called()
        self.db.commit.assert_not_called()

    def test_stale_summary_rejected_before_any_write(self):
        self.payload.revision = "a" * 64
        with (
            patch.object(selection, "_manager_campaign", return_value=self.campaign),
            patch.object(selection, "review_stage", return_value="screening"),
            patch.object(selection, "selection_overview", return_value=self.report),
            patch.object(selection, "create_audit_log") as audit,
        ):
            with self.assertRaises(HTTPException) as caught:
                endpoint()(self.campaign.id, self.payload, self.db, self.user)
        self.assertEqual(caught.exception.status_code, 409)
        audit.assert_not_called()

    def test_review_fingerprint_changes_when_any_jury_note_changes(self):
        row = SimpleNamespace(
            id=uuid4(), updated_at=None, score=12,
            criteria_assessment={"teamwork": 4},
            recommendation="shortlisted", stage="screening",
        )
        first = selection.review_fingerprint([row])
        row.score = 13
        self.assertNotEqual(selection.review_fingerprint([row]), first)

    def test_resolution_survives_only_with_same_decision_and_same_reviews(self):
        opinion = SimpleNamespace(
            id=uuid4(), updated_at=None, score=12,
            criteria_assessment={"teamwork": 4},
            recommendation="shortlisted", stage="screening",
        )
        candidate = SimpleNamespace(screening_decision="shortlisted")
        summary = {"screening_review_count": 3}
        recorded = {
            "decision": "shortlisted",
            "review_fingerprint": selection.review_fingerprint([opinion]),
            "reason": "jury_collective",
        }
        self.assertTrue(selection.is_collectively_resolved(
            self.campaign, candidate, [opinion], summary, 4, recorded
        ))
        candidate.screening_decision = "not_shortlisted"
        self.assertFalse(selection.is_collectively_resolved(
            self.campaign, candidate, [opinion], summary, 4, recorded
        ))
        candidate.screening_decision = "shortlisted"
        opinion.score = 13
        self.assertFalse(selection.is_collectively_resolved(
            self.campaign, candidate, [opinion], summary, 4, recorded
        ))
        opinion.score = 12
        summary["screening_review_count"] = 2
        self.assertFalse(selection.is_collectively_resolved(
            self.campaign, candidate, [opinion], summary, 4, recorded
        ))

    def test_only_authorized_managers_can_use_the_endpoint(self):
        with patch.object(selection, "_manager_campaign",
                          side_effect=HTTPException(403, "Accès refusé")):
            with self.assertRaises(HTTPException) as caught:
                endpoint()(self.campaign.id, self.payload, self.db, self.user)
        self.assertEqual(caught.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
