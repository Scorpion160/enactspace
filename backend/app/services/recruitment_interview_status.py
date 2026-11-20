"""Single source of truth for the operational state of a recruitment interview.

The application selection status is deliberately left untouched.
"""
from datetime import datetime


def operational_status_from_score(
    status: str, *, score: float | None,
    scheduled_at: datetime | None, now: datetime,
) -> str:
    if status == "completed_pending_score":
        return "completed"
    if status in {"postponed", "no_show"}:
        return status
    if score is not None and scheduled_at is not None and scheduled_at <= now:
        return "completed"
    return status
