"""Safeguards for a single private interview room open to authorised campaign jurors.

These tests do not connect to Jitsi, mutate production records, or send mail.
"""
from datetime import datetime
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import MagicMock, patch
from uuid import uuid4

from fastapi import HTTPException
from pydantic import ValidationError

from app.api.routes.meetings import (
    _can_access, _can_moderate_open_recruitment,
    _open_recruitment_campaign, _require_regular_meeting,
)
from app.schemas.meeting import MeetingCreate
from app.services.recruitment_meetings import candidate_enactmeet_access_state
from app.services.recruitment_access import open_interview_application_ids


class OpenJuryRoomTests(TestCase):
    def setUp(self):
        self.campaign = SimpleNamespace(id=uuid4())
        self.meeting = SimpleNamespace(scope_type="custom", scope_id=self.campaign.id,
                                       id=uuid4(), status="scheduled")
        self.user = SimpleNamespace(id=uuid4(), is_active=True,
                                    email_verified=True, status="active")
        self.db = MagicMock()
        self.db.get.return_value = self.campaign

    def test_only_explicit_campaign_scoped_custom_room_is_open(self):
        self.assertIs(_open_recruitment_campaign(self.db, self.meeting), self.campaign)
        self.assertIsNone(_open_recruitment_campaign(
            self.db, SimpleNamespace(scope_type="custom", scope_id=None)))
        self.assertIsNone(_open_recruitment_campaign(
            self.db, SimpleNamespace(scope_type="club", scope_id=self.campaign.id)))
        self.assertEqual(self.db.get.call_count, 1)

    def test_active_campaign_juror_may_join_and_moderate(self):
        with patch("app.services.recruitment_access.active_jury_member", return_value=True):
            with patch("app.services.recruitment_access.can_manage_jury", return_value=False):
                self.assertTrue(_can_access(self.db, self.meeting, self.user))
                self.assertTrue(_can_moderate_open_recruitment(self.db, self.meeting, self.user))

    def test_unregistered_or_revoked_juror_cannot_join(self):
        with patch("app.services.recruitment_access.active_jury_member", return_value=False):
            with patch("app.services.recruitment_access.can_manage_jury", return_value=False):
                self.assertFalse(_can_access(self.db, self.meeting, self.user))
                self.assertFalse(_can_moderate_open_recruitment(self.db, self.meeting, self.user))

    def test_non_campaign_room_does_not_gain_open_jury_access(self):
        self.meeting.scope_id = None
        self.assertIsNone(_open_recruitment_campaign(self.db, self.meeting))
        self.assertFalse(_can_moderate_open_recruitment(self.db, self.meeting, self.user))

    def test_open_jury_dossiers_require_active_campaign_membership(self):
        dossier = uuid4()
        rows = [SimpleNamespace(id=dossier)]
        self.db.query.return_value.join.return_value.filter.return_value.all.return_value = rows
        with patch("app.services.recruitment_access.active_jury_member", return_value=True):
            self.assertEqual(
                open_interview_application_ids(self.db, self.user, self.campaign.id),
                {dossier},
            )
        self.db.query.reset_mock()
        with patch("app.services.recruitment_access.active_jury_member", return_value=False):
            self.assertEqual(
                open_interview_application_ids(self.db, self.user, self.campaign.id),
                set(),
            )
        self.db.query.assert_not_called()

    def test_custom_public_create_cannot_claim_campaign_scope(self):
        with self.assertRaises(ValidationError):
            MeetingCreate(title="Untrusted room", scope_type="custom",
                          scope_id=self.campaign.id)

    def test_open_interview_room_cannot_be_edited_as_regular_meeting(self):
        self.db.query.return_value.filter.return_value.limit.return_value.scalar.return_value = None
        with self.assertRaises(HTTPException) as caught:
            _require_regular_meeting(self.db, self.meeting)
        self.assertEqual(caught.exception.status_code, 409)


class CandidateEntryTests(TestCase):
    def state(self, **kwargs):
        params = {
            "status": "interview_scheduled", "mode": "online",
            "released": True, "meeting": SimpleNamespace(status="scheduled"),
            "questionnaire_submitted": True,
        }
        params.update(kwargs)
        return candidate_enactmeet_access_state(**params)

    def test_online_candidate_not_published_yet(self):
        self.assertEqual(self.state(meeting=None), "pending_publication")
        self.assertEqual(self.state(released=False), "pending_publication")

    def test_questionnaire_is_explicit_prerequisite(self):
        self.assertEqual(self.state(questionnaire_submitted=False), "questionnaire_required")

    def test_waits_for_jury_then_can_join(self):
        self.assertEqual(self.state(), "waiting_for_jury")
        self.assertEqual(self.state(meeting=SimpleNamespace(status="live")), "ready")

    def test_rejected_or_in_person_candidate_has_no_online_access(self):
        self.assertIsNone(self.state(status="rejected"))
        self.assertIsNone(self.state(mode="in_person"))
