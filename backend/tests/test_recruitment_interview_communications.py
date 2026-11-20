"""Regression checks for manager-reviewed recruitment communications."""
import inspect
import unittest
from datetime import date, datetime
from uuid import uuid4

from fastapi import APIRouter, HTTPException
from pydantic import ValidationError

from app.services.recruitment_interview_communications import (
    InterviewCommunicationRequest, _email_ok, _validate_mail,
    _when, _allowed_status, register_interview_communications,
)


class InterviewCommunicationTests(unittest.TestCase):
    def test_selection_requires_explicit_scoping_and_recipients(self):
        candidate = uuid4()
        payload = InterviewCommunicationRequest(
            action="reminder", application_ids=[candidate],
            send_candidates=True, send_jurors=False,
        )
        self.assertEqual(payload.application_ids, [candidate])
        self.assertIsNone(payload.interview_date)
        with self.assertRaises(ValidationError):
            InterviewCommunicationRequest(action="venue", application_ids=[candidate])
        with self.assertRaises(ValidationError):
            InterviewCommunicationRequest(
                action="venue", interview_date=date(2026, 11, 23),
                location="Salle CRENT", send_candidates=False, send_jurors=False,
            )
        with self.assertRaises(ValidationError):
            InterviewCommunicationRequest(
                action="reminder", application_ids=[candidate, candidate],
            )
        with self.assertRaises(ValidationError):
            InterviewCommunicationRequest(
                action="reminder", interview_date=date(2026, 11, 23),
                location="Salle CRENT",
            )
        with self.assertRaises(ValidationError):
            InterviewCommunicationRequest(
                action="venue", application_ids=[candidate],
                location="Salle CRENT", send_candidates=False, send_jurors=True,
            )

    def test_first_publication_allows_shortlisted_unpublished_dossier(self):
        self.assertTrue(_allowed_status("under_review", "publish"))
        self.assertFalse(_allowed_status("under_review", "reminder"))
        self.assertFalse(_allowed_status("under_review", "venue"))
        self.assertFalse(_allowed_status("rejected", "publish"))
        self.assertTrue(_allowed_status("interview_scheduled", "publish"))

    def test_next_campaign_is_dynamic(self):
        request = InterviewCommunicationRequest(
            action="publish", interview_date=date(2031, 9, 16),
            from_time="12:00", until_time="14:00",
        )
        self.assertEqual(request.interview_date.year, 2031)
        with self.assertRaises(ValidationError):
            InterviewCommunicationRequest(
                action="reminder", interview_date=date(2031, 9, 16),
                from_time="20:00", until_time="12:00",
            )

    def test_french_accents_survive_mime_roundtrip(self):
        self.assertEqual(
            _when(datetime(2026, 11, 21, 12, 30)),
            "samedi 21 novembre 2026 \u00e0 12 h 30",
        )
        message = {
            "kind": "candidate", "name": "A\u00efssatou Dial",
            "email": "aissatou@example.org",
            "subject": "Enactus ESP \u2014 Changement de salle",
            "body": ("Bonjour A\u00efssatou,\n\n\u00c0 c\u00f4t\u00e9 du Grand Amphi, "
                     "salle CRENT.\n\nL\u2019\u00e9quipe de recrutement."),
        }
        _validate_mail(message)
        self.assertIn("html", message)
        self.assertIn("Grand Amphi", message["html"])

    def test_replacement_characters_and_invalid_addresses_fail(self):
        self.assertFalse(_email_ok(""))
        self.assertFalse(_email_ok("not-an-email"))
        with self.assertRaises(HTTPException):
            _validate_mail({
                "kind": "candidate", "name": "Test",
                "email": "test@example.org", "subject": "Annonce",
                "body": "Texte \ufffd irrecuperable",
            })
        with self.assertRaises(HTTPException):
            _validate_mail({
                "kind": "candidate", "name": "Test",
                "email": "test@example.org", "subject": "Annonce",
                "body": "D?partement de G?nie ?lectrique",
            })

    def test_routes_registered_on_campaign(self):
        router = APIRouter(prefix="/recruitment")
        register_interview_communications(router)
        paths = {route.path: route.methods for route in router.routes}
        base = "/recruitment/campaigns/{campaign_id}/interviews/communications/"
        self.assertIn("POST", paths[base + "preview"])
        self.assertIn("POST", paths[base + "send"])
        self.assertIn("GET", paths[base + "history"])

    def test_interview_scheduling_never_sends_implicitly(self):
        from app.api.routes.recruitment import schedule_application_interview
        self.assertNotIn(
            "notify_application_status(",
            inspect.getsource(schedule_application_interview),
        )


if __name__ == "__main__":
    unittest.main()
