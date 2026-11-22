"""Shortlist remains ranked, confidential and independent of interview outcomes."""
import unittest
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4

from fastapi import HTTPException

from app.services import recruitment_selection as selection


def candidate(name, decision, status="under_review", department="GE"):
    return SimpleNamespace(
        id=uuid4(), first_name=name, last_name="Test",
        screening_decision=decision, status=status,
        department=department, study_level="DIC2",
    )


def review(app, score, stage="screening"):
    return SimpleNamespace(
        id=uuid4(), application_id=app.id, score=score, stage=stage,
    )


class RecruitmentShortlistTests(unittest.TestCase):
    def setUp(self):
        self.campaign = SimpleNamespace(
            screening_published_at=None, identities_revealed_at=None,
            screening_rubric_version=None,
        )

    def test_order_is_real_screening_average_and_only_shortlisted(self):
        a = candidate("Awa", "shortlisted")
        b = candidate("Binta", "shortlisted", status="interview_scheduled")
        excluded = candidate("Cheikh", "not_shortlisted")
        reviews = [review(a, 12), review(a, 14), review(a, 16),
                   review(b, 18), review(b, 17), review(b, 19),
                   review(excluded, 20), review(a, 20, stage="interview")]
        def summary(assessments, campaign, stage):
            self.assertEqual(stage, "screening")
            return {"screening_score": None, "screening_review_count": len(
                [r for r in assessments if r.stage == "screening"]
            )}
        with patch.object(selection, "reviewed_summary", side_effect=summary):
            rows = selection.screening_shortlist_rows([a, b, excluded], reviews, self.campaign)
        self.assertEqual(len(rows), 2)
        self.assertEqual([r["application_id"] for r in rows], [str(b.id), str(a.id)])
        self.assertEqual([r["rank"] for r in rows], [1, 2])
        self.assertEqual([r["jury_average_20"] for r in rows], [18, 14])
        self.assertTrue(rows[0]["interview_scheduled"])
        self.assertIsNone(rows[0]["candidate_name"])
        self.assertNotIn("email", rows[0])

    def test_names_require_both_publication_and_identity_reveal(self):
        a = candidate("Awa", "shortlisted")
        reviews = [review(a, 15)]
        with patch.object(selection, "reviewed_summary", return_value={
            "screening_score": 75, "screening_review_count": 1
        }):
            self.campaign.identities_revealed_at = "date"
            self.assertIsNone(selection.screening_shortlist_rows(
                [a], reviews, self.campaign)[0]["candidate_name"])
            self.campaign.identities_revealed_at = None
            self.campaign.screening_published_at = "date"
            self.assertIsNone(selection.screening_shortlist_rows(
                [a], reviews, self.campaign)[0]["candidate_name"])
            self.campaign.identities_revealed_at = "date"
            self.assertEqual(selection.screening_shortlist_rows(
                [a], reviews, self.campaign)[0]["candidate_name"], "Awa Test")

    def test_jury_ranking_access_is_scoped_to_active_campaign_jurors(self):
        campaign_id = uuid4()
        user = SimpleNamespace(id=uuid4())
        campaign = SimpleNamespace(selection_policy_version=selection.POLICY_VERSION)
        db = MagicMock()
        db.get.return_value = campaign

        with patch.object(selection, "can_manage_jury", return_value=False), \
             patch.object(selection, "active_jury_member", return_value=True) as member:
            self.assertIs(selection._ranking_reader_campaign(db, user, campaign_id), campaign)
            member.assert_called_once_with(db, user, campaign_id)

        with patch.object(selection, "can_manage_jury", return_value=True), \
             patch.object(selection, "active_jury_member", return_value=False):
            self.assertIs(selection._ranking_reader_campaign(db, user, campaign_id), campaign)

        # Campaign readers and unaffiliated jurors do not receive ranking access.
        with patch.object(selection, "can_manage_jury", return_value=False), \
             patch.object(selection, "active_jury_member", return_value=False):
            with self.assertRaises(HTTPException) as denied:
                selection._ranking_reader_campaign(db, user, campaign_id)
            self.assertEqual(denied.exception.status_code, 403)

        db.get.return_value = None
        with self.assertRaises(HTTPException) as missing:
            selection._ranking_reader_campaign(db, user, campaign_id)
        self.assertEqual(missing.exception.status_code, 404)

    def test_missing_scores_are_last_without_inventing_notes(self):
        a = candidate("Awa", "shortlisted")
        b = candidate("Binta", "shortlisted")
        with patch.object(selection, "reviewed_summary", side_effect=[
            {"screening_score": None, "screening_review_count": 0},
            {"screening_score": 80, "screening_review_count": 1},
        ]):
            rows = selection.screening_shortlist_rows([a, b], [], self.campaign)
        self.assertEqual(rows[0]["application_id"], str(b.id))
        self.assertEqual(rows[0]["jury_average_20"], 16)
        self.assertIsNone(rows[1]["jury_average_20"])


if __name__ == "__main__":
    unittest.main()
