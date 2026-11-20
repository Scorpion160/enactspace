"""Regression checks for in-app recruitment interview communications."""
from datetime import date, datetime
from uuid import uuid4

import pytest
from fastapi import APIRouter, HTTPException
from pydantic import ValidationError

from app.services.recruitment_interview_communications import (
    InterviewCommunicationRequest, _email_ok, _validate_mail,
    _when, register_interview_communications,
)


def test_audience_is_explicit_and_has_one_selection_source():
    candidate = uuid4()
    payload = InterviewCommunicationRequest(
        action="reminder", application_ids=[candidate],
        send_candidates=True, send_jurors=False,
    )
    assert payload.application_ids == [candidate]
    assert payload.interview_date is None
    with pytest.raises(ValidationError):
        InterviewCommunicationRequest(action="venue", application_ids=[candidate])
    with pytest.raises(ValidationError):
        InterviewCommunicationRequest(
            action="venue", interview_date=date(2026, 11, 23),
            location="Salle CRENT", send_candidates=False, send_jurors=False,
        )
    with pytest.raises(ValidationError):
        InterviewCommunicationRequest(
            action="reminder", application_ids=[candidate, candidate],
        )
    with pytest.raises(ValidationError):
        InterviewCommunicationRequest(
            action="reminder", interview_date=date(2026, 11, 23),
            location="Une salle ne doit pas être modifiée par un rappel",
        )


def test_preview_supports_future_campaigns_without_fixed_year():
    request = InterviewCommunicationRequest(
        action="publish", interview_date=date(2031, 9, 16),
        from_time="12:00", until_time="14:00",
    )
    assert request.interview_date.year == 2031
    with pytest.raises(ValidationError):
        InterviewCommunicationRequest(
            action="reminder", interview_date=date(2031, 9, 16),
            from_time="20:00", until_time="12:00",
        )


def test_french_accents_survive_real_mime_serialization():
    assert _when(datetime(2026, 11, 21, 12, 30)) == (
        "samedi 21 novembre 2026 à 12 h 30"
    )
    mail = {
        "kind": "candidate", "name": "Aïssatou Diâl",
        "email": "aissatou@example.org",
        "subject": "Enactus ESP — Changement de salle",
        "body": "Bonjour Aïssatou,\n\nÀ côté du Grand Amphi, salle CRENT.\n\nL’équipe de recrutement.",
    }
    _validate_mail(mail)
    assert "html" in mail
    assert "Aïssatou" in mail["html"]
    assert "Grand Amphi" in mail["html"]


def test_bad_mail_is_rejected_and_safe_address_required():
    assert not _email_ok("")
    assert not _email_ok("not-an-email")
    with pytest.raises(HTTPException):
        _validate_mail({
            "kind": "candidate", "name": "Test",
            "email": "test@example.org", "subject": "Annonce",
            "body": "D?partement de G?nie ?lectrique",
        }.copy() | {"body": "Texte \ufffd irrécupérable"})


def test_manager_routes_are_registered_on_campaign():
    router = APIRouter(prefix="/recruitment")
    register_interview_communications(router)
    paths = {route.path: route.methods for route in router.routes}
    base = "/recruitment/campaigns/{campaign_id}/interviews/communications/"
    assert "POST" in paths[base + "preview"]
    assert "POST" in paths[base + "send"]
    assert "GET" in paths[base + "history"]


def test_scheduling_appointment_does_not_silently_send_email():
    """Publication of emails is exclusively controlled by the preview/send flow."""
    import inspect
    from app.api.routes.recruitment import schedule_application_interview

    code = inspect.getsource(schedule_application_interview)
    assert "notify_application_status(" not in code
