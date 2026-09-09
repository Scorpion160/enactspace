"""Focused PR-3 product-services backend regressions."""

import os
import inspect
import unittest
import uuid
from datetime import datetime, timedelta
from unittest.mock import patch

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "pr3-product-services-test-secret-at-least-32-characters")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.deps import require_admin_or_team_leader
from app.api.routes import account, notifications
from app.api.routes import product_services as product
from app.core.config import settings
from app.db.database import Base, engine as application_engine
from app.models.account import UserPreference
from app.models.audit import AuditLog
from app.models.notification import Notification
from app.models.product_services import (
    AppInstallation,
    AppRelease,
    AppVersionPolicy,
    ProductFeedback,
    SupportTicket,
    SupportTicketMessage,
)
from app.models.role import Role, UserRole
from app.models.user import User
from app.schemas.account import UserPreferenceUpdate
from app.schemas.product_services import (
    AppReleaseCreate,
    AppReleaseUpdate,
    AppVersionPolicyUpdate,
    FeedbackCategory,
    ProductFeedbackAdminRead,
    ProductFeedbackCreate,
    ProductFeedbackManage,
    ProductFeedbackRead,
    ProductPlatform,
    SupportStatus,
    SupportTicketCreate,
    SupportTicketManage,
    SupportTicketMessageCreate,
)
from app.services.account_service import build_user_data_export
from app.services.notification_channels import _dispatch_email, _dispatch_push
from app.services.notification_service import create_notification, unread_count


class ProductServicesTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.db = self.Session()
        self.user = self._user("member")
        self.other = self._user("other")
        self.admin = self._user("admin")
        self.team_leader = self._user("leader")
        admin_role = Role(name="administrateur")
        leader_role = Role(name="team_leader")
        self.db.add_all([admin_role, leader_role])
        self.db.flush()
        self.db.add_all([
            UserRole(user_id=self.admin.id, role_id=admin_role.id),
            UserRole(user_id=self.team_leader.id, role_id=leader_role.id),
        ])
        self.db.commit()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def _user(self, label):
        user = User(
            first_name=label,
            last_name="PR3",
            email=f"{label}-{uuid.uuid4().hex}@example.test",
            password_hash="not-used",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(user)
        self.db.flush()
        return user

    def _release(self, version, build, platform="android"):
        store_url = {
            "android": (
                "https://play.google.com/store/apps/details"
                "?id=sn.enactusesp.enactspace"
            ),
            "ios": "https://apps.apple.com/sn/app/enactspace/id1234567890",
            "web": "https://www.enactspace.example/releases",
        }[platform]
        return product.create_app_release(
            AppReleaseCreate(
                platform=platform,
                version=version,
                build_number=build,
                store_url=store_url,
            ),
            db=self.db,
            current_user=self.admin,
        )

    def _publish(self, release):
        return product.publish_app_release(
            str(release.id), db=self.db, current_user=self.admin
        )

    def test_application_sqlite_engine_enforces_foreign_keys(self):
        with application_engine.connect() as connection:
            self.assertEqual(
                connection.execute(text("PRAGMA foreign_keys")).scalar_one(), 1
            )

    def test_installation_idempotency_ownership_revocation_and_privacy(self):
        key = uuid.uuid4()
        created = product.register_installation(
            product.InstallationUpsert(
                installation_key=key,
                platform="android",
                app_version="1.0.0",
                build_number=10,
            ),
            db=self.db,
            current_user=self.user,
        )
        refreshed = product.register_installation(
            product.InstallationUpsert(
                installation_key=key,
                platform="android",
                app_version="1.1.0",
                build_number=11,
                os_version="15",
                device_model="Generic model",
                locale="fr",
            ),
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(refreshed.id, created.id)
        self.assertEqual(refreshed.build_number, 11)
        self.assertEqual(self.db.query(AppInstallation).count(), 1)
        with self.assertRaises(HTTPException) as collision:
            product.register_installation(
                product.InstallationUpsert(installation_key=key, platform="android"),
                db=self.db,
                current_user=self.other,
            )
        self.assertEqual(collision.exception.status_code, 409)
        other_installation = product.register_installation(
            product.InstallationUpsert(installation_key=uuid.uuid4(), platform="web"),
            db=self.db,
            current_user=self.other,
        )
        self.assertEqual(
            [row.id for row in product.list_my_installations(
                db=self.db, current_user=self.user
            )],
            [created.id],
        )
        with self.assertRaises(HTTPException) as foreign_revoke:
            product.revoke_installation(
                str(other_installation.id), db=self.db, current_user=self.user
            )
        self.assertEqual(foreign_revoke.exception.status_code, 404)
        revoked = product.revoke_installation(
            str(created.id), db=self.db, current_user=self.user
        )
        self.assertIsNotNone(revoked.revoked_at)
        self.assertEqual(self.db.query(AppInstallation).count(), 2)
        forbidden_columns = {
            "push_token", "fcm_token", "apns_token", "imei", "android_id",
            "advertising_id", "serial_number", "mac_address", "phone_number",
            "location", "ip_address",
        }
        self.assertTrue(forbidden_columns.isdisjoint(AppInstallation.__table__.columns.keys()))

    def test_notification_preferences_control_all_future_channels(self):
        preference = account.get_preferences(db=self.db, current_user=self.user)
        self.assertFalse(preference.notification_push_enabled)
        historical = Notification(
            user_id=self.user.id,
            title="Historique",
            message="Visible avant changement",
            type="general",
        )
        self.db.add(historical)
        self.db.commit()
        preference = account.update_preferences(
            UserPreferenceUpdate(
                notification_in_app_enabled=False,
                notification_email_enabled=False,
                notification_push_enabled=False,
            ),
            db=self.db,
            current_user=self.user,
        )
        future = create_notification(
            self.db,
            user_id=self.user.id,
            title="Future",
            message="Supprimee du flux",
            dedupe=False,
        )
        self.db.commit()
        self.assertTrue(future.in_app_suppressed)
        self.assertEqual(unread_count(self.db, user_id=self.user.id), 1)
        visible = notifications.list_my_notifications(
            db=self.db, current_user=self.user, unread_only=None, type_filter=None
        )
        self.assertEqual([item.id for item in visible], [historical.id])
        self.assertEqual(self.db.query(Notification).count(), 2)

        original = (
            settings.EMAIL_ENABLED, settings.PUSH_ENABLED,
            settings.SMTP_HOST, settings.FCM_SERVER_KEY,
        )
        try:
            settings.EMAIL_ENABLED = True
            settings.PUSH_ENABLED = True
            settings.SMTP_HOST = "smtp.example.test"
            settings.FCM_SERVER_KEY = "configured-for-test"
            self.assertFalse(_dispatch_push(future, self.other, None))
            self.assertFalse(_dispatch_email(future, self.user, preference))
            self.assertFalse(_dispatch_push(future, self.user, preference))
            preference.notification_email_enabled = True
            preference.notification_push_enabled = True
            self.assertTrue(_dispatch_email(future, self.user, preference))
            self.assertTrue(_dispatch_push(future, self.user, preference))
            settings.EMAIL_ENABLED = False
            settings.PUSH_ENABLED = False
            self.assertFalse(_dispatch_email(future, self.user, preference))
            self.assertFalse(_dispatch_push(future, self.user, preference))
        finally:
            (
                settings.EMAIL_ENABLED, settings.PUSH_ENABLED,
                settings.SMTP_HOST, settings.FCM_SERVER_KEY,
            ) = original

    def test_support_ownership_messages_management_transitions_and_audit(self):
        ticket = product.create_support_ticket(
            SupportTicketCreate(
                subject="Connexion impossible",
                category="access",
                priority="high",
                message="Le compte reste bloque.",
            ),
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(self.db.query(SupportTicketMessage).count(), 1)
        self.assertEqual(
            [item.id for item in product.list_my_support_tickets(
                db=self.db, current_user=self.user
            )],
            [ticket.id],
        )
        self.assertEqual(
            product.list_my_support_tickets(db=self.db, current_user=self.other), []
        )
        for action in (
            lambda: product.get_my_support_ticket(
                str(ticket.id), db=self.db, current_user=self.other
            ),
            lambda: product.add_my_support_message(
                str(ticket.id), SupportTicketMessageCreate(message="Intrusion"),
                db=self.db, current_user=self.other,
            ),
        ):
            with self.assertRaises(HTTPException) as hidden:
                action()
            self.assertEqual(hidden.exception.status_code, 404)
        reply = product.add_my_support_message(
            str(ticket.id), SupportTicketMessageCreate(message="Precision"),
            db=self.db, current_user=self.user,
        )
        self.assertEqual(reply.author_id, self.user.id)
        self.assertEqual(
            [item.id for item in product.list_all_support_tickets(
                db=self.db, current_user=self.team_leader
            )],
            [ticket.id],
        )
        product.manage_support_ticket(
            str(ticket.id),
            SupportTicketManage(
                status="in_progress", assigned_to_id=self.team_leader.id
            ),
            db=self.db,
            current_user=self.team_leader,
        )
        product.manage_support_ticket(
            str(ticket.id), SupportTicketManage(status="closed"),
            db=self.db, current_user=self.admin,
        )
        with self.assertRaises(HTTPException) as closed_reply:
            product.add_my_support_message(
                str(ticket.id), SupportTicketMessageCreate(message="Encore"),
                db=self.db, current_user=self.user,
            )
        self.assertEqual(closed_reply.exception.status_code, 409)
        with self.assertRaises(HTTPException) as invalid_transition:
            product.manage_support_ticket(
                str(ticket.id), SupportTicketManage(status="resolved"),
                db=self.db, current_user=self.admin,
            )
        self.assertEqual(invalid_transition.exception.status_code, 409)
        management_reply = product.add_support_management_message(
            str(ticket.id), SupportTicketMessageCreate(message="Conclusion"),
            db=self.db, current_user=self.admin,
        )
        self.assertEqual(management_reply.author_id, self.admin.id)
        self.assertGreaterEqual(
            self.db.query(AuditLog).filter(
                AuditLog.action == "support_ticket_managed"
            ).count(),
            2,
        )

    def test_feedback_ownership_validation_and_management(self):
        with self.assertRaises(ValidationError):
            ProductFeedbackCreate(category="bug", message="Erreur", rating=6)
        with self.assertRaises(ValidationError):
            ProductFeedbackCreate(category="unknown", message="Erreur")
        feedback = product.create_product_feedback(
            ProductFeedbackCreate(
                category=FeedbackCategory.usability,
                message="Navigation difficile",
                rating=3,
                platform="ios",
                app_version="2.0.0",
                build_number=20,
            ),
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(
            [item.id for item in product.list_my_product_feedback(
                db=self.db, current_user=self.user
            )],
            [feedback.id],
        )
        with self.assertRaises(HTTPException) as hidden:
            product.get_my_product_feedback(
                str(feedback.id), db=self.db, current_user=self.other
            )
        self.assertEqual(hidden.exception.status_code, 404)
        self.assertEqual(
            [item.id for item in product.list_all_product_feedback(
                db=self.db, current_user=self.team_leader
            )],
            [feedback.id],
        )
        updated = product.manage_product_feedback(
            str(feedback.id),
            ProductFeedbackManage(status="planned", admin_note="Planifie"),
            db=self.db,
            current_user=self.admin,
        )
        self.assertEqual(updated.status, "planned")
        original = (updated.status, updated.admin_note, updated.updated_at)
        with self.assertRaises(HTTPException) as null_status:
            product.manage_product_feedback(
                str(feedback.id),
                ProductFeedbackManage(status=None),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(null_status.exception.status_code, 400)
        self.db.refresh(feedback)
        self.assertEqual(
            (feedback.status, feedback.admin_note, feedback.updated_at), original
        )
        note_only = product.manage_product_feedback(
            str(feedback.id),
            ProductFeedbackManage(admin_note="Note interne revisee"),
            db=self.db,
            current_user=self.team_leader,
        )
        self.assertEqual(note_only.status, "planned")
        self.assertEqual(note_only.admin_note, "Note interne revisee")
        user_response = ProductFeedbackRead.model_validate(note_only).model_dump()
        admin_response = ProductFeedbackAdminRead.model_validate(note_only).model_dump()
        self.assertNotIn("admin_note", user_response)
        self.assertEqual(admin_response["admin_note"], "Note interne revisee")
        with self.assertRaises(ValidationError):
            ProductFeedbackManage(status="invalid")
        with self.assertRaises(HTTPException) as forbidden:
            require_admin_or_team_leader(db=self.db, current_user=self.user)
        self.assertEqual(forbidden.exception.status_code, 403)

    def test_release_policy_build_semantics_and_audit(self):
        minimum = self._publish(self._release("1.0.0", 100))
        current = self._publish(self._release("2.0.0", 200))
        higher = self._publish(self._release("3.0.0", 300))
        with self.assertRaises(HTTPException) as duplicate:
            self._release("2.0.0", 200)
        self.assertEqual(duplicate.exception.status_code, 409)
        with self.assertRaises(HTTPException) as duplicate_build:
            self._release("2.0.1", 200)
        self.assertEqual(duplicate_build.exception.status_code, 409)
        ios_same_build = self._release("2.0.1", 200, platform="ios")
        self.assertEqual(ios_same_build.build_number, 200)
        with self.assertRaises(ValidationError):
            AppReleaseCreate(platform="android", version="1.0.0", build_number=0)
        with self.assertRaises(ValidationError):
            AppReleaseCreate(
                platform="android",
                version="1.0.0",
                build_number=1,
                store_url="http://127.0.0.1/private",
            )
        self.assertIsNotNone(current.published_at)
        with self.assertRaises(HTTPException) as minimum_too_high:
            product.update_app_version_policy(
                ProductPlatform.android,
                AppVersionPolicyUpdate(
                    current_release_id=current.id,
                    minimum_supported_release_id=higher.id,
                ),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(minimum_too_high.exception.status_code, 400)
        with self.assertRaises(HTTPException) as unknown_release:
            product.update_app_version_policy(
                ProductPlatform.android,
                AppVersionPolicyUpdate(current_release_id=uuid.uuid4()),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(unknown_release.exception.status_code, 400)
        ios = self._publish(self._release("1.0.0", 1, platform="ios"))
        with self.assertRaises(HTTPException) as mismatch:
            product.update_app_version_policy(
                ProductPlatform.android,
                AppVersionPolicyUpdate(current_release_id=ios.id),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(mismatch.exception.status_code, 400)
        policy = product.update_app_version_policy(
            ProductPlatform.android,
            AppVersionPolicyUpdate(
                current_release_id=current.id,
                minimum_supported_release_id=minimum.id,
            ),
            db=self.db,
            current_user=self.admin,
        )
        self.assertFalse(policy.force_update_to_current)
        current_client = product.product_bootstrap(
            ProductPlatform.android, "2.0.0", 200, db=self.db
        )
        supported_old = product.product_bootstrap(
            ProductPlatform.android, "1.5.0", 150, db=self.db
        )
        unsupported = product.product_bootstrap(
            ProductPlatform.android, "0.9.0", 50, db=self.db
        )
        self.assertFalse(current_client["update_available"])
        self.assertTrue(supported_old["update_available"])
        self.assertFalse(supported_old["force_update"])
        self.assertTrue(unsupported["update_required"])
        self.assertTrue(unsupported["force_update"])
        product.update_app_version_policy(
            ProductPlatform.android,
            AppVersionPolicyUpdate(force_update_to_current=True),
            db=self.db,
            current_user=self.team_leader,
        )
        self.assertTrue(product.product_bootstrap(
            ProductPlatform.android, "1.5.0", 150, db=self.db
        )["force_update"])
        self.assertGreaterEqual(self.db.query(AuditLog).count(), 5)

    def test_platform_store_urls_are_strict_and_updates_use_existing_platform(self):
        android = self._release("6.0.0", 600)
        self.assertEqual(
            android.store_url,
            "https://play.google.com/store/apps/details"
            "?id=sn.enactusesp.enactspace",
        )
        ios = self._release("6.0.0", 600, platform="ios")
        self.assertEqual(
            ios.store_url,
            "https://apps.apple.com/sn/app/enactspace/id1234567890",
        )
        web = self._release("6.0.0", 600, platform="web")
        self.assertEqual(web.store_url, "https://www.enactspace.example/releases")

        rejected = [
            (
                "android",
                "https://example.com/store/apps/details"
                "?id=sn.enactusesp.enactspace",
            ),
            (
                "android",
                "https://play.google.com/store/apps/details?id=wrong.package",
            ),
            (
                "android",
                "https://user@play.google.com/store/apps/details"
                "?id=sn.enactusesp.enactspace",
            ),
            (
                "android",
                "https://play.google.com/store/apps/details"
                "?id=sn.enactusesp.enactspace#fragment",
            ),
            ("ios", "https://example.com/sn/app/enactspace/id1234567890"),
            ("ios", "https://apps.apple.com/sn/app/enactspace/not-an-id"),
        ]
        for index, (platform, store_url) in enumerate(rejected, start=1):
            with self.subTest(platform=platform, store_url=store_url):
                with self.assertRaises((ValidationError, HTTPException)):
                    product.create_app_release(
                        AppReleaseCreate(
                            platform=platform,
                            version=f"7.0.{index}",
                            build_number=700 + index,
                            store_url=store_url,
                        ),
                        db=self.db,
                        current_user=self.admin,
                    )

        with self.assertRaises(ValidationError):
            AppReleaseCreate(
                platform="web",
                version="7.1.0",
                build_number=710,
                store_url="https://internal/releases",
            )
        with self.assertRaises(HTTPException):
            product.update_app_release(
                str(android.id),
                AppReleaseUpdate(
                    store_url="https://apps.apple.com/sn/app/enactspace/id1234567890"
                ),
                db=self.db,
                current_user=self.admin,
            )

    def test_force_capable_policies_require_current_store_destination(self):
        with self.assertRaises(HTTPException) as no_current:
            product.update_app_version_policy(
                ProductPlatform.ios,
                AppVersionPolicyUpdate(force_update_to_current=True),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(no_current.exception.status_code, 400)

        current_without_url = product.create_app_release(
            AppReleaseCreate(
                platform="android", version="8.0.0", build_number=800
            ),
            db=self.db,
            current_user=self.admin,
        )
        self._publish(current_without_url)
        non_force = product.update_app_version_policy(
            ProductPlatform.android,
            AppVersionPolicyUpdate(current_release_id=current_without_url.id),
            db=self.db,
            current_user=self.admin,
        )
        self.assertFalse(non_force.force_update_to_current)

        with self.assertRaises(HTTPException) as no_force_url:
            product.update_app_version_policy(
                ProductPlatform.android,
                AppVersionPolicyUpdate(force_update_to_current=True),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(no_force_url.exception.status_code, 400)

        minimum = self._publish(self._release("7.0.0", 700))
        with self.assertRaises(HTTPException) as no_minimum_url:
            product.update_app_version_policy(
                ProductPlatform.android,
                AppVersionPolicyUpdate(
                    minimum_supported_release_id=minimum.id,
                ),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(no_minimum_url.exception.status_code, 400)

        valid_current = self._publish(self._release("9.0.0", 900))
        policy = product.update_app_version_policy(
            ProductPlatform.android,
            AppVersionPolicyUpdate(
                current_release_id=valid_current.id,
                minimum_supported_release_id=minimum.id,
                force_update_to_current=True,
            ),
            db=self.db,
            current_user=self.admin,
        )
        self.assertTrue(policy.force_update_to_current)

        valid_current.store_url = None
        self.db.flush()
        with self.assertRaises(HTTPException) as idempotent_revalidation:
            product.update_app_version_policy(
                ProductPlatform.android,
                AppVersionPolicyUpdate(),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(idempotent_revalidation.exception.status_code, 400)

    def test_maintenance_windows_unconfigured_bootstrap_and_public_endpoint(self):
        with self.assertRaises(HTTPException) as invalid_window:
            product.update_app_version_policy(
                ProductPlatform.web,
                AppVersionPolicyUpdate(
                    maintenance_enabled=True,
                    maintenance_starts_at=datetime.utcnow(),
                ),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(invalid_window.exception.status_code, 400)
        unconfigured = product.product_bootstrap(
            ProductPlatform.web, "1.0.0", 1, db=self.db
        )
        self.assertFalse(unconfigured["configured"])
        immediate = product.update_app_version_policy(
            ProductPlatform.web,
            AppVersionPolicyUpdate(
                maintenance_enabled=True,
                maintenance_message="Maintenance planifiee",
            ),
            db=self.db,
            current_user=self.admin,
        )
        self.assertTrue(product.product_bootstrap(
            ProductPlatform.web, "1.0.0", 1, db=self.db
        )["maintenance"]["active"])
        product.update_app_version_policy(
            ProductPlatform.web,
            AppVersionPolicyUpdate(maintenance_enabled=False),
            db=self.db,
            current_user=self.admin,
        )
        self.assertFalse(product.product_bootstrap(
            ProductPlatform.web, "1.0.0", 1, db=self.db
        )["maintenance"]["active"])
        product.update_app_version_policy(
            ProductPlatform.web,
            AppVersionPolicyUpdate(maintenance_enabled=True),
            db=self.db,
            current_user=self.admin,
        )
        future_start = datetime.utcnow() + timedelta(days=1)
        future_end = future_start + timedelta(hours=1)
        product.update_app_version_policy(
            ProductPlatform.web,
            AppVersionPolicyUpdate(
                maintenance_starts_at=future_start,
                maintenance_ends_at=future_end,
            ),
            db=self.db,
            current_user=self.admin,
        )
        self.assertFalse(product.product_bootstrap(
            ProductPlatform.web, "1.0.0", 1, db=self.db
        )["maintenance"]["active"])
        expired_end = datetime.utcnow() - timedelta(hours=1)
        expired_start = expired_end - timedelta(hours=1)
        product.update_app_version_policy(
            ProductPlatform.web,
            AppVersionPolicyUpdate(
                maintenance_starts_at=expired_start,
                maintenance_ends_at=expired_end,
            ),
            db=self.db,
            current_user=self.admin,
        )
        self.assertFalse(product.product_bootstrap(
            ProductPlatform.web, "1.0.0", 1, db=self.db
        )["maintenance"]["active"])
        active_start = datetime.utcnow() - timedelta(hours=1)
        active_end = datetime.utcnow() + timedelta(hours=1)
        product.update_app_version_policy(
            ProductPlatform.web,
            AppVersionPolicyUpdate(
                maintenance_starts_at=active_start,
                maintenance_ends_at=active_end,
            ),
            db=self.db,
            current_user=self.admin,
        )
        decision = product.product_bootstrap(
            ProductPlatform.web, "1.0.0", 1, db=self.db
        )
        self.assertTrue(decision["maintenance"]["active"])
        forbidden_terms = {"database", "filesystem", "credential", "container", "secret"}
        self.assertTrue(forbidden_terms.isdisjoint(decision.keys()))

        self.assertNotIn(
            "current_user", inspect.signature(product.product_bootstrap).parameters
        )

    def test_release_withdrawal_and_policy_references_are_safe(self):
        release = self._release("4.0.0", 400)
        with self.assertRaises(HTTPException) as draft_policy:
            product.update_app_version_policy(
                ProductPlatform.android,
                AppVersionPolicyUpdate(current_release_id=release.id),
                db=self.db,
                current_user=self.admin,
            )
        self.assertEqual(draft_policy.exception.status_code, 409)
        self._publish(release)
        product.update_app_version_policy(
            ProductPlatform.android,
            AppVersionPolicyUpdate(current_release_id=release.id),
            db=self.db,
            current_user=self.admin,
        )
        with self.assertRaises(HTTPException) as referenced:
            product.withdraw_app_release(
                str(release.id), db=self.db, current_user=self.admin
            )
        self.assertEqual(referenced.exception.status_code, 409)
        product.update_app_version_policy(
            ProductPlatform.android,
            AppVersionPolicyUpdate(current_release_id=None),
            db=self.db,
            current_user=self.admin,
        )
        withdrawn = product.withdraw_app_release(
            str(release.id), db=self.db, current_user=self.admin
        )
        self.assertEqual(withdrawn.status, "withdrawn")
        actions = {row.action for row in self.db.query(AuditLog).all()}
        self.assertIn("app_release_published", actions)
        self.assertIn("app_release_withdrawn", actions)

    def test_account_export_includes_new_user_owned_records(self):
        account.get_preferences(db=self.db, current_user=self.user)
        product.register_installation(
            product.InstallationUpsert(
                installation_key=uuid.uuid4(), platform="android"
            ),
            db=self.db,
            current_user=self.user,
        )
        product.create_support_ticket(
            SupportTicketCreate(subject="Aide", message="Question"),
            db=self.db,
            current_user=self.user,
        )
        product.create_product_feedback(
            ProductFeedbackCreate(category="idea", message="Suggestion"),
            db=self.db,
            current_user=self.user,
        )
        exported = build_user_data_export(self.db, self.user, "test")
        self.assertEqual(len(exported["data"]["app_installations"]), 1)
        self.assertEqual(len(exported["data"]["support_tickets"]), 1)
        self.assertEqual(len(exported["data"]["support_messages_authored"]), 1)
        self.assertEqual(len(exported["data"]["product_feedback"]), 1)
        self.assertNotIn("admin_note", exported["data"]["product_feedback"][0])
        self.assertIn(
            "notification_push_enabled", exported["data"]["preferences"][0]
        )


if __name__ == "__main__":
    unittest.main()
