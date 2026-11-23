"""No-contact interview rescheduling: integrity and scheduling checks."""
import unittest
from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock
from uuid import uuid4

from fastapi import HTTPException

from app.services.recruitment_interview_proposals import (
    PrivateProposalSave, check_private_proposal,
)


class PrivateProposalTests(unittest.TestCase):
    def setUp(self):
        self.cid = uuid4()
        self.app = SimpleNamespace(id=uuid4(), email="candidate@esp.sn", department="Gestion")
        self.members = []
        for dep in ("Gestion", "Génie Électrique", "GCBA"):
            m = SimpleNamespace(id=uuid4(), user_id=uuid4(), is_active=True)
            u = SimpleNamespace(
                id=m.user_id, first_name=dep, last_name="Test",
                email=str(m.user_id)+"@esp.sn", department=dep,
                status="active", email_verified=True, is_active=True,
            )
            self.members.append((m, u))
        self.campaign = SimpleNamespace(id=self.cid)
        self.start = datetime(2026, 11, 20, 12, 30)
        self.proposal = PrivateProposalSave(
            starts_at=self.start,
            ends_at=self.start + timedelta(minutes=20),
            mode="in_person", location="ESP Dakar",
            jury_member_ids=[m.id for m, _ in self.members],
            reason="Report demandé par le candidat",
        )

    def _db(self, *, conflict=False, remote=False, unavailable=False,
            missing_availability=False, recorded_unavailable=False):
        db = MagicMock()
        db.get.return_value = None
        qs=[MagicMock() for _ in range(6)]
        db.query.side_effect = qs
        qs[0].join.return_value.filter.return_value.all.return_value = self.members
        events = []
        if remote:
            events.append(SimpleNamespace(
                action="restriction_jure_distanciel",
                new_value={"jury_user_id":str(self.members[0][1].id),
                           "allowed_participation":"online_only"},
            ))
        if unavailable:
            events.append(SimpleNamespace(
                action="indisponibilite_jure_exceptionnelle_20261117",
                new_value={"user_id":str(self.members[0][1].id),
                           "date":"2026-11-20", "available":False},
            ))
        qs[1].filter.return_value.order_by.return_value.all.return_value = events
        qs[2].filter.return_value.all.return_value = (
            [] if missing_availability else [
                SimpleNamespace(
                    user_id=u.id,
                    windows=[] if recorded_unavailable and u.id == self.members[0][1].id
                    else [{"weekday":4, "start":"12:00","end":"14:00"}],
                ) for _, u in self.members
            ]
        )
        qs[3].filter.return_value.all.return_value = (
            [SimpleNamespace(
                starts_at=self.start, ends_at=self.start+timedelta(minutes=20),
                jury_member_ids=[str(self.members[0][0].id)],
            )] if conflict else []
        )
        qs[4].filter.return_value.all.return_value = [m for m,_ in self.members]
        qs[5].join.return_value.join.return_value.filter.return_value.all.return_value=[]
        return db

    def test_valid_friday_proposal_is_read_only(self):
        db=self._db()
        start,end,exception=check_private_proposal(db,self.campaign,self.app,self.proposal)
        self.assertEqual(start,self.start)
        self.assertEqual(end,self.start+timedelta(minutes=20))
        self.assertFalse(exception)
        db.commit.assert_not_called()
        db.add.assert_not_called()

    def test_remote_only_must_be_hybrid(self):
        with self.assertRaises(HTTPException):
            check_private_proposal(self._db(remote=True),self.campaign,self.app,self.proposal)
        draft=self.proposal.model_copy(update={"mode":"hybrid"})
        self.assertFalse(check_private_proposal(
            self._db(remote=True),self.campaign,self.app,draft
        )[2])

    def test_blackout_rejects_even_a_date_with_weekly_availability(self):
        with self.assertRaises(HTTPException):
            check_private_proposal(
                self._db(unavailable=True),self.campaign,self.app,self.proposal
            )

    def test_unrecorded_availability_needs_explicit_manager_confirmation(self):
        with self.assertRaises(HTTPException) as blocked:
            check_private_proposal(
                self._db(missing_availability=True),
                self.campaign, self.app, self.proposal,
            )
        self.assertEqual(blocked.exception.status_code, 409)
        confirmed = self.proposal.model_copy(
            update={"confirm_unrecorded_jury_availability": True}
        )
        _, _, exception = check_private_proposal(
            self._db(missing_availability=True),
            self.campaign, self.app, confirmed,
        )
        self.assertFalse(exception)

    def test_recorded_unavailability_never_overridden_by_confirmation(self):
        confirmed = self.proposal.model_copy(
            update={"confirm_unrecorded_jury_availability": True}
        )
        with self.assertRaises(HTTPException) as blocked:
            check_private_proposal(
                self._db(recorded_unavailable=True),
                self.campaign, self.app, confirmed,
            )
        self.assertEqual(blocked.exception.status_code, 409)

    def test_juror_may_not_have_overlapping_private_draft(self):
        with self.assertRaises(HTTPException):
            check_private_proposal(
                self._db(conflict=True),self.campaign,self.app,self.proposal
            )


if __name__=="__main__":
    unittest.main()
