"""Campaign-specific interview rules and availability, no notification operations."""
import unittest
from datetime import datetime,timedelta
from uuid import uuid4
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from fastapi import HTTPException
from app.models.recruitment import RecruitmentJuryMember
from app.models.recruitment_interview_drafts import RecruitmentInterviewDraft
from app.models.recruitment_interview_policy import RecruitmentJuryAvailability
from app.models.user import User
from pydantic import ValidationError
from app.services.recruitment_interview_policy import (
    PolicySave, AvailabilitySave, fetch_policy, within_windows, juror_available, register_interview_policy, DEFAULT_WINDOWS,
)

class RecruitmentInterviewPolicyTests(unittest.TestCase):
    def test_campaign_default_in_person_but_editable(self):
        from unittest.mock import MagicMock
        db=MagicMock()
        db.get.return_value=None
        policy=fetch_policy(db,"campaign")
        self.assertEqual(policy["default_mode"],"in_person")
        self.assertFalse(policy["respect_candidate_availability"])
        self.assertEqual(len(policy["daily_windows"]),2)

    def test_distinct_campaign_windows(self):
        policy=PolicySave.model_validate({
            "duration_minutes":30,
            "daily_windows":[{"start":"09:00","end":"12:00"}],
            "default_mode":"online",
        }).model_dump()
        start=datetime(2026,11,20,9,0)
        self.assertTrue(within_windows(policy,start,start+timedelta(minutes=30)))
        self.assertFalse(within_windows(policy,start,start+timedelta(minutes=20)))
        self.assertFalse(within_windows(policy,datetime(2026,11,20,19,0),
                                       datetime(2026,11,20,19,30)))

    def test_overlapping_windows_rejected(self):
        with self.assertRaises(ValidationError):
            PolicySave.model_validate({
                "duration_minutes":20,
                "daily_windows":[{"start":"12:00","end":"14:00"},
                                 {"start":"13:30","end":"15:00"}],
                "default_mode":"in_person",
            })

    def test_availability_on_recurring_weekday(self):
        start=datetime(2026,11,17,19,0)  # Tuesday, Dakar local
        end=start+timedelta(minutes=20)
        windows=[{"weekday":1,"start":"18:00","end":"21:00"}]
        self.assertTrue(juror_available(windows,start,end))
        self.assertFalse(juror_available(windows,start-timedelta(days=1),end-timedelta(days=1)))
        self.assertFalse(juror_available(windows,start+timedelta(hours=2),end+timedelta(hours=2)))
        self.assertFalse(juror_available([],start,end))

    def test_specific_date_replaces_recurring_weekday(self):
        start=datetime(2026,11,17,19,0)
        end=start+timedelta(minutes=20)
        windows=[
            {"weekday":1,"start":"19:00","end":"21:00"},
            {"date":"2026-11-17","start":"12:30","end":"13:30"},
        ]
        self.assertFalse(juror_available(windows,start,end))
        midday=datetime(2026,11,17,12,30)
        self.assertTrue(juror_available(windows,midday,midday+timedelta(minutes=20)))
        next_tuesday=start+timedelta(days=7)
        self.assertTrue(juror_available(windows,next_tuesday,next_tuesday+timedelta(minutes=20)))

    def test_updating_availability_cannot_break_saved_interview_draft(self):
        routes = {}
        class Router:
            def get(self, path):
                return lambda fn: fn
            def put(self, path):
                def decorator(fn):
                    routes[path] = fn
                    return fn
                return decorator
        register_interview_policy(Router())
        cid, uid, mid = uuid4(), uuid4(), uuid4()
        db = MagicMock()
        user = SimpleNamespace(is_active=True, status="active")
        db.get.side_effect = lambda model, key: (
            user if model is User else None
        )
        qmember, qdraft = MagicMock(), MagicMock()
        db.query.side_effect = [qmember, qdraft]
        qmember.filter.return_value.first.return_value = SimpleNamespace(id=mid)
        start = datetime(2026, 11, 17, 19, 0)
        qdraft.filter.return_value.all.return_value = [
            SimpleNamespace(
                jury_member_ids=[str(mid)],
                starts_at=start,
                ends_at=start + timedelta(minutes=20),
            )
        ]
        payload = AvailabilitySave.model_validate({
            "windows": [{"weekday":0, "start":"19:00", "end":"21:00"}]
        })
        with patch("app.services.recruitment_interview_policy.can_manage"), patch(
            "app.services.recruitment_interview_policy.lock_row"
        ):
            with self.assertRaises(HTTPException) as caught:
                routes["/campaigns/{campaign_id}/jury/availability/{user_id}"](
                    cid, uid, payload, db=db, actor=SimpleNamespace(id=uuid4())
                )
        self.assertEqual(caught.exception.status_code, 409)
        db.add.assert_not_called()
        db.commit.assert_not_called()

    def test_weekday_availability_without_campaign_specific_dates(self):
        saved=AvailabilitySave.model_validate({
            "windows":[
                {"weekday":1,"start":"18:00","end":"21:00"},
                {"weekday":2,"start":"18:00","end":"21:00"},
                {"weekday":4,"start":"18:00","end":"21:00"},
            ]
        })
        self.assertEqual([w.weekday for w in saved.windows],[1,2,4])

    def test_availability_requires_day_and_prevents_overlaps(self):
        with self.assertRaises(ValidationError):
            AvailabilitySave.model_validate({"windows":[{"start":"19:00","end":"21:00"}]})
        with self.assertRaises(ValidationError):
            AvailabilitySave.model_validate({"windows":[
                {"weekday":1,"start":"18:00","end":"20:00"},
                {"weekday":1,"start":"19:00","end":"21:00"},
            ]})

if __name__=="__main__":
    unittest.main()
