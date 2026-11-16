"""Verify candidate-facing modality does not depend on remote jury members."""
import unittest
from app.services.recruitment_interview_drafts import (
    candidate_presence_from_mode,
    remote_link_to_verify,
)


class CandidateAttendanceModeTests(unittest.TestCase):
    def test_presentiel_candidate_stays_onsite(self):
        self.assertEqual(candidate_presence_from_mode("in_person"), "on_site")
        self.assertEqual(candidate_presence_from_mode("hybrid"), "on_site")

    def test_only_explicit_online_exception_is_remote_candidate(self):
        self.assertEqual(candidate_presence_from_mode("online"), "remote_exception")

    def test_video_link_advisory_for_remote_participants(self):
        self.assertFalse(remote_link_to_verify("in_person", "ESP Dakar"))
        self.assertTrue(remote_link_to_verify(
            "hybrid", "ESP Dakar : candidat sur place, jury en ligne ; salle à confirmer"
        ))
        self.assertTrue(remote_link_to_verify(
            "online", "Lien EnactMeet à communiquer"
        ))
        self.assertFalse(remote_link_to_verify(
            "hybrid", "ESP Dakar et réunion https://meet.example.org/jury-16"
        ))
        self.assertFalse(remote_link_to_verify(
            "online", "https://meet.example.org/jury-17"
        ))


if __name__ == "__main__":
    unittest.main()
