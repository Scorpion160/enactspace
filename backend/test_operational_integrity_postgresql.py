"""PR-6.5 PostgreSQL 16 locking and exactly-once acceptance tests."""

import asyncio
import os
import secrets
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta
from threading import Barrier, Lock
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from fastapi import HTTPException
from sqlalchemy import create_engine, func, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from starlette.requests import Request

import app.models.base  # noqa: F401
from app.api.routes import (
    attendance,
    events,
    finance,
    payments,
    poles,
    projects,
    recruitment,
    users,
)
from app.core.config import settings
from app.models.attendance import AttendanceExpectedMember, AttendanceRecord, AttendanceSession
from app.models.event import Event, EventParticipant
from app.models.finance import ClubTransaction, Fee, FinancialAccount, Payment, PaymentAllocation
from app.models.mobile_money import MobileMoneyTransaction, MobileMoneyTransactionEvent
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember
from app.models.recruitment import Application, RecruitmentCampaign
from app.models.role import Role, UserRole
from app.models.user import User
from app.schemas.finance import PaymentRejectRequest
from app.schemas.mobile_money import MobileMoneyInitiateRequest
from app.schemas.pole import PoleMemberAssign
from app.schemas.project import ProjectMemberAssign
from app.schemas.recruitment import ConvertApplicationToUserRequest
from app.schemas.user import UserRoleAssign
import app.services.mobile_money_service as mobile_money_service
from app.services.operational_integrity import lock_row
from app.services.payments import PaymentProviderResult


def _request() -> Request:
    return Request({"type": "http", "client": ("127.0.0.1", 12345), "headers": []})


class OperationalIntegrityPostgreSQLTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw_url = os.environ.get("TEST_DATABASE_URL")
        if not raw_url:
            raise unittest.SkipTest("TEST_DATABASE_URL missing: real PostgreSQL tests NOT RUN")
        url = make_url(raw_url)
        if (
            url.get_backend_name() != "postgresql"
            or url.host not in {"localhost", "127.0.0.1", "::1"}
            or not (url.database or "").startswith("enactspace_pr2b_test")
        ):
            raise RuntimeError("Refusing a non-local or non-test PostgreSQL database")
        cls.schema = "pr65_" + secrets.token_hex(12)
        cls.admin_engine = create_engine(url, connect_args={"connect_timeout": 5})
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA "{cls.schema}"'))
        isolated = url.update_query_dict({"options": f"-csearch_path={cls.schema}"})
        cls.url = isolated.render_as_string(hide_password=False)
        cls.engine = create_engine(cls.url, connect_args={"connect_timeout": 5})
        cls.Session = sessionmaker(bind=cls.engine, autoflush=False)
        config = Config("alembic.ini")
        with patch.object(settings, "DATABASE_URL", cls.url):
            command.upgrade(config, "head")

    @classmethod
    def tearDownClass(cls):
        cls.engine.dispose()
        if cls.schema.startswith("pr65_") and len(cls.schema) == 29:
            with cls.admin_engine.begin() as connection:
                connection.execute(text(f'DROP SCHEMA "{cls.schema}" CASCADE'))
        cls.admin_engine.dispose()

    def _user(self, *, roles=(), status="active", active=True, profile_type="enacteur", email=None):
        db = self.Session()
        try:
            user = User(
                first_name="PR65",
                last_name="Race",
                email=email or f"{uuid.uuid4()}@example.test",
                password_hash="unused",
                status=status,
                is_active=active,
                profile_type=profile_type,
                email_verified=True,
            )
            db.add(user)
            db.flush()
            for name in roles:
                role = db.query(Role).filter(Role.name == name).with_for_update().first()
                if role is None:
                    role = Role(name=name)
                    db.add(role)
                    db.flush()
                db.add(UserRole(user_id=user.id, role_id=role.id))
            db.commit()
            return user.id
        finally:
            db.close()

    def _parallel(self, first, second):
        barrier = Barrier(2)

        def run(callback):
            try:
                barrier.wait(timeout=10)
                return ("ok", callback())
            except HTTPException as exc:
                return ("http", exc.status_code, str(exc.detail))
            except IntegrityError as exc:
                diagnostic = getattr(exc.orig, "diag", None)
                constraint = getattr(diagnostic, "constraint_name", None)
                return ("integrity", exc.orig.__class__.__name__, constraint)

        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(run, first), executor.submit(run, second)]
            return [future.result(timeout=30) for future in futures]

    def _assert_race_outcomes(
        self,
        results,
        *,
        success_count: int | None = None,
        minimum_successes: int = 1,
        allowed_http: set[int] | None = None,
        allow_integrity: bool = False,
    ):
        allowed_http = allowed_http or set()
        self.assertEqual(len(results), 2, results)
        successes = sum(result[0] == "ok" for result in results)
        if success_count is None:
            self.assertGreaterEqual(successes, minimum_successes, results)
        else:
            self.assertEqual(successes, success_count, results)
        for result in results:
            if result[0] == "ok":
                continue
            if result[0] == "http":
                self.assertIn(result[1], allowed_http, results)
                continue
            if result[0] == "integrity" and allow_integrity:
                continue
            self.fail(f"Unexpected concurrent outcome: {result!r}; all={results!r}")

    def _admin(self):
        return self._user(roles=("administrateur",))

    def test_01_global_team_leader_assignment_has_one_final_holder(self):
        admin_id = self._admin()
        first_id = self._user(roles=("enacteur",))
        second_id = self._user(roles=("enacteur",))
        db = self.Session()
        role = Role(name="team_leader")
        db.add(role)
        db.commit()
        db.close()

        def assign(target_id):
            def operation():
                session = self.Session()
                try:
                    return users.assign_roles_to_user(
                        str(target_id), UserRoleAssign(role_names=["team_leader"]),
                        _request(), session, session.get(User, admin_id),
                    )
                finally:
                    session.close()
            return operation

        results = self._parallel(assign(first_id), assign(second_id))
        self._assert_race_outcomes(results, minimum_successes=1, allowed_http={409})
        db = self.Session()
        count = db.query(UserRole).join(Role).filter(Role.name == "team_leader").count()
        db.close()
        self.assertEqual(count, 1)

    def test_02_pole_leader_assignment_has_one_final_holder(self):
        admin_id = self._admin()
        first_id, second_id = self._user(), self._user()
        db = self.Session()
        pole = Pole(name=f"Pole {uuid.uuid4()}", type="support")
        db.add(pole)
        db.commit()
        pole_id = pole.id
        db.close()

        def assign(target_id):
            def operation():
                session = self.Session()
                try:
                    return poles.assign_pole_member(
                        str(pole_id), PoleMemberAssign(user_id=target_id, position="chef_pole"),
                        _request(), session, session.get(User, admin_id),
                    )
                finally:
                    session.close()
            return operation

        results = self._parallel(assign(first_id), assign(second_id))
        self._assert_race_outcomes(results, minimum_successes=1, allowed_http={409})
        db = self.Session()
        leaders = db.query(PoleMember).filter_by(pole_id=pole_id, position="chef_pole", is_active=True).count()
        db.close()
        self.assertEqual(leaders, 1)

    def test_03_project_leader_assignment_has_one_final_holder(self):
        admin_id = self._admin()
        first_id, second_id = self._user(), self._user()
        db = self.Session()
        project = Project(name=f"Project {uuid.uuid4()}")
        db.add(project)
        db.commit()
        project_id = project.id
        db.close()

        def assign(target_id):
            def operation():
                session = self.Session()
                try:
                    return projects.assign_project_member(
                        str(project_id), ProjectMemberAssign(user_id=target_id, position="chef_projet"),
                        _request(), session, session.get(User, admin_id),
                    )
                finally:
                    session.close()
            return operation

        results = self._parallel(assign(first_id), assign(second_id))
        self._assert_race_outcomes(results, minimum_successes=1, allowed_http={409})
        db = self.Session()
        leaders = db.query(ProjectMember).filter_by(project_id=project_id, position="chef_projet", is_active=True).count()
        db.close()
        self.assertEqual(leaders, 1)

    def _attendance_session(self):
        admin_id = self._admin()
        member_id = self._user()
        db = self.Session()
        row = AttendanceSession(title=f"Session {uuid.uuid4()}", status="open", is_closed=False, created_by=admin_id)
        db.add(row)
        db.flush()
        db.add(AttendanceExpectedMember(session_id=row.id, user_id=member_id))
        db.commit()
        identifiers = (admin_id, member_id, row.id)
        db.close()
        return identifiers

    def _close_operation(self, session_id, admin_id):
        def operation():
            db = self.Session()
            try:
                return attendance.close_attendance_session(
                    str(session_id), _request(), db, db.get(User, admin_id)
                )
            finally:
                db.close()
        return operation

    def test_04_concurrent_attendance_close_creates_one_record(self):
        admin_id, member_id, session_id = self._attendance_session()
        results = self._parallel(
            self._close_operation(session_id, admin_id),
            self._close_operation(session_id, admin_id),
        )
        self._assert_race_outcomes(results, success_count=2)
        db = self.Session()
        self.assertEqual(db.query(AttendanceRecord).filter_by(session_id=session_id, user_id=member_id).count(), 1)
        db.close()

    def test_05_concurrent_attendance_close_creates_one_penalty(self):
        admin_id, member_id, session_id = self._attendance_session()
        results = self._parallel(
            self._close_operation(session_id, admin_id),
            self._close_operation(session_id, admin_id),
        )
        self._assert_race_outcomes(results, success_count=2)
        db = self.Session()
        record = db.query(AttendanceRecord).filter_by(session_id=session_id, user_id=member_id).one()
        self.assertEqual(db.query(Fee).filter_by(related_attendance_id=record.id).count(), 1)
        db.close()

    def test_06_qr_nfc_manual_funnel_has_one_attendance_truth(self):
        admin_id, member_id, session_id = self._attendance_session()

        def point(source):
            def operation():
                db = self.Session()
                try:
                    session = lock_row(db, AttendanceSession, session_id)
                    actor = db.get(User, admin_id)
                    attendance._upsert_record(
                        db, session, actor, user_id=member_id,
                        attendance_status="present", source=source,
                    )
                    db.commit()
                finally:
                    db.close()
            return operation

        results = self._parallel(point("qr"), point("nfc"))
        self._assert_race_outcomes(results, success_count=2)
        db = self.Session()
        self.assertEqual(db.query(AttendanceRecord).filter_by(session_id=session_id, user_id=member_id).count(), 1)
        db.close()

    def _payment(self):
        payer_id = self._user()
        reviewer_id = self._admin()
        db = self.Session()
        fee = Fee(user_id=payer_id, type="cotisation", label="Race fee", amount=100, amount_paid=0)
        payment = Payment(user_id=payer_id, amount=100, method="cash", status="pending")
        account = FinancialAccount(user_id=payer_id, balance_due=100, total_paid=0)
        db.add_all([fee, payment, account])
        db.commit()
        result = (payer_id, reviewer_id, payment.id)
        db.close()
        return result

    def test_07_double_manual_payment_validation_applies_once(self):
        _, reviewer_id, payment_id = self._payment()

        def validate():
            db = self.Session()
            try:
                return finance.validate_payment(str(payment_id), _request(), db, db.get(User, reviewer_id))
            finally:
                db.close()

        results = self._parallel(validate, validate)
        self._assert_race_outcomes(results, success_count=2)
        db = self.Session()
        self.assertEqual(db.query(PaymentAllocation).filter_by(payment_id=payment_id).count(), 1)
        self.assertEqual(db.query(ClubTransaction).filter_by(payment_id=payment_id).count(), 1)
        db.close()

    def test_08_validate_vs_reject_has_one_terminal_state(self):
        _, reviewer_id, payment_id = self._payment()

        def validate():
            db = self.Session()
            try:
                return finance.validate_payment(str(payment_id), _request(), db, db.get(User, reviewer_id))
            finally:
                db.close()

        def reject():
            db = self.Session()
            try:
                return finance.reject_payment(
                    str(payment_id), PaymentRejectRequest(reason="invalid"),
                    _request(), db, db.get(User, reviewer_id),
                )
            finally:
                db.close()

        results = self._parallel(validate, reject)
        self._assert_race_outcomes(results, minimum_successes=1, allowed_http={409})
        db = self.Session()
        payment = db.get(Payment, payment_id)
        self.assertIn(payment.status, {"validated", "rejected"})
        self.assertLessEqual(db.query(ClubTransaction).filter_by(payment_id=payment_id).count(), 1)
        db.close()

    def _mobile_transaction(self):
        member_id = self._user()
        db = self.Session()
        fee = Fee(user_id=member_id, type="cotisation", label="Mobile fee", amount=100, amount_paid=0)
        account = FinancialAccount(user_id=member_id, balance_due=100, total_paid=0)
        db.add_all([fee, account])
        db.flush()
        transaction = MobileMoneyTransaction(
            member_id=member_id,
            finance_item_id=fee.id,
            provider="fake",
            idempotency_key=f"pr65-{uuid.uuid4()}",
            amount=100,
            currency="XOF",
            status="pending",
            metadata_json={"finance_item_ids": [str(fee.id)]},
        )
        db.add(transaction)
        db.commit()
        result = (member_id, transaction.id)
        db.close()
        return result

    def _confirm_operation(self, transaction_id, event_id):
        def operation():
            db = self.Session()
            try:
                transaction = db.get(MobileMoneyTransaction, transaction_id)
                mobile_money_service.confirm_transaction(
                    db,
                    transaction=transaction,
                    provider_status="completed",
                    provider_transaction_id=f"provider-{transaction_id}",
                    provider_event_id=event_id,
                    request=_request(),
                )
                db.commit()
            finally:
                db.close()
        return operation

    class _SuccessfulProvider:
        def __init__(self, transaction_id, event_id):
            self.result = PaymentProviderResult(
                provider="paydunya",
                status="successful",
                provider_token=f"provider-token-{transaction_id}",
                provider_transaction_id=f"provider-transaction-{transaction_id}",
                provider_status="completed",
                metadata={
                    "amount": 100,
                    "currency": "XOF",
                    "event_id": event_id,
                    "custom_data": {
                        "enactspace_transaction_id": str(transaction_id),
                    },
                },
            )

        async def verify_callback(self, _payload):
            return self.result

        async def get_payment_status(self, **_kwargs):
            return self.result

    def _assert_mobile_money_truth(self, transaction_id, provider_event_id):
        db = self.Session()
        try:
            transaction = db.get(MobileMoneyTransaction, transaction_id)
            self.assertEqual(transaction.status, "successful")
            self.assertIsNotNone(transaction.payment_id)
            self.assertEqual(
                db.query(Payment).filter(Payment.id == transaction.payment_id).count(),
                1,
            )
            self.assertEqual(
                db.query(ClubTransaction)
                .filter(ClubTransaction.payment_id == transaction.payment_id)
                .count(),
                1,
            )
            self.assertEqual(
                db.query(PaymentAllocation)
                .filter(PaymentAllocation.payment_id == transaction.payment_id)
                .count(),
                1,
            )
            self.assertEqual(
                db.query(MobileMoneyTransactionEvent)
                .filter_by(
                    transaction_id=transaction_id,
                    provider_event_id=provider_event_id,
                )
                .count(),
                1,
            )
            self.assertEqual(
                db.query(Payment)
                .filter(
                    Payment.user_id == transaction.member_id,
                    Payment.method == "mobile_money",
                    Payment.status == "validated",
                )
                .count(),
                1,
            )
        finally:
            db.close()

    def test_09_ipn_vs_refresh_creates_one_payment(self):
        member_id, transaction_id = self._mobile_transaction()
        provider_event_id = "ipn-refresh"
        provider = self._SuccessfulProvider(transaction_id, provider_event_id)

        def ipn():
            db = self.Session()
            try:
                return asyncio.run(payments.paydunya_ipn({}, _request(), db))
            finally:
                db.close()

        def refresh():
            db = self.Session()
            try:
                return asyncio.run(
                    finance.refresh_mobile_money_payment_status(
                        str(transaction_id),
                        _request(),
                        db,
                        db.get(User, member_id),
                    )
                )
            finally:
                db.close()

        with (
            patch.object(payments, "get_payment_provider", return_value=provider),
            patch.object(
                mobile_money_service,
                "get_payment_provider",
                return_value=provider,
            ),
        ):
            results = self._parallel(ipn, refresh)
        self._assert_race_outcomes(results, success_count=2)
        self._assert_mobile_money_truth(transaction_id, provider_event_id)

    def test_10_refresh_vs_reconcile_creates_one_payment(self):
        member_id, transaction_id = self._mobile_transaction()
        admin_id = self._admin()
        provider_event_id = "refresh-reconcile"
        provider = self._SuccessfulProvider(transaction_id, provider_event_id)

        def refresh():
            db = self.Session()
            try:
                return asyncio.run(
                    finance.refresh_mobile_money_payment_status(
                        str(transaction_id),
                        _request(),
                        db,
                        db.get(User, member_id),
                    )
                )
            finally:
                db.close()

        def reconcile():
            db = self.Session()
            try:
                return asyncio.run(
                    finance.reconcile_mobile_money_payments(
                        _request(),
                        50,
                        db,
                        db.get(User, admin_id),
                    )
                )
            finally:
                db.close()

        with (
            patch.object(
                mobile_money_service,
                "get_payment_provider",
                return_value=provider,
            ),
            patch.object(settings, "PAYMENT_RECONCILIATION_ENABLED", True),
        ):
            results = self._parallel(refresh, reconcile)
        self._assert_race_outcomes(results, success_count=2)
        self._assert_mobile_money_truth(transaction_id, provider_event_id)

    def test_11_duplicate_provider_event_has_one_financial_effect(self):
        _, transaction_id = self._mobile_transaction()
        provider_event_id = "provider-event-1"
        results = self._parallel(
            self._confirm_operation(transaction_id, provider_event_id),
            self._confirm_operation(transaction_id, provider_event_id),
        )
        self._assert_race_outcomes(results, success_count=2)
        self._assert_mobile_money_truth(transaction_id, provider_event_id)

    def test_12_concurrent_candidate_conversion_returns_one_user(self):
        admin_id = self._admin()
        db = self.Session()
        campaign = RecruitmentCampaign(title=f"Campaign {uuid.uuid4()}")
        db.add(campaign)
        db.flush()
        email = f"convert-{uuid.uuid4()}@example.test"
        application = Application(campaign_id=campaign.id, first_name="New", last_name="Member", email=email, status="accepted")
        db.add(application)
        db.commit()
        application_id = application.id
        db.close()

        def convert():
            session = self.Session()
            try:
                return recruitment.convert_application_to_user(
                    str(application_id), ConvertApplicationToUserRequest(password="temporary-pass"),
                    _request(), session, session.get(User, admin_id),
                )
            finally:
                session.close()

        results = self._parallel(convert, convert)
        self._assert_race_outcomes(results, success_count=2)
        db = self.Session()
        application = db.get(Application, application_id)
        self.assertIsNotNone(application.converted_user_id)
        self.assertEqual(db.query(User).filter(func.lower(User.email) == email.lower()).count(), 1)
        self.assertEqual({result[1]["user_id"] for result in results if result[0] == "ok"}, {str(application.converted_user_id)})
        db.close()

    def test_13_duplicate_campaign_email_application_has_one_row(self):
        db = self.Session()
        campaign = RecruitmentCampaign(title=f"Campaign {uuid.uuid4()}")
        db.add(campaign)
        db.commit()
        campaign_id = campaign.id
        db.close()
        email = f"duplicate-{uuid.uuid4()}@example.test"

        def submit(value):
            def operation():
                session = self.Session()
                try:
                    session.add(Application(campaign_id=campaign_id, first_name=value, last_name="Race", email=value, status="submitted"))
                    session.commit()
                finally:
                    session.close()
            return operation

        results = self._parallel(submit(email.lower()), submit(email.upper()))
        self._assert_race_outcomes(
            results,
            success_count=1,
            allow_integrity=True,
        )
        db = self.Session()
        self.assertEqual(db.query(Application).filter(Application.campaign_id == campaign_id, func.lower(Application.email) == email.lower()).count(), 1)
        db.close()

    def test_14_last_event_seat_has_one_winner(self):
        first_id, second_id = self._user(), self._user()
        db = self.Session()
        event_row = Event(title=f"Seat {uuid.uuid4()}", event_type="meeting", start_time=datetime.utcnow() + timedelta(days=1), requires_registration=True, max_participants=1)
        db.add(event_row)
        db.commit()
        event_id = event_row.id
        db.close()

        def register(user_id):
            def operation():
                session = self.Session()
                try:
                    return events.register_for_event(str(event_id), session, session.get(User, user_id))
                finally:
                    session.close()
            return operation

        results = self._parallel(register(first_id), register(second_id))
        self._assert_race_outcomes(
            results,
            success_count=1,
            allowed_http={409},
        )
        self.assertEqual(sum(result[0] == "ok" for result in results), 1)
        db = self.Session()
        self.assertEqual(db.query(EventParticipant).filter_by(event_id=event_id).count(), 1)
        db.close()

    def test_15_role_assignment_vs_suspend_leaves_no_authority(self):
        admin_id = self._admin()
        target_id = self._user(roles=("enacteur",))
        db = self.Session()
        if db.query(Role).filter_by(name="financier").first() is None:
            db.add(Role(name="financier"))
            db.commit()
        db.close()

        def assign():
            db = self.Session()
            try:
                return users.assign_roles_to_user(
                    str(target_id), UserRoleAssign(role_names=["enacteur", "financier"]),
                    _request(), db, db.get(User, admin_id),
                )
            finally:
                db.close()

        def suspend():
            db = self.Session()
            try:
                return users.suspend_user(str(target_id), _request(), db, db.get(User, admin_id))
            finally:
                db.close()

        results = self._parallel(assign, suspend)
        self._assert_race_outcomes(
            results,
            minimum_successes=1,
            allowed_http={400, 409},
        )
        db = self.Session()
        target = db.get(User, target_id)
        roles = {row[0] for row in db.query(Role.name).join(UserRole).filter(UserRole.user_id == target_id)}
        self.assertEqual(target.status, "suspended")
        self.assertFalse(target.is_active)
        self.assertEqual(roles, {"enacteur"})
        db.close()

    def test_16_lifecycle_preserves_enactrice_and_restores_alumni(self):
        admin_id = self._admin()
        enactrice_id = self._user(
            roles=("enacteur", "recruiter"),
            profile_type="enactrice",
        )
        alumni_id = self._user(
            roles=("alumni", "recruiter"),
            status="alumni",
            profile_type="alumni",
        )
        db = self.Session()
        pole = Pole(name=f"Lifecycle {uuid.uuid4()}", type="support")
        project = Project(name=f"Lifecycle {uuid.uuid4()}")
        db.add_all([pole, project])
        db.flush()
        db.add_all([
            PoleMember(pole_id=pole.id, user_id=alumni_id),
            ProjectMember(project_id=project.id, user_id=alumni_id),
        ])
        db.commit()
        pole_id, project_id = pole.id, project.id
        db.close()

        for user_id in (enactrice_id, alumni_id):
            db = self.Session()
            try:
                users.suspend_user(
                    str(user_id), _request(), db, db.get(User, admin_id)
                )
            finally:
                db.close()
            db = self.Session()
            try:
                users.reactivate_user(
                    str(user_id), _request(), db, db.get(User, admin_id)
                )
            finally:
                db.close()

        db = self.Session()
        enactrice = db.get(User, enactrice_id)
        alumni = db.get(User, alumni_id)
        self.assertEqual((enactrice.status, enactrice.profile_type, enactrice.is_active), ("active", "enactrice", True))
        self.assertEqual((alumni.status, alumni.profile_type, alumni.is_active), ("alumni", "alumni", True))
        enactrice_roles = {name for name, in db.query(Role.name).join(UserRole).filter(UserRole.user_id == enactrice_id)}
        alumni_roles = {name for name, in db.query(Role.name).join(UserRole).filter(UserRole.user_id == alumni_id)}
        self.assertEqual(enactrice_roles, {"enacteur"})
        self.assertEqual(alumni_roles, {"alumni"})
        self.assertFalse(db.query(PoleMember).filter_by(pole_id=pole_id, user_id=alumni_id).one().is_active)
        self.assertFalse(db.query(ProjectMember).filter_by(project_id=project_id, user_id=alumni_id).one().is_active)
        db.close()

    def test_17_conversion_vs_application_delete_preserves_provenance(self):
        admin_id = self._admin()
        db = self.Session()
        campaign = RecruitmentCampaign(title=f"Application delete {uuid.uuid4()}")
        db.add(campaign)
        db.flush()
        email = f"application-delete-{uuid.uuid4()}@example.test"
        application = Application(
            campaign_id=campaign.id,
            first_name="Race",
            last_name="Application",
            email=email,
            status="accepted",
        )
        db.add(application)
        db.commit()
        application_id = application.id
        db.close()

        def convert():
            session = self.Session()
            try:
                return recruitment.convert_application_to_user(
                    str(application_id),
                    ConvertApplicationToUserRequest(password="temporary-pass"),
                    _request(), session, session.get(User, admin_id),
                )
            finally:
                session.close()

        def delete():
            session = self.Session()
            try:
                return recruitment.delete_application(
                    str(application_id), session, session.get(User, admin_id)
                )
            finally:
                session.close()

        results = self._parallel(convert, delete)
        self._assert_race_outcomes(results, success_count=1, allowed_http={404, 409})
        db = self.Session()
        application = db.get(Application, application_id)
        users_count = db.query(User).filter(func.lower(User.email) == email.lower()).count()
        if users_count:
            self.assertIsNotNone(application)
            self.assertIsNotNone(application.converted_user_id)
        else:
            self.assertIsNone(application)
        db.close()

    def test_18_conversion_vs_campaign_delete_preserves_provenance(self):
        admin_id = self._admin()
        db = self.Session()
        campaign = RecruitmentCampaign(title=f"Campaign delete {uuid.uuid4()}")
        db.add(campaign)
        db.flush()
        email = f"campaign-delete-{uuid.uuid4()}@example.test"
        application = Application(
            campaign_id=campaign.id,
            first_name="Race",
            last_name="Campaign",
            email=email,
            status="accepted",
        )
        db.add(application)
        db.commit()
        campaign_id, application_id = campaign.id, application.id
        db.close()

        def convert():
            session = self.Session()
            try:
                return recruitment.convert_application_to_user(
                    str(application_id),
                    ConvertApplicationToUserRequest(password="temporary-pass"),
                    _request(), session, session.get(User, admin_id),
                )
            finally:
                session.close()

        def delete():
            session = self.Session()
            try:
                return recruitment.delete_campaign(
                    str(campaign_id), session, session.get(User, admin_id)
                )
            finally:
                session.close()

        results = self._parallel(convert, delete)
        self._assert_race_outcomes(results, success_count=1, allowed_http={404, 409})
        db = self.Session()
        application = db.get(Application, application_id)
        users_count = db.query(User).filter(func.lower(User.email) == email.lower()).count()
        if users_count:
            self.assertIsNotNone(db.get(RecruitmentCampaign, campaign_id))
            self.assertIsNotNone(application)
            self.assertIsNotNone(application.converted_user_id)
        else:
            self.assertIsNone(db.get(RecruitmentCampaign, campaign_id))
            self.assertIsNone(application)
        db.close()

    def test_19_cross_campaign_case_insensitive_conversion_has_one_user(self):
        admin_id = self._admin()
        db = self.Session()
        campaigns = [
            RecruitmentCampaign(title=f"Cross campaign {uuid.uuid4()}")
            for _ in range(2)
        ]
        core_pole = Pole(name=f"Cross core {uuid.uuid4()}", type="core")
        support_pole = Pole(name=f"Cross support {uuid.uuid4()}", type="support")
        project = Project(name=f"Cross project {uuid.uuid4()}")
        db.add_all([*campaigns, core_pole, support_pole, project])
        db.flush()
        core_pole_id = core_pole.id
        support_pole_id = support_pole.id
        project_id = project.id
        email = f"case-{uuid.uuid4()}@example.test"
        applications = [
            Application(
                campaign_id=campaigns[0].id,
                first_name="Case",
                last_name="Upper",
                email=email.upper(),
                status="accepted",
            ),
            Application(
                campaign_id=campaigns[1].id,
                first_name="Case",
                last_name="Lower",
                email=email.lower(),
                status="accepted",
            ),
        ]
        db.add_all(applications)
        db.commit()
        application_ids = [application.id for application in applications]
        db.close()

        def convert(application_id):
            def operation():
                session = self.Session()
                try:
                    return recruitment.convert_application_to_user(
                        str(application_id),
                        ConvertApplicationToUserRequest(
                            password="temporary-pass",
                            core_pole_id=core_pole_id,
                            support_pole_ids=[support_pole_id],
                            project_id=project_id,
                        ),
                        _request(), session, session.get(User, admin_id),
                    )
                finally:
                    session.close()
            return operation

        results = self._parallel(convert(application_ids[0]), convert(application_ids[1]))
        self._assert_race_outcomes(results, success_count=2)
        self.assertNotIn("integrity", {result[0] for result in results})
        response_scopes = {
            (result[1]["core_pole_id"], result[1]["project_id"])
            for result in results
        }
        self.assertEqual(
            response_scopes,
            {(str(core_pole_id), str(project_id)), (None, None)},
        )
        db = self.Session()
        matching_user = db.query(User).filter(func.lower(User.email) == email.lower()).one()
        linked_ids = {
            db.get(Application, application_id).converted_user_id
            for application_id in application_ids
            if db.get(Application, application_id).converted_user_id is not None
        }
        self.assertLessEqual(len(linked_ids), 1)
        if len(linked_ids) == 1:
            self.assertEqual(linked_ids, {matching_user.id})
        self.assertEqual(
            db.query(PoleMember).filter(
                PoleMember.user_id == matching_user.id,
                PoleMember.is_active.is_(True),
            ).count(),
            2,
        )
        self.assertEqual(
            db.query(ProjectMember).filter(
                ProjectMember.user_id == matching_user.id,
                ProjectMember.is_active.is_(True),
            ).count(),
            1,
        )
        db.close()

    def test_20_mobile_money_active_dedupe_and_terminal_retry(self):
        member_id = self._user()
        db = self.Session()
        fee = Fee(user_id=member_id, type="cotisation", label="Retry race", amount=100, amount_paid=0)
        db.add(fee)
        db.commit()
        fee_id = fee.id
        db.close()

        class Provider:
            def __init__(self):
                self.calls = 0
                self.lock = Lock()

            async def create_payment(self, request):
                with self.lock:
                    self.calls += 1
                return PaymentProviderResult(
                    provider="paydunya",
                    status="pending",
                    provider_token=f"token-{request.transaction_id}",
                    provider_transaction_id=f"provider-{request.transaction_id}",
                    checkout_url=f"https://example.test/{request.transaction_id}",
                )

        provider = Provider()
        payload = MobileMoneyInitiateRequest(finance_item_ids=[fee_id])

        def initiate():
            db = self.Session()
            try:
                return asyncio.run(finance.initiate_mobile_money_payment(
                    payload, _request(), db, db.get(User, member_id)
                ))
            finally:
                db.close()

        with (
            patch.object(finance, "get_payment_provider", return_value=provider),
            patch.object(settings, "MOBILE_MONEY_ENABLED", True),
        ):
            results = self._parallel(initiate, initiate)
            self._assert_race_outcomes(results, success_count=2)
            self.assertEqual(provider.calls, 1)
            first_ids = {result[1]["transaction_id"] for result in results}
            self.assertEqual(len(first_ids), 1)
            first_id = next(iter(first_ids))
            db = self.Session()
            transaction = db.get(MobileMoneyTransaction, first_id)
            transaction.status = "failed"
            db.commit()
            db.close()
            retry = initiate()

        self.assertNotEqual(retry["transaction_id"], first_id)
        self.assertEqual(provider.calls, 2)
        db = self.Session()
        self.assertEqual(db.query(MobileMoneyTransaction).filter(
            MobileMoneyTransaction.member_id == member_id,
            MobileMoneyTransaction.status.in_(("created", "pending", "processing")),
        ).count(), 1)
        db.close()


if __name__ == "__main__":
    unittest.main()
