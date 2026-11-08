"""PR-6.5 operational integrity rules on the portable SQLite test database."""

import asyncio
import unittest
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy import create_engine, event
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.requests import Request
from unittest.mock import patch

import app.models.base  # noqa: F401
from app.api.routes import academic, attendance, events, files, finance, meetings, projects, recruitment, seasons, tasks, users
from app.core.config import settings
from app.core.roles import RECRUITMENT_ACCESS_ROLES
from app.db.database import Base
from app.models.academic import UserAcademicHistory
from app.models.attendance import AttendanceRecord, AttendanceSession
from app.models.audit import AuditLog
from app.models.email_delivery import EmailDelivery
from app.models.event import Event, EventParticipant
from app.models.finance import ClubTransaction, Fee, FinancialAccount, Payment, PaymentAllocation
from app.models.meeting import Meeting, MeetingMember
from app.models.mobile_money import MobileMoneyTransaction
from app.models.notification import Notification
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember
from app.models.recruitment import (
    Application, ApplicationInterviewJuror, ApplicationInterviewTeam, ApplicationPersonality, ApplicationReview, RecruitmentCampaign,
    RecruitmentJuryMember, RecruitmentJuryTeam, RecruitmentViewerAccess,
)
from app.models.role import Role, UserRole
from app.models.season import Season
from app.models.stored_file import StoredFile
from app.models.task import Task
from app.models.user import User
from app.schemas.meeting import MeetingCreate, MeetingInviteRequest, MeetingUpdate
from app.schemas.recruitment import ApplicationInterviewSchedule, ApplicationReviewCreate, ApplicationTrackingRequest, ConvertApplicationToUserRequest
from app.schemas.recruitment_schedule import NOVEMBER_2026_SCHEDULE
from app.schemas.mobile_money import MobileMoneyInitiateRequest
from app.schemas.season import YearActivation
from app.schemas.user import UserAdminUpdate, UserRoleAssign
from app.services.operational_integrity import reconcile_user_lifecycle, to_naive_utc
from app.services.payments import PaymentProviderResult
from app.services import recruitment_meetings, recruitment_selection
from app.services.recruitment_personality import instrument
from app.services.recruitment_rubric import CRITERION_IDS, VERSION
from app.services.recruitment_selection import POLICY_VERSION, SelectionDecision, SelectionPublication, anonymous_code, selection_overview


def _request() -> Request:
    return Request({"type": "http", "client": ("127.0.0.1", 12345), "headers": []})


def _structured_review(application, user, stage, rating=3):
    return ApplicationReview(application_id=application.id, reviewer_id=user.id, stage=stage,
        criteria_assessment={"rubric_version": VERSION, "ratings": [
            {"criterion_id": criterion, "rating": rating, "evidence": "Observation fictive"}
            for criterion in sorted(CRITERION_IDS)
        ]})


class OperationalIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )

        @event.listens_for(self.engine, "connect")
        def _foreign_keys(connection, _record):
            connection.execute("PRAGMA foreign_keys=ON")

        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.db = self.Session()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def _user(
        self,
        *,
        status="active",
        profile_type="enacteur",
        active=True,
        email=None,
        email_verified=True,
    ):
        user = User(
            first_name="PR65",
            last_name="Member",
            email=email or f"{uuid.uuid4()}@example.test",
            password_hash="unused",
            status=status,
            profile_type=profile_type,
            is_active=active,
            email_verified=email_verified,
        )
        self.db.add(user)
        self.db.flush()
        return user

    def _role(self, user, name):
        role = self.db.query(Role).filter(Role.name == name).first()
        if role is None:
            role = Role(name=name)
            self.db.add(role)
            self.db.flush()
        self.db.add(UserRole(user_id=user.id, role_id=role.id))
        self.db.flush()

    def _lifecycle_state(self, user):
        self.db.flush()
        return {
            "status": user.status,
            "profile_type": user.profile_type,
            "is_active": user.is_active,
            "roles": tuple(
                sorted(
                    name
                    for name, in self.db.query(Role.name)
                    .join(UserRole, UserRole.role_id == Role.id)
                    .filter(UserRole.user_id == user.id)
                )
            ),
            "pole_memberships": tuple(
                (str(row.pole_id), row.is_active, row.left_at)
                for row in self.db.query(PoleMember)
                .filter(PoleMember.user_id == user.id)
                .order_by(PoleMember.id)
            ),
            "project_memberships": tuple(
                (str(row.project_id), row.is_active, row.left_at)
                for row in self.db.query(ProjectMember)
                .filter(ProjectMember.user_id == user.id)
                .order_by(ProjectMember.id)
            ),
            "audit_count": self.db.query(AuditLog)
            .filter(AuditLog.entity_type == "user", AuditLog.entity_id == user.id)
            .count(),
            "notification_count": self.db.query(Notification)
            .filter(Notification.user_id == user.id)
            .count(),
        }

    def test_open_year_preserves_existing_work_and_academic_confirmations(self):
        admin = self._user()
        self._role(admin, "administrateur")
        member = self._user()
        previous = Season(
            name="2025–2026", start_date=date(2025, 10, 1),
            end_date=date(2026, 9, 30), is_current=True,
        )
        upcoming = Season(
            name="2026–2027", start_date=date(2026, 10, 1),
            end_date=date(2027, 9, 30),
        )
        self.db.add_all([previous, upcoming])
        self.db.flush()
        member.study_level = "DIC2"
        member.academic_confirmed_season_id = previous.id
        history = UserAcademicHistory(
            user_id=member.id, season_id=previous.id, department="Génie électrique",
            cursus="DIC", study_level="DIC2",
        )
        project = Project(name="Projet en cours", season_id=previous.id)
        campaign = RecruitmentCampaign(
            title="Campagne en cours", season_id=previous.id, is_active=True,
            start_date=date(2026, 11, 6), end_date=date(2026, 11, 9),
        )
        self.db.add_all([history, project, campaign])
        self.db.flush()
        task = Task(title="Tâche en cours", project_id=project.id, status="en_cours")
        self.db.add(task)
        self.db.commit()

        with self.assertRaises(HTTPException) as stale:
            seasons.activate_season(upcoming.id, YearActivation(), self.db, admin)
        self.assertEqual(stale.exception.status_code, 409)
        self.db.rollback()
        self.assertTrue(previous.is_current)
        self.assertFalse(upcoming.is_current)

        activation = YearActivation(expected_current_id=previous.id)
        for _ in range(2):
            opened = seasons.activate_season(upcoming.id, activation, self.db, admin)
            self.assertTrue(opened.is_current)
        self.assertFalse(previous.is_current)
        self.assertTrue(previous.archived)
        self.assertEqual(project.season_id, previous.id)
        self.assertEqual(task.project_id, project.id)
        self.assertEqual(task.status, "en_cours")
        self.assertEqual(campaign.season_id, previous.id)
        self.assertTrue(campaign.is_active)
        self.assertEqual(campaign.end_date, date(2026, 11, 9))
        self.assertEqual(member.study_level, "DIC2")
        self.assertEqual(history.season_id, previous.id)
        profile = academic.read_profile(self.db, member)
        self.assertEqual(profile.current_season_id, upcoming.id)
        self.assertEqual(profile.confirmed_season_id, previous.id)
        self.assertFalse(profile.confirmed_current_season)
        self.assertEqual(self.db.query(AuditLog).filter_by(action="activation_annee").count(), 1)
        self.assertEqual(self.db.query(Notification).filter_by(user_id=member.id).count(), 1)

    def test_blind_recruitment_keeps_answers_and_seals_candidate_documents(self):
        manager = self._user()
        self._role(manager, "administrateur")
        juror = self._user()
        reader = self._user(status="alumni", profile_type="alumni")
        campaign = RecruitmentCampaign(title="Campagne fictive", selection_policy_version=POLICY_VERSION)
        self.db.add(campaign)
        self.db.flush()
        application = Application(
            campaign_id=campaign.id, first_name="Émilie", last_name="Exemple",
            email="emilie@example.com", phone="+221 77 123 45 67",
            department="Génie électrique", study_level="DIC2",
            class_name="2025-2026 (emilie@example.com)",
            questionnaire_answers=[{"id": "motivation", "question": "Pourquoi ?", "answer": "Je suis Emilie et je souhaite agir."}],
        )
        self.db.add_all([
            application,
            RecruitmentJuryMember(campaign_id=campaign.id, user_id=juror.id),
            RecruitmentViewerAccess(campaign_id=campaign.id, user_id=reader.id),
        ])
        self.db.flush()
        cv = StoredFile(
            original_filename="cv-emilie.pdf", stored_filename="fake.pdf",
            storage_path="recruitment/fake.pdf", file_size=5, visibility="private",
            storage_scope="recruitment", entity_type="application", entity_id=application.id,
        )
        self.db.add(cv)
        self.db.flush()
        application.cv_url = f"/api/files/{cv.id}/download"
        self.db.commit()
        reveal = next(
            route.endpoint for route in recruitment.router.routes
            if route.path == "/recruitment/campaigns/{campaign_id}/selection/reveal"
        )

        for user in (manager, juror, reader):
            with self.subTest(user=user.id):
                dossier = recruitment.get_application(str(application.id), False, self.db, user)
                self.assertTrue(dossier["is_anonymized"])
                self.assertEqual(dossier["department"], "Génie électrique")
                self.assertEqual(dossier["study_level"], "DIC2")
                self.assertEqual(dossier["class_name"], "2025-2026 ([identité masquée])")
                self.assertEqual(dossier["questionnaire_answers"][0]["answer"], "Je suis [identité masquée] et je souhaite agir.")
                self.assertEqual(dossier["permissions"]["can_review"], user.id == juror.id)
                self.assertIsNone(dossier["cv_url"])
                for read_file in (files.get_file_metadata, files.preview_file, files.download_file):
                    with self.assertRaises(HTTPException) as hidden:
                        read_file(str(cv.id), self.db, user)
                    self.assertEqual(hidden.exception.status_code, 403)

        with self.assertRaises(HTTPException) as early:
            reveal(campaign.id, self.db, manager)
        self.assertEqual(early.exception.status_code, 409)
        campaign.screening_published_at = datetime(2026, 11, 15)
        self.db.commit()
        with self.assertRaises(HTTPException) as unauthorized:
            reveal(campaign.id, self.db, juror)
        self.assertEqual(unauthorized.exception.status_code, 403)
        self.assertIsNone(recruitment.get_application(str(application.id), False, self.db, juror)["cv_url"])

        reveal(campaign.id, self.db, manager)
        dossier = recruitment.get_application(str(application.id), False, self.db, juror)
        self.assertEqual(dossier["first_name"], "Émilie")
        self.assertEqual(dossier["cv_url"], application.cv_url)
        self.assertEqual(files.get_file_metadata(str(cv.id), self.db, juror)["original_filename"], "cv-emilie.pdf")
        with self.assertRaises(HTTPException) as reader_denied:
            files.get_file_metadata(str(cv.id), self.db, reader)
        self.assertEqual(reader_denied.exception.status_code, 403)

    def test_enactmeet_interview_uses_the_jury_selected_in_the_same_request(self):
        manager = self._user()
        self._role(manager, "administrateur")
        juror = self._user()
        now = datetime.now(timezone.utc)
        campaign = RecruitmentCampaign(
            title="Campagne fictive", selection_policy_version=POLICY_VERSION,
            screening_published_at=to_naive_utc(now), identities_revealed_at=to_naive_utc(now),
        )
        self.db.add(campaign)
        self.db.flush()
        appointment = RecruitmentJuryMember(campaign_id=campaign.id, user_id=juror.id)
        application = Application(
            campaign_id=campaign.id, first_name="Émilie", last_name="Exemple",
            email="emilie@example.com", status="under_review", screening_decision="shortlisted",
        )
        self.db.add_all([appointment, application])
        self.db.commit()

        payload = ApplicationInterviewSchedule(
            interview_at=now + timedelta(hours=1), interview_mode="online",
            use_enactmeet=True, jury_member_ids=[appointment.id],
        )
        with patch.multiple(
            settings, MEET_SERVER_URL="https://meet.example.invalid", MEET_REQUIRE_JWT=True,
            MEET_JWT_APP_ID="enactspace-test", MEET_JWT_SECRET="local-test-secret",
        ):
            result = recruitment.schedule_application_interview(
                str(application.id), payload, _request(), self.db, manager,
            )
        meeting = self.db.get(Meeting, result["interview_meeting_id"])
        self.assertTrue(meeting.lobby_enabled)
        self.assertFalse(meeting.recording_enabled)
        members = self.db.query(MeetingMember).filter_by(meeting_id=meeting.id).all()
        self.assertEqual({member.user_id: member.role for member in members}, {manager.id: "host", juror.id: "cohost"})

        meeting_id = str(meeting.id)
        detail = meetings.get_meeting(meeting_id, self.db, manager)
        self.assertTrue(detail.is_recruitment_interview)
        self.assertTrue(detail.can_manage)
        self.assertFalse(detail.can_delete)
        operations = (
            lambda: meetings.update_meeting(meeting_id, MeetingUpdate(lobby_enabled=False), self.db, juror),
            lambda: meetings.invite_members(meeting_id, MeetingInviteRequest(user_ids=[manager.id]), self.db, juror),
            lambda: meetings.cancel_meeting(meeting_id, self.db, manager),
            lambda: meetings.delete_meeting(meeting_id, self.db, manager),
        )
        for operation in operations:
            with self.assertRaises(HTTPException) as protected:
                operation()
            self.assertEqual(protected.exception.status_code, 409)
        self.assertTrue(meeting.lobby_enabled)
        self.assertEqual(meeting.status, "scheduled")

        code = recruitment.ensure_tracking_code(self.db, application)
        self.db.commit()
        tracking = ApplicationTrackingRequest(application_id=code, email=application.email)
        candidate_join = next(route.endpoint for route in recruitment.router.routes
                              if route.path == "/recruitment/applications/interview/join")
        self.assertFalse(recruitment.track_application(tracking, self.db)["enactmeet_available"])
        with self.assertRaises(HTTPException) as incomplete:
            candidate_join(tracking, self.db)
        self.assertIn("questionnaire obligatoire", incomplete.exception.detail)
        snapshot = instrument()
        attempt = ApplicationPersonality(application_id=application.id, instrument_version=snapshot["version"],
                                         instrument_snapshot=snapshot, invited_by=manager.id)
        self.db.add(attempt)
        self.db.commit()
        self.assertFalse(recruitment.track_application(tracking, self.db)["enactmeet_available"])
        attempt.submitted_at = to_naive_utc(now)
        meeting.status = "live"
        self.db.commit()
        self.assertTrue(recruitment.track_application(tracking, self.db)["enactmeet_available"])
        with patch.multiple(
            settings, MEET_SERVER_URL="https://meet.example.invalid", MEET_REQUIRE_JWT=True,
            MEET_JWT_APP_ID="enactspace-test", MEET_JWT_SECRET="local-test-secret-for-synthetic-rooms",
        ), patch.object(recruitment_meetings, "utc_now", return_value=application.interview_at):
            guest = candidate_join(tracking, self.db)
        self.assertFalse(guest.moderator)
        self.assertEqual(guest.meeting_id, meeting.id)
        meetings.end_meeting(meeting_id, self.db, manager)
        self.assertFalse(recruitment.track_application(tracking, self.db)["enactmeet_available"])

        regular = meetings.create_meeting(MeetingCreate(title="Réunion fictive"), self.db, manager)
        updated = meetings.update_meeting(str(regular.id), MeetingUpdate(lobby_enabled=False), self.db, manager)
        self.assertFalse(updated.lobby_enabled)
        self.assertFalse(updated.is_recruitment_interview)

    def test_interview_lists_keep_the_same_anonymity_as_the_dossier(self):
        manager = self._user()
        self._role(manager, "administrateur")
        juror = self._user()
        reader = self._user(status="alumni", profile_type="alumni")
        now = to_naive_utc(datetime.now(timezone.utc))
        campaign = RecruitmentCampaign(
            title="Campagne fictive", selection_policy_version=POLICY_VERSION,
            screening_published_at=now,
        )
        self.db.add(campaign)
        self.db.flush()
        team = RecruitmentJuryTeam(campaign_id=campaign.id, name="Équipe A", name_key="équipe a")
        application = Application(
            campaign_id=campaign.id, first_name="Émilie", last_name="Exemple",
            email="emilie@example.com", status="interview_scheduled", screening_decision="shortlisted",
            interview_at=now + timedelta(hours=1),
        )
        self.db.add_all([
            team, application, RecruitmentJuryMember(campaign_id=campaign.id, user_id=juror.id),
            RecruitmentViewerAccess(campaign_id=campaign.id, user_id=reader.id),
        ])
        self.db.flush()
        self.db.add(ApplicationInterviewTeam(
            application_id=application.id, team_id=team.id, name=team.name, revision=team.revision,
        ))
        team.revision += 1  # The existing appointment needs reassignment.
        self.db.commit()
        endpoints = {route.path: route.endpoint for route in recruitment.router.routes if "GET" in route.methods}
        teams = endpoints["/recruitment/campaigns/{campaign_id}/jury/teams"]
        jury = endpoints["/recruitment/campaigns/{campaign_id}/jury"]

        for user in (manager, juror, reader):
            self.assertEqual(teams(campaign.id, self.db, user)[0]["interviews"][0]["name"], anonymous_code(application))
        self.assertEqual(jury(campaign.id, self.db, manager)["interviews_needing_reassignment"][0]["name"], anonymous_code(application))

        campaign.identities_revealed_at = now
        self.db.commit()
        for user in (manager, juror):
            self.assertEqual(teams(campaign.id, self.db, user)[0]["interviews"][0]["name"], "Émilie Exemple")
        self.assertEqual(teams(campaign.id, self.db, reader)[0]["interviews"][0]["name"], anonymous_code(application))
        self.assertEqual(jury(campaign.id, self.db, manager)["interviews_needing_reassignment"][0]["name"], "Émilie Exemple")

    def test_interview_juror_cannot_review_their_own_application(self):
        applicant = self._user(email="candidate@example.com")
        other = self._user()
        now = to_naive_utc(datetime.now(timezone.utc))
        campaign = RecruitmentCampaign(
            title="Campagne fictive", selection_policy_version=POLICY_VERSION,
            screening_published_at=now, identities_revealed_at=now,
        )
        self.db.add(campaign)
        self.db.flush()
        application = Application(
            campaign_id=campaign.id, first_name="Émilie", last_name="Exemple",
            email="Candidate@example.com", status="interview_scheduled", screening_decision="shortlisted",
        )
        members = [RecruitmentJuryMember(campaign_id=campaign.id, user_id=user.id) for user in (applicant, other)]
        self.db.add_all([application, *members])
        self.db.flush()
        self.db.add_all(ApplicationInterviewJuror(application_id=application.id, jury_member_id=member.id) for member in members)
        self.db.add_all([
            ApplicationReview(application_id=application.id, reviewer_id=applicant.id, stage="interview", score=20),
            ApplicationReview(application_id=application.id, reviewer_id=other.id, stage="interview", score=12),
        ])
        application.final_score = 16
        self.db.commit()

        own_dossier = recruitment.get_application(str(application.id), False, self.db, applicant)
        self.assertFalse(own_dossier["permissions"]["can_review"])
        self.assertIsNone(own_dossier["my_review"])
        other_dossier = recruitment.get_application(str(application.id), False, self.db, other)
        self.assertTrue(other_dossier["permissions"]["can_review"])
        self.assertEqual(other_dossier["final_score"], 12)
        with self.assertRaises(HTTPException) as forbidden:
            recruitment.create_or_update_review(ApplicationReviewCreate(application_id=application.id), self.db, applicant)
        self.assertEqual(forbidden.exception.status_code, 403)

    def test_interview_end_controls_the_calendar_and_final_publication(self):
        manager = self._user()
        self._role(manager, "administrateur")
        campaign = RecruitmentCampaign(
            title="Campagne fictive", selection_policy_version=POLICY_VERSION,
            selection_schedule=NOVEMBER_2026_SCHEDULE, is_active=False,
            screening_published_at=datetime(2026, 11, 15), identities_revealed_at=datetime(2026, 11, 15),
        )
        self.db.add(campaign)
        self.db.flush()
        application = Application(
            campaign_id=campaign.id, first_name="Émilie", last_name="Exemple",
            email="emilie@example.com", status="under_review", screening_decision="shortlisted",
        )
        self.db.add(application)
        self.db.commit()

        start = datetime(2026, 11, 21, 23, 40)
        end = datetime(2026, 11, 22)
        with self.assertRaises(HTTPException) as too_late:
            recruitment.schedule_application_interview(
                str(application.id), ApplicationInterviewSchedule(interview_at=start + timedelta(minutes=1)),
                _request(), self.db, manager,
            )
        self.assertEqual(too_late.exception.status_code, 422)
        self.db.rollback()
        recruitment.schedule_application_interview(
            str(application.id), ApplicationInterviewSchedule(interview_at=start), _request(), self.db, manager,
        )
        self.assertEqual(application.interview_end_at, end)

        campaign.selection_schedule = None
        application.pending_final_decision = "rejected"  # A decision prepared by an older version.
        self.db.commit()
        endpoints = {route.path: route.endpoint for route in recruitment.router.routes if "POST" in route.methods}
        decide = endpoints["/recruitment/applications/{application_id}/selection-decision"]
        publish = endpoints["/recruitment/campaigns/{campaign_id}/selection/publish"]
        decision = SelectionDecision(stage="interview", decision="rejected")
        publication = SelectionPublication(stage="interview", revision="r" * 64)
        report = {"stage": "interview", "revision": publication.revision, "rows": [
            {"application_id": str(application.id), "ready": True, "decision": "rejected"},
        ]}
        with patch.object(recruitment_selection, "utc_now", return_value=end - timedelta(minutes=1)), \
             patch.object(recruitment_selection, "selection_overview", return_value=report):
            with self.assertRaises(HTTPException) as early_decision:
                decide(application.id, decision, self.db, manager)
            self.assertIn("réalise l’entretien", early_decision.exception.detail)
            with self.assertRaises(HTTPException) as early_publication:
                publish(campaign.id, publication, self.db, manager)
            self.assertIn("entretien doit être réalisé", early_publication.exception.detail)
        self.assertIsNone(campaign.final_published_at)
        self.assertEqual(application.status, "interview_scheduled")

        with patch.object(recruitment_selection, "utc_now", return_value=end):
            decide(application.id, decision, self.db, manager)
        self.assertEqual(application.pending_final_decision, "rejected")

    def test_interview_requires_the_grids_of_the_assigned_panel(self):
        campaign = RecruitmentCampaign(title="Campagne fictive", selection_policy_version=POLICY_VERSION,
                                       screening_min_reviews=5, screening_published_at=datetime(2026, 11, 15))
        self.db.add(campaign)
        self.db.flush()
        first, second, other = [self._user() for _ in range(3)]
        panel = [RecruitmentJuryMember(campaign_id=campaign.id, user_id=user.id) for user in (first, second)]
        application = Application(campaign_id=campaign.id, first_name="Test", last_name="Fictif",
                                  email="candidate@example.test", screening_decision="shortlisted")
        self.db.add_all([application, *panel])
        self.db.flush()
        self.db.add_all([ApplicationInterviewJuror(application_id=application.id, jury_member_id=member.id)
                         for member in panel])
        self.db.add_all([_structured_review(application, first, "interview", 4),
                         _structured_review(application, other, "interview")])
        self.db.commit()
        incomplete = selection_overview(self.db, campaign)["rows"][0]
        self.assertEqual(incomplete["required_reviews"], 2)
        self.assertEqual(incomplete["review_count"], 1)
        self.assertFalse(incomplete["ready"])
        self.db.add(_structured_review(application, second, "interview", 2))
        self.db.commit()
        complete = selection_overview(self.db, campaign)["rows"][0]
        self.assertEqual(complete["required_reviews"], 2)
        self.assertEqual(complete["spread"], 50)
        self.assertTrue(complete["ready"])

    def test_screening_results_are_published_and_queued_together(self):
        manager = self._user()
        self._role(manager, "administrateur")
        now = datetime(2026, 11, 15, 10)
        campaign = RecruitmentCampaign(title="Campagne fictive", selection_policy_version=POLICY_VERSION,
                                       start_date=date(2026, 11, 6), end_date=now.date(), is_active=True)
        self.db.add(campaign)
        self.db.flush()
        applications = [Application(campaign_id=campaign.id, first_name="Test", last_name="Fictif",
                        email=f"{decision}@example.org", screening_decision=decision)
                        for decision in ("shortlisted", "not_shortlisted")]
        self.db.add_all(applications)
        self.db.flush()
        jurors = [self._user() for _ in range(3)]
        for application in applications:
            self.db.add_all([_structured_review(application, user, "screening") for user in jurors])
        self.db.commit()
        report = selection_overview(self.db, campaign)
        publication = SelectionPublication(stage="screening", revision=report["revision"])
        publish = next(route.endpoint for route in recruitment.router.routes
                       if route.path == "/recruitment/campaigns/{campaign_id}/selection/publish")
        tracking = [ApplicationTrackingRequest(application_id=recruitment.ensure_tracking_code(self.db, row),
                                              email=row.email) for row in applications]
        self.db.commit()
        with patch.object(recruitment_selection, "utc_now", return_value=now):
            with self.assertRaises(HTTPException) as open_deposits:
                publish(campaign.id, publication, self.db, manager)
            self.assertIn("Clôture les dépôts", open_deposits.exception.detail)
            self.assertEqual(self.db.query(EmailDelivery).count(), 0)
            self.assertTrue(all(recruitment.track_application(ref, self.db)["screening_result"] is None for ref in tracking))
            campaign.end_date = date(2026, 11, 9)
            self.db.commit()
            with patch.multiple(settings, NOTIFICATION_EMAIL_ENABLED=True, SMTP_HOST="smtp.example.test",
                                EMAIL_RESTRICT_TO_TEST_RECIPIENT=False):
                result = publish(campaign.id, publication, self.db, manager)
                self.assertEqual(result["count"], 2)
                self.assertTrue(publish(campaign.id, publication, self.db, manager)["already_published"])
        deliveries = self.db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like("recruitment-results:%")).all()
        self.assertEqual({row.recipient_email for row in deliveries}, {app.email for app in applications})
        self.assertTrue(all(row.status == "pending" and row.next_attempt_at == now for row in deliveries))
        accepted, rejected = [recruitment.track_application(ref, self.db) for ref in tracking]
        self.assertEqual(accepted["screening_result"], "shortlisted")
        self.assertEqual(accepted["personality_status"], "invited")
        self.assertEqual(rejected["screening_result"], "not_shortlisted")
        self.assertEqual(rejected["status"], "rejected")
        self.assertIsNone(rejected["personality_status"])
        self.assertEqual(accepted["result_published_at"], rejected["result_published_at"])

    def test_member_lifecycle_removes_authority_without_restoring_memberships(self):
        member = self._user()
        for role_name in ("enacteur", "team_leader", "recruiter"):
            self._role(member, role_name)
        pole = Pole(name="Tech", type="support")
        project = Project(name="Integrity")
        self.db.add_all([pole, project])
        self.db.flush()
        pole_link = PoleMember(pole_id=pole.id, user_id=member.id, position="chef_pole")
        project_link = ProjectMember(
            project_id=project.id,
            user_id=member.id,
            position="chef_projet",
        )
        self.db.add_all([pole_link, project_link])
        self.db.flush()

        reconcile_user_lifecycle(self.db, member, "suspended")
        self.db.flush()
        self.assertFalse(member.is_active)
        self.assertFalse(pole_link.is_active)
        self.assertFalse(project_link.is_active)
        role_names = {
            row[0]
            for row in self.db.query(Role.name)
            .join(UserRole, UserRole.role_id == Role.id)
            .filter(UserRole.user_id == member.id)
        }
        self.assertEqual(role_names, {"enacteur"})

        self._role(member, "recruiter")
        reconcile_user_lifecycle(self.db, member, "active")
        self.db.flush()
        role_names = {
            row[0]
            for row in self.db.query(Role.name)
            .join(UserRole, UserRole.role_id == Role.id)
            .filter(UserRole.user_id == member.id)
        }
        self.assertEqual(role_names, {"enacteur"})
        self.assertFalse(pole_link.is_active)
        self.assertFalse(project_link.is_active)

        reconcile_user_lifecycle(self.db, member, "alumni")
        self.db.flush()
        self.assertEqual(member.status, "alumni")
        self.assertTrue(member.is_active)
        role_names = {
            row[0]
            for row in self.db.query(Role.name)
            .join(UserRole, UserRole.role_id == Role.id)
            .filter(UserRole.user_id == member.id)
        }
        self.assertEqual(role_names, {"alumni"})

    def test_reactivation_preserves_operational_profile_identity(self):
        admin = self._user()
        self._role(admin, "administrateur")
        for profile_type in ("enacteur", "enactrice"):
            with self.subTest(profile_type=profile_type):
                member = self._user(profile_type=profile_type)
                self._role(member, "enacteur")
                users.suspend_user(str(member.id), _request(), self.db, admin)
                users.reactivate_user(str(member.id), _request(), self.db, admin)
                self.assertEqual(member.profile_type, profile_type)
                self.assertEqual(member.status, "active")
                self.assertTrue(member.is_active)

    def test_alumni_reactivation_restores_only_alumni_without_memberships(self):
        admin = self._user()
        self._role(admin, "administrateur")
        alumni = self._user(profile_type="alumni", status="alumni")
        self._role(alumni, "alumni")
        self._role(alumni, "recruiter")
        pole = Pole(name="Alumni pole", type="support")
        project = Project(name="Alumni project")
        self.db.add_all([pole, project])
        self.db.flush()
        pole_link = PoleMember(pole_id=pole.id, user_id=alumni.id)
        project_link = ProjectMember(project_id=project.id, user_id=alumni.id)
        self.db.add_all([pole_link, project_link])
        self.db.commit()

        users.suspend_user(str(alumni.id), _request(), self.db, admin)
        users.reactivate_user(str(alumni.id), _request(), self.db, admin)

        self.assertEqual(alumni.status, "alumni")
        self.assertEqual(alumni.profile_type, "alumni")
        self.assertTrue(alumni.is_active)
        self.assertFalse(pole_link.is_active)
        self.assertFalse(project_link.is_active)
        role_names = {
            name for name, in self.db.query(Role.name).join(UserRole).filter(
                UserRole.user_id == alumni.id
            )
        }
        self.assertEqual(role_names, {"alumni"})

    def test_candidate_reactivation_is_rejected_without_authority(self):
        admin = self._user()
        self._role(admin, "administrateur")
        candidate = self._user(
            profile_type="candidate",
            status="inactive",
            active=False,
        )
        self._role(candidate, "candidate")

        with self.assertRaises(HTTPException) as caught:
            users.reactivate_user(str(candidate.id), _request(), self.db, admin)

        self.assertEqual(caught.exception.status_code, 409)
        self.assertEqual(candidate.status, "inactive")
        self.assertFalse(candidate.is_active)
        role_names = {
            name for name, in self.db.query(Role.name).join(UserRole).filter(
                UserRole.user_id == candidate.id
            )
        }
        self.assertEqual(role_names, {"candidate"})

    def test_suspend_source_state_gate_rejects_bypass_states_without_mutation(self):
        admin = self._user()
        self._role(admin, "administrateur")
        pole = Pole(name="Suspend source gate", type="support")
        project = Project(name="Suspend source gate")
        self.db.add_all([pole, project])
        self.db.flush()
        cases = (
            ("pending-enacteur", "pending", "enacteur", False, "enacteur"),
            ("pending-enactrice", "pending", "enactrice", False, "enacteur"),
            ("rejected-enacteur", "rejected", "enacteur", False, "enacteur"),
            ("rejected-enactrice", "rejected", "enactrice", False, "enacteur"),
            ("candidate", "candidate", "candidate", False, "candidate"),
            ("inactive", "inactive", "enacteur", False, "enacteur"),
            ("active-alumni-profile", "active", "alumni", True, "alumni"),
            ("alumni-operational-profile", "alumni", "enacteur", True, "enacteur"),
        )
        for label, source_status, profile_type, active, role_name in cases:
            with self.subTest(case=label):
                target = self._user(
                    status=source_status,
                    profile_type=profile_type,
                    active=active,
                )
                self._role(target, role_name)
                self.db.add_all(
                    [
                        PoleMember(pole_id=pole.id, user_id=target.id),
                        ProjectMember(project_id=project.id, user_id=target.id),
                    ]
                )
                self.db.flush()
                before = self._lifecycle_state(target)

                with self.assertRaises(HTTPException) as caught:
                    users.suspend_user(
                        str(target.id), _request(), self.db, admin
                    )
                self.assertEqual(caught.exception.status_code, 409)
                self.assertEqual(self._lifecycle_state(target), before)

                if source_status in {"pending", "rejected", "candidate"}:
                    with self.assertRaises(HTTPException) as reactivation:
                        users.reactivate_user(
                            str(target.id), _request(), self.db, admin
                        )
                    self.assertEqual(reactivation.exception.status_code, 409)
                    self.assertEqual(self._lifecycle_state(target), before)

    def test_make_alumni_source_gate_and_pending_alumni_approval(self):
        admin = self._user()
        self._role(admin, "administrateur")
        pole = Pole(name="Alumni source gate", type="support")
        project = Project(name="Alumni source gate")
        self.db.add_all([pole, project])
        self.db.flush()
        rejected_sources = (
            ("pending", "pending", "enacteur", False, "enacteur"),
            ("rejected", "rejected", "enactrice", False, "enacteur"),
            ("suspended", "suspended", "enacteur", False, "enacteur"),
            ("inactive", "inactive", "enactrice", False, "enacteur"),
            ("candidate", "candidate", "candidate", False, "candidate"),
            ("active-alumni-profile", "active", "alumni", True, "alumni"),
        )
        for label, source_status, profile_type, active, role_name in rejected_sources:
            with self.subTest(case=label):
                target = self._user(
                    status=source_status,
                    profile_type=profile_type,
                    active=active,
                )
                self._role(target, role_name)
                self.db.add_all(
                    [
                        PoleMember(pole_id=pole.id, user_id=target.id),
                        ProjectMember(project_id=project.id, user_id=target.id),
                    ]
                )
                self.db.flush()
                before = self._lifecycle_state(target)
                with self.assertRaises(HTTPException) as caught:
                    users.make_user_alumni(
                        str(target.id), _request(), self.db, admin
                    )
                self.assertEqual(caught.exception.status_code, 409)
                self.assertEqual(self._lifecycle_state(target), before)

        for profile_type in ("enacteur", "enactrice"):
            with self.subTest(allowed_profile=profile_type):
                target = self._user(profile_type=profile_type)
                self._role(target, "enacteur")
                pole_link = PoleMember(pole_id=pole.id, user_id=target.id)
                project_link = ProjectMember(project_id=project.id, user_id=target.id)
                self.db.add_all([pole_link, project_link])
                self.db.commit()
                users.make_user_alumni(
                    str(target.id), _request(), self.db, admin
                )
                self.assertEqual(target.status, "alumni")
                self.assertEqual(target.profile_type, "alumni")
                self.assertTrue(target.is_active)
                self.assertFalse(pole_link.is_active)
                self.assertFalse(project_link.is_active)
                self.assertEqual(self._lifecycle_state(target)["roles"], ("alumni",))

        pending_alumni = self._user(
            status="pending",
            profile_type="alumni",
            active=False,
            email_verified=False,
        )
        users.approve_user(
            str(pending_alumni.id), _request(), self.db, admin
        )
        self.assertEqual(pending_alumni.status, "alumni")
        self.assertEqual(pending_alumni.profile_type, "alumni")
        self.assertTrue(pending_alumni.is_active)
        self.assertTrue(pending_alumni.email_verified)
        self.assertEqual(self._lifecycle_state(pending_alumni)["roles"], ("alumni",))

    def test_email_verification_cannot_bypass_lifecycle_source_gates(self):
        admin = self._user()
        self._role(admin, "administrateur")
        for source_status in ("pending", "rejected"):
            with self.subTest(status=source_status):
                target = self._user(
                    status=source_status,
                    active=False,
                    email_verified=False,
                )
                self._role(target, "enacteur")
                users.admin_update_user(
                    str(target.id),
                    UserAdminUpdate(email_verified=True),
                    _request(),
                    self.db,
                    admin,
                )
                self.assertTrue(target.email_verified)
                verified_state = self._lifecycle_state(target)
                for transition in (users.suspend_user, users.make_user_alumni):
                    with self.assertRaises(HTTPException) as caught:
                        transition(str(target.id), _request(), self.db, admin)
                    self.assertEqual(caught.exception.status_code, 409)
                    self.assertEqual(self._lifecycle_state(target), verified_state)
                with self.assertRaises(HTTPException) as reactivation:
                    users.reactivate_user(
                        str(target.id), _request(), self.db, admin
                    )
                self.assertEqual(reactivation.exception.status_code, 409)
                self.assertEqual(self._lifecycle_state(target), verified_state)

    def test_generic_admin_patch_cannot_bypass_lifecycle(self):
        target = self._user()
        admin = self._user()
        self._role(admin, "administrateur")
        with self.assertRaises(HTTPException) as caught:
            users.admin_update_user(
                str(target.id),
                UserAdminUpdate(status="suspended", is_active=False),
                _request(),
                self.db,
                admin,
            )
        self.assertEqual(caught.exception.status_code, 409)
        self.assertEqual(target.status, "active")

    def test_global_role_assignment_requires_coherent_operational_profile(self):
        admin = self._user()
        self._role(admin, "administrateur")
        finance_role = Role(name="financier")
        self.db.add(finance_role)
        self.db.flush()

        for profile_type, initial_role in (
            ("alumni", "alumni"),
            ("candidate", "candidate"),
        ):
            with self.subTest(rejected_profile=profile_type):
                target = self._user(
                    status="active",
                    profile_type=profile_type,
                    active=True,
                )
                self._role(target, initial_role)
                before = self._lifecycle_state(target)

                with self.assertRaises(HTTPException) as caught:
                    users.assign_roles_to_user(
                        str(target.id),
                        UserRoleAssign(role_names=["financier"]),
                        _request(),
                        self.db,
                        admin,
                    )

                self.assertEqual(caught.exception.status_code, 409)
                self.assertEqual(self._lifecycle_state(target), before)

        for profile_type in ("enacteur", "enactrice"):
            with self.subTest(allowed_profile=profile_type):
                target = self._user(profile_type=profile_type)
                self._role(target, "enacteur")
                result = users.assign_roles_to_user(
                    str(target.id),
                    UserRoleAssign(role_names=["financier"]),
                    _request(),
                    self.db,
                    admin,
                )
                self.assertEqual(target.status, "active")
                self.assertEqual(target.profile_type, profile_type)
                self.assertTrue(target.is_active)
                self.assertEqual(set(result.roles), {"enacteur", "financier"})

    def test_recruitment_rbac_is_narrow(self):
        self.assertNotIn("chef_pole", RECRUITMENT_ACCESS_ROLES)
        self.assertNotIn("chef_projet", RECRUITMENT_ACCESS_ROLES)
        self.assertNotIn("financier", RECRUITMENT_ACCESS_ROLES)
        self.assertTrue({"recruiter", "recrutement", "pole_veille"}.issubset(RECRUITMENT_ACCESS_ROLES))

    def test_project_task_and_recruitment_transition_graphs(self):
        project = Project(name="Graph", status="idee")
        self.assertTrue(projects.apply_project_status(project, "etude"))
        with self.assertRaises(HTTPException) as project_error:
            projects.apply_project_status(project, "termine")
        self.assertEqual(project_error.exception.status_code, 409)
        project.status = "termine"
        with self.assertRaises(HTTPException):
            projects.apply_project_status(project, "test")

        task = Task(title="Proof", status="en_cours", proof_required=True)
        with self.assertRaises(HTTPException) as proof_error:
            tasks.apply_task_status(task, "termine", is_manager=False, actor_id=uuid.uuid4())
        self.assertEqual(proof_error.exception.status_code, 400)
        task.proof_url = "https://example.test/proof"
        self.assertTrue(tasks.apply_task_status(task, "termine", is_manager=False, actor_id=uuid.uuid4()))
        with self.assertRaises(HTTPException):
            tasks.apply_task_status(task, "valide", is_manager=False, actor_id=uuid.uuid4())
        self.assertTrue(tasks.apply_task_status(task, "valide", is_manager=True, actor_id=uuid.uuid4()))
        with self.assertRaises(HTTPException):
            tasks.apply_task_status(task, "en_cours", is_manager=True, actor_id=uuid.uuid4())

        application = Application(
            campaign_id=uuid.uuid4(),
            first_name="A",
            last_name="B",
            email="graph@example.test",
            status="submitted",
        )
        self.assertTrue(recruitment.apply_application_status(application, "preselected"))
        self.assertEqual(application.status, "under_review")
        self.assertTrue(recruitment.apply_application_status(application, "accepted"))
        with self.assertRaises(HTTPException):
            recruitment.apply_application_status(application, "under_review")

    def test_time_and_event_value_normalization(self):
        aware = datetime(2026, 9, 9, 12, tzinfo=timezone(timedelta(hours=2)))
        self.assertEqual(to_naive_utc(aware), datetime(2026, 9, 9, 10))
        events.validate_event_values(aware, aware + timedelta(hours=1), 0, 1)
        for values in (
            (aware, aware, 0, 1),
            (aware, aware + timedelta(hours=1), -1, 1),
            (aware, aware + timedelta(hours=1), 0, 0),
        ):
            with self.assertRaises(HTTPException):
                events.validate_event_values(*values)

    def test_database_identity_and_value_constraints(self):
        first = self._user()
        second = self._user()
        pole = Pole(name="Unique pole", type="support")
        self.db.add(pole)
        self.db.commit()
        first_id = first.id
        second_id = second.id
        pole_id = pole.id
        self.db.add_all(
            [
                PoleMember(pole_id=pole_id, user_id=first_id, position="chef_pole"),
                PoleMember(pole_id=pole_id, user_id=second_id, position="chef_pole"),
            ]
        )
        with self.assertRaises(IntegrityError):
            self.db.commit()
        self.db.rollback()

        first = self.db.get(User, first_id)
        session = AttendanceSession(title="Unique", status="open", is_closed=False)
        self.db.add(session)
        self.db.flush()
        self.db.add_all(
            [
                AttendanceRecord(session_id=session.id, user_id=first.id, status="present"),
                AttendanceRecord(session_id=session.id, user_id=first.id, status="late"),
            ]
        )
        with self.assertRaises(IntegrityError):
            self.db.commit()

    def test_penalty_is_cancelled_and_reused_without_erasing_history(self):
        member = self._user()
        actor = self._user()
        session = AttendanceSession(title="Penalty", status="closed", is_closed=True)
        self.db.add(session)
        self.db.flush()
        record = AttendanceRecord(
            session_id=session.id,
            user_id=member.id,
            status="absent",
            justification_status="not_submitted",
        )
        self.db.add(record)
        self.db.flush()
        attendance._sync_attendance_penalty(self.db, record, actor)
        self.db.flush()
        fee_id = record.penalty_fee_id
        fee = self.db.get(Fee, fee_id)
        fee.amount_paid = Decimal("20")
        self.db.flush()
        record.justification_status = "pending"
        attendance._sync_attendance_penalty(self.db, record, actor)
        self.db.flush()
        self.assertEqual(fee.status, "cancelled")
        self.assertEqual(fee.amount_paid, Decimal("20"))
        record.justification_status = "rejected"
        attendance._sync_attendance_penalty(self.db, record, actor)
        self.db.flush()
        self.assertEqual(record.penalty_fee_id, fee_id)
        self.assertEqual(self.db.query(Fee).filter(Fee.related_attendance_id == record.id).count(), 1)
        self.assertIn(fee.status, {"partial", "paid"})

    def test_manual_payment_finalization_is_sequentially_idempotent(self):
        payer = self._user()
        reviewer = self._user()
        self._role(reviewer, "administrateur")
        fee = Fee(user_id=payer.id, type="cotisation", label="Fee", amount=100, amount_paid=0)
        payment = Payment(user_id=payer.id, amount=100, method="cash", status="pending")
        self.db.add_all([fee, payment])
        self.db.commit()

        finance.validate_payment(str(payment.id), _request(), self.db, reviewer)
        finance.validate_payment(str(payment.id), _request(), self.db, reviewer)
        self.assertEqual(self.db.query(PaymentAllocation).filter_by(payment_id=payment.id).count(), 1)
        self.assertEqual(self.db.query(ClubTransaction).filter_by(payment_id=payment.id).count(), 1)
        account = self.db.query(FinancialAccount).filter_by(user_id=payer.id).one()
        self.assertEqual(account.total_paid, Decimal("100.00"))

    def test_conversion_rejects_incompatible_user_and_preserves_active_user(self):
        admin = self._user()
        self._role(admin, "administrateur")
        campaign = RecruitmentCampaign(title="Campaign")
        self.db.add(campaign)
        self.db.flush()
        suspended = self._user(status="suspended", active=False, email="same@example.test")
        application = Application(
            campaign_id=campaign.id,
            first_name="Same",
            last_name="Person",
            email="same@example.test",
            status="accepted",
        )
        self.db.add(application)
        self.db.commit()
        with self.assertRaises(HTTPException) as caught:
            recruitment.convert_application_to_user(
                str(application.id),
                ConvertApplicationToUserRequest(password="temporary-pass"),
                _request(),
                self.db,
                admin,
            )
        self.assertEqual(caught.exception.status_code, 409)
        self.assertIsNone(application.converted_user_id)
        self.assertEqual(suspended.status, "suspended")

    def test_conversion_profile_type_is_operational_and_existing_identity_is_preserved(self):
        admin = self._user()
        self._role(admin, "administrateur")
        campaign = RecruitmentCampaign(title="Profile conversion")
        core_pole = Pole(name="Existing conversion core", type="core")
        support_pole = Pole(name="Existing conversion support", type="support")
        project = Project(name="Existing conversion project")
        self.db.add_all([campaign, core_pole, support_pole, project])
        self.db.flush()
        female = Application(
            campaign_id=campaign.id,
            first_name="Profile",
            last_name="Female",
            gender="femme",
            email="female-profile@example.test",
            status="accepted",
        )
        invalid = Application(
            campaign_id=campaign.id,
            first_name="Profile",
            last_name="Invalid",
            email="invalid-profile@example.test",
            status="accepted",
        )
        existing = self._user(
            profile_type="enactrice",
            email="existing-profile@example.test",
        )
        linked = Application(
            campaign_id=campaign.id,
            first_name="Existing",
            last_name="Profile",
            email="EXISTING-PROFILE@example.test",
            status="accepted",
        )
        self.db.add_all([female, invalid, linked])
        self.db.commit()

        result = recruitment.convert_application_to_user(
            str(female.id),
            ConvertApplicationToUserRequest(password="temporary-pass"),
            _request(), self.db, admin,
        )
        converted = self.db.get(User, uuid.UUID(result["user_id"]))
        self.assertEqual(converted.profile_type, "enactrice")

        for unsupported in ("candidate", "alumni", "arbitrary"):
            with self.subTest(unsupported=unsupported):
                with self.assertRaises(HTTPException) as caught:
                    recruitment.convert_application_to_user(
                        str(invalid.id),
                        ConvertApplicationToUserRequest(
                            password="temporary-pass",
                            profile_type=unsupported,
                        ),
                        _request(), self.db, admin,
                    )
                self.assertEqual(caught.exception.status_code, 400)

        result = recruitment.convert_application_to_user(
            str(linked.id),
            ConvertApplicationToUserRequest(
                password="temporary-pass",
                profile_type="enacteur",
                core_pole_id=core_pole.id,
                support_pole_ids=[support_pole.id],
                project_id=project.id,
            ),
            _request(), self.db, admin,
        )
        self.assertEqual(result["user_id"], str(existing.id))
        self.assertEqual(existing.profile_type, "enactrice")
        self.assertEqual(existing.status, "active")
        self.assertIsNone(result["core_pole_id"])
        self.assertIsNone(result["project_id"])
        self.assertEqual(
            self.db.query(PoleMember).filter(PoleMember.user_id == existing.id).count(),
            0,
        )
        self.assertEqual(
            self.db.query(ProjectMember)
            .filter(ProjectMember.user_id == existing.id)
            .count(),
            0,
        )

    def test_mobile_money_terminal_attempt_allows_immediate_retry(self):
        member = self._user()
        fee = Fee(
            user_id=member.id,
            type="cotisation",
            label="Retry fee",
            amount=100,
            amount_paid=0,
        )
        self.db.add(fee)
        self.db.commit()

        class Provider:
            calls = 0

            async def create_payment(self, request):
                self.calls += 1
                return PaymentProviderResult(
                    provider="paydunya",
                    status="pending",
                    provider_token=f"token-{request.transaction_id}",
                    provider_transaction_id=f"provider-{request.transaction_id}",
                    checkout_url=f"https://example.test/{request.transaction_id}",
                )

        provider = Provider()
        payload = MobileMoneyInitiateRequest(
            finance_item_ids=[fee.id],
        )
        with (
            patch.object(finance, "get_payment_provider", return_value=provider),
            patch.object(finance.settings, "MOBILE_MONEY_ENABLED", True),
        ):
            first = asyncio.run(
                finance.initiate_mobile_money_payment(
                    payload, _request(), self.db, member
                )
            )
            first_row = self.db.get(MobileMoneyTransaction, first["transaction_id"])
            first_row.status = "failed"
            self.db.commit()
            second = asyncio.run(
                finance.initiate_mobile_money_payment(
                    payload, _request(), self.db, member
                )
            )

        self.assertNotEqual(first["transaction_id"], second["transaction_id"])
        self.assertEqual(provider.calls, 2)
        self.assertEqual(
            self.db.query(MobileMoneyTransaction).filter(
                MobileMoneyTransaction.member_id == member.id,
                MobileMoneyTransaction.status.in_(("created", "pending", "processing")),
            ).count(),
            1,
        )

    def test_event_detail_route_and_registration_eligibility(self):
        paths = {route.path for route in events.router.routes}
        self.assertIn("/events/{event_id}", paths)
        candidate = self._user(profile_type="candidate")
        event_row = Event(
            title="Community",
            event_type="meeting",
            start_time=datetime.utcnow() + timedelta(days=1),
            requires_registration=True,
            max_participants=1,
        )
        self.db.add(event_row)
        self.db.commit()
        with self.assertRaises(HTTPException) as caught:
            events.register_for_event(str(event_row.id), self.db, candidate)
        self.assertEqual(caught.exception.status_code, 403)
        self.assertEqual(self.db.query(EventParticipant).count(), 0)

    def test_attendance_event_reference_is_reauthorized(self):
        creator = self._user()
        outsider = self._user()
        event_row = Event(
            title="Scoped event",
            event_type="meeting",
            start_time=datetime.utcnow() + timedelta(days=1),
            created_by=creator.id,
        )
        self.db.add(event_row)
        self.db.flush()

        attendance._validate_event_reference_permissions(
            self.db,
            creator,
            event_row.id,
        )
        with self.assertRaises(HTTPException) as caught:
            attendance._validate_event_reference_permissions(
                self.db,
                outsider,
                event_row.id,
            )
        self.assertEqual(caught.exception.status_code, 403)


if __name__ == "__main__":
    unittest.main()
