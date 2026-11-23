"""External EnactMeet guests: meeting scope, short-lived JWTs and revocation."""
import unittest
from datetime import datetime, timedelta
from types import SimpleNamespace
from unittest.mock import MagicMock, patch
from uuid import uuid4

import jwt
from fastapi import HTTPException
from pydantic import ValidationError

from app.api.routes.meetings import router, _make_jitsi_token
from app.services.meeting_guest_invitations import (
    GuestInvitationRequest, _guest_active, _guest_expiration,
    _public_guest_link,
)


def _endpoint(path, method):
    return next(
        route.endpoint for route in router.routes
        if route.path == path and method in route.methods
    )


class ExternalMeetingGuestTests(unittest.TestCase):
    def test_guest_address_validation_and_optional_name(self):
        valid = GuestInvitationRequest(email=" Outside@Example.org ")
        self.assertEqual(valid.email, "outside@example.org")
        self.assertIsNone(valid.display_name)
        for invalid in ("not-an-email", "a@b", "a@b.com,other@b.com", "a@b.com\nBcc: x"):
            with self.subTest(invalid=invalid):
                with self.assertRaises(ValidationError):
                    GuestInvitationRequest(email=invalid)
        with self.assertRaises(ValidationError):
            GuestInvitationRequest(email="a@example.org", display_name="\nadmin")

    def test_invalidated_links_cannot_be_reused(self):
        now = datetime(2026, 11, 23, 13, 0)
        entry = SimpleNamespace(revoked_at=None, expires_at=now + timedelta(days=1))
        self.assertTrue(_guest_active(entry, now))
        entry.revoked_at = now
        self.assertFalse(_guest_active(entry, now))
        entry.revoked_at = None
        entry.expires_at = now
        self.assertFalse(_guest_active(entry, now))

    def test_expiration_tracks_future_meeting_and_has_a_ceiling(self):
        now = datetime(2026, 11, 23, 13, 0)
        with patch("app.services.meeting_guest_invitations.utc_now", return_value=now):
            meeting = SimpleNamespace(scheduled_start=now + timedelta(days=15),
                                      scheduled_end=now + timedelta(days=15, hours=1))
            self.assertGreater(_guest_expiration(meeting), meeting.scheduled_end)
            far_away = SimpleNamespace(
                scheduled_start=now + timedelta(days=120),
                scheduled_end=now + timedelta(days=120, hours=1),
            )
            with self.assertRaises(HTTPException) as denied:
                _guest_expiration(far_away)
            self.assertEqual(denied.exception.status_code, 422)

    def test_link_uses_configured_api_not_request_host(self):
        with patch("app.services.meeting_guest_invitations.settings") as settings:
            settings.PUBLIC_API_BASE_URL = "https://api.example.org"
            settings.APP_ENV = "production"
            link = _public_guest_link(None, "opaque_token")
        self.assertEqual(link, "https://api.example.org/api/meetings/guests/join/opaque_token")

    def test_external_guest_endpoints_exist(self):
        self.assertIsNotNone(_endpoint("/meetings/{meeting_id}/guests", "POST"))
        self.assertIsNotNone(_endpoint("/meetings/{meeting_id}/guests", "GET"))
        self.assertIsNotNone(_endpoint("/meetings/{meeting_id}/guests/{guest_id}", "DELETE"))
        self.assertIsNotNone(_endpoint("/meetings/guests/join/{token}", "GET"))

    def test_invalid_or_revoked_public_link_is_denied(self):
        join = _endpoint("/meetings/guests/join/{token}", "GET")
        db = MagicMock()
        with self.assertRaises(HTTPException) as bad:
            join("short", db=db)
        self.assertEqual(bad.exception.status_code, 404)
        raw = "a" * 48
        db.query.return_value.filter.return_value.first.return_value = None
        with self.assertRaises(HTTPException) as absent:
            join(raw, db=db)
        self.assertEqual(absent.exception.status_code, 404)
        entry = SimpleNamespace(
            revoked_at=datetime(2026, 11, 23), expires_at=datetime(2099, 1, 1)
        )
        db.query.return_value.filter.return_value.first.return_value = entry
        with self.assertRaises(HTTPException) as revoked:
            join(raw, db=db)
        self.assertEqual(revoked.exception.status_code, 404)

    def test_external_jitsi_token_is_room_bound_and_not_moderator(self):
        now = datetime(2026, 11, 23, 13, 0)
        meeting = SimpleNamespace(
            server_url="https://meet.example.org", room_key="one-meeting",
            recording_enabled=False,
        )
        guest = SimpleNamespace(
            id="guest:" + str(uuid4()), first_name="Visiteur",
            last_name="Externe", email="outside@example.org", photo_url=None,
        )
        with patch("app.api.routes.meetings.utc_now", return_value=now), \
             patch("app.api.routes.meetings.settings") as settings:
            settings.MEET_JWT_APP_ID = "enactspace"
            settings.MEET_JWT_SECRET = "a_unique_jitsi_test_secret"
            settings.MEET_REQUIRE_JWT = True
            settings.MEET_JWT_SUBJECT = "meet.example.org"
            settings.MEET_JWT_AUDIENCE = "jitsi"
            settings.MEET_JWT_TTL_MINUTES = 180
            token = _make_jitsi_token(
                meeting, guest, moderator=False,
                expires_at=now + timedelta(minutes=20),
            )
            claims = jwt.decode(
                token, settings.MEET_JWT_SECRET, algorithms=["HS256"],
                audience="jitsi", options={"verify_exp": False, "verify_nbf": False},
            )
        self.assertEqual(claims["room"], "one-meeting")
        self.assertFalse(claims["context"]["user"]["moderator"])
        self.assertEqual(claims["context"]["user"]["email"], guest.email)
        self.assertEqual(claims["exp"], int((now + timedelta(minutes=20)).timestamp()))


if __name__ == "__main__":
    unittest.main()
