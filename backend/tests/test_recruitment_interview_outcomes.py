"""Reusable no-show/withdrawal safeguards: no calendar-based automatic exclusion."""
import unittest
from datetime import datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4

from fastapi import APIRouter
from pydantic import ValidationError
from app.services.recruitment_interview_outcomes import (
    ConfirmOutcome, DEFAULT_ABSENCE_LIMIT, _absence_days_from_events, absence_limit,
    register_interview_outcomes,
)


class InterviewOutcomeTests(unittest.TestCase):
    @staticmethod
    def event(action, day, status="no_show", idx=0):
        return SimpleNamespace(
            id=uuid4(),
            action=action,
            created_at=datetime(2026, 11, 21, 9) + timedelta(seconds=idx),
            new_value={"status": status, "actual_day": day},
        )

    def test_two_repeated_appointments_count_twice_not_four_times(self):
        rows = [
            self.event("coordination_absences_constatees_nov21_2026", "2026-11-18", idx=0),
            self.event("coordination_absences_constatees_nov21_2026", "2026-11-21", idx=1),
            self.event("entretien_presence_enregistree", "2026-11-21", idx=2),
        ]
        self.assertEqual(
            _absence_days_from_events(rows),
            ["2026-11-18", "2026-11-21"],
        )

    def test_corrected_attendance_removes_absence_for_that_date(self):
        rows = [
            self.event("entretien_presence_enregistree", "2026-11-18", idx=0),
            self.event("entretien_presence_enregistree", "2026-11-18",
                       status="completed", idx=1),
        ]
        self.assertEqual(_absence_days_from_events(rows), [])

    def test_future_calendar_date_is_not_evidence_of_no_show(self):
        rows = [self.event("entretien_presence_enregistree", "2099-11-22")]
        self.assertEqual(_absence_days_from_events(rows), [])

    def test_three_distinct_misses_are_required(self):
        rows = [
            self.event("entretien_presence_enregistree", "2026-11-17", idx=0),
            self.event("entretien_presence_enregistree", "2026-11-21", idx=1),
            self.event("entretien_presence_enregistree", "2026-11-20", idx=2),
        ]
        self.assertEqual(len(_absence_days_from_events(rows)), 3)

    def test_default_and_campaign_specific_limit(self):
        self.assertEqual(
            absence_limit(SimpleNamespace(selection_schedule={})),
            DEFAULT_ABSENCE_LIMIT,
        )
        self.assertEqual(
            absence_limit(SimpleNamespace(selection_schedule={"max_no_shows": 4})),
            4,
        )
        self.assertEqual(
            absence_limit(SimpleNamespace(selection_schedule={"max_no_shows": 0})),
            DEFAULT_ABSENCE_LIMIT,
        )
        self.assertEqual(
            absence_limit(SimpleNamespace(selection_schedule={"max_no_shows": True})),
            DEFAULT_ABSENCE_LIMIT,
        )

    def test_explicit_decision_requires_meaningful_reason_and_confirmation(self):
        with self.assertRaises(ValidationError):
            ConfirmOutcome(reason="                ", confirmed=True)
        with self.assertRaises(ValidationError):
            ConfirmOutcome(reason="Le candidat a d?clar? son d?sistement.")
        self.assertFalse(
            ConfirmOutcome(reason="Absence confirm?e par le jury.", confirmed=False).confirmed
        )

    def test_manager_only_outcomes_are_explicit_routes(self):
        router = APIRouter(prefix="/recruitment")
        register_interview_outcomes(router)
        paths = {r.path: r.methods for r in router.routes}
        base = "/recruitment/applications/{application_id}/interview/"
        self.assertIn("GET", paths[base + "absence-summary"])
        self.assertIn("POST", paths[base + "withdraw"])
        self.assertIn("POST", paths[base + "exclude-no-show"])


if __name__ == "__main__":
    unittest.main()
