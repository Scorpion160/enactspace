"""Calendar dates are local dates in Dakar; publication remains a batch action."""
from datetime import date, timedelta

from pydantic import BaseModel, model_validator


class RecruitmentSchedule(BaseModel):
    applications_open: date
    applications_close: date
    screening_start: date
    screening_end: date
    screening_results: date
    interviews_start: date
    interviews_end: date
    final_results: date

    @model_validator(mode="after")
    def chronological_dates(self):
        sequence = (
            self.applications_open, self.applications_close, self.screening_end,
            self.screening_results, self.interviews_start, self.interviews_end, self.final_results,
        )
        if list(sequence) != sorted(sequence) or not self.applications_open <= self.screening_start <= self.screening_end:
            raise ValueError("Les dates doivent suivre l’ordre des dépôts, de l’étude, des résultats du dossier, des entretiens et des résultats finaux.")
        return self


NOVEMBER_2026_SCHEDULE = {
    "applications_open": "2026-11-06", "applications_close": "2026-11-09",
    "screening_start": "2026-11-06", "screening_end": "2026-11-14",
    "screening_results": "2026-11-15",
    "interviews_start": "2026-11-16", "interviews_end": "2026-11-21",
    "final_results": "2026-11-24",
}


def suggested_recruitment_schedule(campaign):
    """Suggest a reusable, editable timeline from this campaign's own dates.

    This is offered only as a form template. It never changes a saved schedule,
    never publishes results, and never sends e-mails.
    """
    opening = campaign.start_date or date.today()
    closing = campaign.end_date or (opening + timedelta(days=3))
    if closing < opening:
        closing = opening
    screening_end = closing + timedelta(days=5)
    results = screening_end + timedelta(days=1)
    interviews_start = results + timedelta(days=1)
    interviews_end = interviews_start + timedelta(days=5)
    final_results = interviews_end + timedelta(days=3)
    return {
        "applications_open": opening.isoformat(),
        "applications_close": closing.isoformat(),
        "screening_start": opening.isoformat(),
        "screening_end": screening_end.isoformat(),
        "screening_results": results.isoformat(),
        "interviews_start": interviews_start.isoformat(),
        "interviews_end": interviews_end.isoformat(),
        "final_results": final_results.isoformat(),
    }
