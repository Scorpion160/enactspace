"""PR-6.5 operational integrity rules on the portable SQLite test database."""

import asyncio
import unittest
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from fastapi import HTTPException
from sqlalchemy import create_engine, event
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.requests import Request
from unittest.mock import patch

import app.models.base  # noqa: F401
from app.api.routes import attendance, events, finance, projects, recruitment, tasks, users
from app.core.roles import RECRUITMENT_ACCESS_ROLES
from app.db.database import Base
from app.models.attendance import AttendanceRecord, AttendanceSession
from app.models.audit import AuditLog
from app.models.event import Event, EventParticipant
from app.models.finance import ClubTransaction, Fee, FinancialAccount, Payment, PaymentAllocation
from app.models.mobile_money import MobileMoneyTransaction
from app.models.notification import Notification
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember
from app.models.recruitment import Application, RecruitmentCampaign
from app.models.role import Role, UserRole
from app.models.task import Task
from app.models.user import User
from app.schemas.recruitment import ConvertApplicationToUserRequest
from app.schemas.mobile_money import MobileMoneyInitiateRequest
from app.schemas.user import UserAdminUpdate, UserRoleAssign
from app.services.operational_integrity import reconcile_user_lifecycle, to_naive_utc
from app.services.payments import PaymentProviderResult


def _request() -> Request:
    return Request({"type": "http", "client": ("127.0.0.1", 12345), "headers": []})


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
