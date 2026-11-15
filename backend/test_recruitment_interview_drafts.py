"""No-contact draft planning: authorization and integrity constraints."""
import unittest
from datetime import datetime, timedelta
from types import SimpleNamespace
from uuid import uuid4
from unittest.mock import MagicMock, patch
from fastapi import HTTPException

from app.services.recruitment_interview_drafts import (
    DraftAppointment, _slot_ok, validate_drafts,
    register_interview_drafts,
)


class DraftInterviewTests(unittest.TestCase):
    def setUp(self):
        self.cid = uuid4()
        self.app_id = uuid4()
        self.campaign = SimpleNamespace(id=self.cid)
        self.app = SimpleNamespace(
            id=self.app_id, campaign_id=self.cid, status="under_review",
            screening_decision="shortlisted", department="Gestion",
            email="applicant@esp.sn"
        )
        self.jurors = []
        for dep in ("Gestion", "Génie Électrique", "GCBA"):
            mid, uid = uuid4(), uuid4()
            member = SimpleNamespace(id=mid, user_id=uid, is_active=True)
            user = SimpleNamespace(id=uid, department=dep, email=str(uid)+"@esp.sn",
                                   email_verified=True, is_active=True, status="active")
            self.jurors.append((member,user))
        self.start = datetime(2026,11,17,19,0)
        self.end = self.start + timedelta(minutes=20)
        self.payload = DraftAppointment(
            application_id=self.app_id,
            starts_at=self.start,
            ends_at=self.end,
            jury_member_ids=[m.id for m,u in self.jurors],
        )

    def _db(self):
        db=MagicMock()
        q1,q2,q3=MagicMock(),MagicMock(),MagicMock()
        db.query.side_effect=[q1,q2,q3]
        q1.filter.return_value=[self.app]
        q2.join.return_value.filter.return_value=self.jurors
        q3.join.return_value.join.return_value.filter.return_value.all.return_value=[]
        return db

    def test_windows_are_exactly_twenty_minutes(self):
        self.assertTrue(_slot_ok(self.start,self.end))
        self.assertTrue(_slot_ok(datetime(2026,11,16,12,30),datetime(2026,11,16,12,50)))
        self.assertFalse(_slot_ok(datetime(2026,11,16,13,50),datetime(2026,11,16,14,10)))
        self.assertFalse(_slot_ok(datetime(2026,11,16,18,40),datetime(2026,11,16,19,0)))
        self.assertFalse(_slot_ok(self.start,self.end+timedelta(minutes=5)))

    def test_validated_draft_has_no_outgoing_contact(self):
        db=self._db()
        result=validate_drafts(db,self.campaign,[self.payload])
        self.assertEqual(result,{"valid":True,"count":1,"notifications_to_candidates":0})
        db.add.assert_not_called()
        db.commit.assert_not_called()

    def test_three_distinct_departments_required(self):
        db=self._db()
        self.jurors[2][1].department="Gestion"
        with self.assertRaises(HTTPException) as caught:
            validate_drafts(db,self.campaign,[self.payload])
        self.assertEqual(caught.exception.status_code,409)

    def test_matching_candidate_department_required(self):
        db=self._db()
        self.app.department="Génie Mécanique"
        with self.assertRaises(HTTPException) as caught:
            validate_drafts(db,self.campaign,[self.payload])
        self.assertEqual(caught.exception.status_code,409)

    def test_duplicate_candidate_forbidden(self):
        db=self._db()
        with self.assertRaises(HTTPException) as caught:
            validate_drafts(db,self.campaign,[self.payload,self.payload])
        self.assertEqual(caught.exception.status_code,409)

    def test_unavailable_juror_forbidden(self):
        db=self._db()
        self.jurors[0][1].email_verified=False
        with self.assertRaises(HTTPException) as caught:
            validate_drafts(db,self.campaign,[self.payload])
        self.assertEqual(caught.exception.status_code,409)


if __name__ == "__main__":
    unittest.main()
