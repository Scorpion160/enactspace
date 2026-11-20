"""Suggested calendars are independent of the 2026 recruitment campaign."""
import unittest
from datetime import date
from types import SimpleNamespace

from app.schemas.recruitment_schedule import (
    RecruitmentSchedule,
    suggested_recruitment_schedule,
)


class SuggestedScheduleTests(unittest.TestCase):
    def test_2026_campaign_keeps_familiar_relative_dates(self):
        campaign = SimpleNamespace(
            start_date=date(2026, 11, 6),
            end_date=date(2026, 11, 9),
            selection_schedule=None,
        )
        suggested = suggested_recruitment_schedule(campaign)
        RecruitmentSchedule.model_validate(suggested)
        self.assertEqual(suggested["screening_end"], "2026-11-14")
        self.assertEqual(suggested["screening_results"], "2026-11-15")
        self.assertEqual(suggested["interviews_start"], "2026-11-16")
        self.assertEqual(suggested["final_results"], "2026-11-24")
        self.assertIsNone(campaign.selection_schedule)

    def test_future_campaign_uses_its_own_year_not_2026(self):
        campaign = SimpleNamespace(
            start_date=date(2028, 2, 28),
            end_date=date(2028, 3, 4),
            selection_schedule={"existing": "untouched"},
        )
        template = suggested_recruitment_schedule(campaign)
        result = RecruitmentSchedule.model_validate(template)
        self.assertEqual(result.applications_open, date(2028, 2, 28))
        self.assertEqual(result.applications_close, date(2028, 3, 4))
        self.assertEqual(result.screening_end, date(2028, 3, 9))
        self.assertEqual(result.final_results, date(2028, 3, 19))
        self.assertEqual(campaign.selection_schedule, {"existing": "untouched"})

    def test_a_missing_closure_produces_valid_relative_schedule(self):
        campaign = SimpleNamespace(
            start_date=date(2027, 9, 1),
            end_date=None,
        )
        suggested = suggested_recruitment_schedule(campaign)
        validated = RecruitmentSchedule.model_validate(suggested)
        self.assertEqual(validated.applications_close, date(2027, 9, 4))


if __name__ == "__main__":
    unittest.main()
