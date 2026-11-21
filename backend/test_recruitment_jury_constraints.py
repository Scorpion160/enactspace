import unittest
from datetime import datetime
from types import SimpleNamespace
from uuid import uuid4

from app.services.recruitment_jury_constraints import (
    constraints_from_events, juror_respects_constraints,
)


class JuryOperationalConstraintsTests(unittest.TestCase):
    def test_two_absences_are_interpreted_separately(self):
        cheikh, ramatoulaye = uuid4(), uuid4()
        events = [
            SimpleNamespace(
                action="indisponibilite_jure_exceptionnelle_20261117",
                new_value={"user_id": str(uid), "date": "2026-11-17", "available": False},
            ) for uid in (cheikh, ramatoulaye)
        ]
        dates, remote = constraints_from_events(events)
        self.assertFalse(remote)
        for uid in (cheikh, ramatoulaye):
            self.assertFalse(
                juror_respects_constraints(
                    uid, datetime(2026, 11, 17, 12, 30),
                    "in_person", dates, remote,
                )
            )
            self.assertTrue(
                juror_respects_constraints(
                    uid, datetime(2026, 11, 18, 12, 30),
                    "in_person", dates, remote,
                )
            )

    def test_sady_online_only_is_allowed_in_hybrid_or_online(self):
        uid = uuid4()
        dates, remote = constraints_from_events([
            SimpleNamespace(
                action="restriction_jure_distanciel",
                new_value={
                    "jury_user_id": str(uid),
                    "allowed_participation": "online_only",
                },
            )
        ])
        at = datetime(2026, 11, 18, 19, 0)
        self.assertFalse(juror_respects_constraints(uid, at, "in_person", dates, remote))
        self.assertTrue(juror_respects_constraints(uid, at, "hybrid", dates, remote))
        self.assertTrue(juror_respects_constraints(uid, at, "online", dates, remote))

    def test_a_later_supervisor_decision_can_lift_blackout(self):
        uid = uuid4()
        events = [
            SimpleNamespace(
                action="contrainte_jure_jour_definie",
                new_value={"user_id": str(uid), "date": "2026-11-17", "available": False},
            ),
            SimpleNamespace(
                action="contrainte_jure_jour_definie",
                new_value={"user_id": str(uid), "date": "2026-11-17", "available": True},
            ),
        ]
        dates, remote = constraints_from_events(events)
        self.assertTrue(
            juror_respects_constraints(
                uid, datetime(2026, 11, 17, 19, 0), "in_person", dates, remote
            )
        )

    def test_unknown_events_never_block_other_users(self):
        target, other = uuid4(), uuid4()
        dates, remote = constraints_from_events([
            SimpleNamespace(action="unrelated", new_value={"user_id": str(target)}),
            SimpleNamespace(
                action="indisponibilite_jure_exceptionnelle_20261117",
                new_value={"user_id": str(other), "date": "2026-11-17", "available": False},
            ),
        ])
        self.assertTrue(
            juror_respects_constraints(
                target, datetime(2026, 11, 17, 12, 30), "in_person", dates, remote
            )
        )


if __name__ == "__main__":
    unittest.main()
