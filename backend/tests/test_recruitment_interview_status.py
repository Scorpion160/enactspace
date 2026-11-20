from datetime import datetime, timedelta

from app.services.recruitment_interview_status import operational_status_from_score


def test_scored_past_interview_is_completed():
    now = datetime(2026, 11, 20, 12, 0)
    assert operational_status_from_score(
        "scheduled", score=65.0,
        scheduled_at=now - timedelta(days=1), now=now,
    ) == "completed"


def test_unscored_interview_requires_confirmation():
    now = datetime(2026, 11, 20, 12, 0)
    assert operational_status_from_score(
        "scheduled", score=None,
        scheduled_at=now - timedelta(days=1), now=now,
    ) == "scheduled"
    assert operational_status_from_score(
        "completed_pending_score", score=None,
        scheduled_at=now - timedelta(days=1), now=now,
    ) == "completed"


def test_future_interview_is_not_auto_completed():
    now = datetime(2026, 11, 20, 12, 0)
    assert operational_status_from_score(
        "scheduled", score=80.0,
        scheduled_at=now + timedelta(days=1), now=now,
    ) == "scheduled"


def test_absence_and_postponement_are_not_overwritten_by_a_score():
    now = datetime(2026, 11, 20, 12, 0)
    for state in ("no_show", "postponed"):
        assert operational_status_from_score(
            state, score=70.0,
            scheduled_at=now - timedelta(days=1), now=now,
        ) == state
