"""Department representation and non-persisting automatic jury proposals."""
import unittest
from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock
from uuid import uuid4
from fastapi import HTTPException

from app.services.recruitment_interviews import (
    department_key, department_represented, propose_interview_jury, assign_interview,
)


def member(department, email):
    id = uuid4()
    return (
        SimpleNamespace(id=id, user_id=id, is_active=True),
        SimpleNamespace(id=id, department=department, email=email,
                        is_active=True, email_verified=True, status="active"),
    )


class JuryDepartmentTests(unittest.TestCase):
    def setUp(self):
        self.candidate = SimpleNamespace(
            id=uuid4(), campaign_id=uuid4(), department="Génie Civil",
            email="candidate@example.org", status="under_review"
        )
        self.start = datetime(2026, 11, 17, 12)
        self.end = self.start + timedelta(minutes=30)
        self.civil = member("Génie Civil", "civil@example.org")
        self.electrical = member("Génie Électrique", "electrical@example.org")
        self.management = member("Gestion", "management@example.org")

    def test_matching_department_is_required(self):
        self.assertTrue(department_represented(
            self.candidate, [self.civil[1], self.management[1]]))
        self.assertFalse(department_represented(
            self.candidate, [self.electrical[1], self.management[1]]))
        self.assertEqual(department_key("GC"), department_key("Génie civil"))
        self.assertNotEqual(department_key("GCBA"), department_key("Génie civil"))
        self.assertFalse(department_represented(
            SimpleNamespace(department=None), [self.civil[1]]))

    def _fake_db(self, people, busy=()):
        db = MagicMock()
        q1, q2, q3 = MagicMock(), MagicMock(), MagicMock()
        db.query.side_effect = [q1, q2, q3]
        q1.join.return_value.filter.return_value.all.return_value = people
        q2.join.return_value.group_by.return_value.all.return_value = [
            (user.id, 0) for _, user in people
        ]
        q3.join.return_value.join.return_value.filter.return_value.all.return_value = [
            (user.id, self.start, self.end) for _, user in people
            if user.email in busy
        ]
        return db

    def test_random_proposal_always_has_a_department_member(self):
        people = [self.civil, self.electrical, self.management]
        db = self._fake_db(people)
        response = propose_interview_jury(
            db, self.candidate, start=self.start, end=self.end, size=3
        )
        self.assertEqual(response["count"], 3)
        self.assertFalse(response["confirmed"])
        self.assertIn(str(self.civil[0].id), response["member_ids"])
        self.assertEqual(len(set(response["member_ids"])), 3)
        db.add.assert_not_called()
        db.commit.assert_not_called()

    def test_proposal_rejects_missing_coverage(self):
        db = self._fake_db([self.electrical, self.management])
        with self.assertRaises(HTTPException) as err:
            propose_interview_jury(db, self.candidate, start=self.start, end=self.end)
        self.assertEqual(err.exception.status_code, 409)
        db.commit.assert_not_called()

    def test_proposal_rejects_busy_same_department_juror(self):
        db = self._fake_db([self.civil, self.management], busy=("civil@example.org",))
        with self.assertRaises(HTTPException) as err:
            propose_interview_jury(db, self.candidate, start=self.start, end=self.end)
        self.assertEqual(err.exception.status_code, 409)

    def test_manual_scheduling_rejects_jury_without_department(self):
        db = MagicMock()
        result = db.query.return_value.join.return_value.filter.return_value.all
        result.return_value = [self.electrical]
        body = SimpleNamespace(
            jury_team_id=None, jury_member_ids=[self.electrical[0].id],
            interview_at=self.start, interview_end_at=self.end,
        )
        with self.assertRaises(HTTPException) as err:
            assign_interview(db, self.candidate, body)
        self.assertEqual(err.exception.status_code, 409)
        db.add.assert_not_called()


if __name__ == "__main__":
    unittest.main()
