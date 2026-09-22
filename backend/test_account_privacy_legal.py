import json
import os
import unittest
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-pr2-account-privacy")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException, Request
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.deps import get_current_user, require_admin_or_team_leader
from app.api.routes import account, auth, legal
from app.core.security import create_access_token, hash_password
from app.db.database import Base
from app.models.account import AuthSession, LegalDocument
from app.models.audit import AuditLog
from app.models.post import Post
from app.models.role import Role, UserRole
from app.models.user import User
from app.schemas.account import (
    AccountDeletionCreate,
    AccountDeletionProcess,
    AccountDeletionRead,
    AccountDeletionUserRead,
    LegalAcceptanceCreate,
    LegalDocumentCreate,
    LegalDocumentPublish,
    LegalDocumentType,
    UserPreferenceUpdate,
)
from app.schemas.auth import LoginRequest, RefreshTokenRequest


class AccountPrivacyLegalBackendTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        cls.Session = sessionmaker(bind=cls.engine, autoflush=False, autocommit=False)

    def setUp(self):
        Base.metadata.drop_all(self.engine)
        Base.metadata.create_all(self.engine)
        self.db = self.Session()
        self.user = self._create_user("member@enactspace.test")
        self.other = self._create_user("other@enactspace.test")
        self.admin = self._create_user("admin@enactspace.test")
        admin_role = Role(name="administrateur")
        self.db.add(admin_role)
        self.db.flush()
        self.db.add(UserRole(user_id=self.admin.id, role_id=admin_role.id))
        self.db.commit()

    def tearDown(self):
        self.db.close()

    def _create_user(self, email):
        user = User(
            first_name="Test",
            last_name="Member",
            email=email,
            password_hash=hash_password("ValidPassword123!"),
            status="active",
            email_verified=True,
            is_active=True,
        )
        self.db.add(user)
        self.db.flush()
        return user

    def _create_legal(self, version="v1"):
        return legal.create_legal_document(
            LegalDocumentCreate(
                document_type="privacy_policy",
                version=version,
                title=f"Politique {version}",
                content="Contenu institutionnel à valider.",
            ),
            db=self.db,
            current_user=self.admin,
        )

    def _publish(self, document):
        return legal.publish_legal_document(
            str(document.id),
            LegalDocumentPublish(),
            db=self.db,
            current_user=self.admin,
        )

    def test_preferences_get_patch_strict_enums_and_unauthorized(self):
        preference = account.get_preferences(db=self.db, current_user=self.user)
        self.assertEqual(preference.locale, "fr")
        updated = account.update_preferences(
            UserPreferenceUpdate(theme="dark", notification_email_enabled=False),
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(updated.theme, "dark")
        self.assertFalse(updated.notification_email_enabled)
        with self.assertRaises(ValidationError):
            UserPreferenceUpdate(theme="purple")
        with self.assertRaises(HTTPException) as unauthorized:
            get_current_user(token="invalid", db=self.db)
        self.assertEqual(unauthorized.exception.status_code, 401)

    def test_legal_versioning_publication_rbac_and_audit(self):
        with self.assertRaises(HTTPException) as forbidden:
            require_admin_or_team_leader(db=self.db, current_user=self.user)
        self.assertEqual(forbidden.exception.status_code, 403)
        first = self._create_legal("v1")
        self.assertEqual(legal.list_legal_documents(document_type=None, db=self.db), [])
        self._publish(first)
        second = self._create_legal("v2")
        self._publish(second)
        historical = legal.list_legal_documents(document_type=None, db=self.db)
        self.assertEqual(len(historical), 2)
        active = legal.get_active_legal_document(LegalDocumentType.privacy_policy, db=self.db)
        self.assertEqual(active.version, "v2")
        self.assertEqual(
            self.db.query(LegalDocument).filter(LegalDocument.is_active.is_(True)).count(),
            1,
        )
        with self.assertRaises(HTTPException) as duplicate:
            self._create_legal("v2")
        self.assertEqual(duplicate.exception.status_code, 409)
        actions = {row.action for row in self.db.query(AuditLog).all()}
        self.assertTrue({"legal_document_created", "legal_document_published"}.issubset(actions))

    def test_acceptance_exact_version_double_and_status(self):
        document = self._publish(self._create_legal("2026.1"))
        with self.assertRaises(HTTPException) as wrong:
            legal.accept_legal_document(
                LegalAcceptanceCreate(
                    legal_document_id=document.id,
                    version="wrong",
                    source="web",
                ),
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(wrong.exception.status_code, 404)
        accepted = legal.accept_legal_document(
            LegalAcceptanceCreate(
                legal_document_id=document.id,
                version="2026.1",
                source="web",
            ),
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(accepted.document_version, "2026.1")
        with self.assertRaises(HTTPException) as duplicate:
            legal.accept_legal_document(
                LegalAcceptanceCreate(
                    legal_document_id=document.id,
                    version="2026.1",
                    source="web",
                ),
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(duplicate.exception.status_code, 409)
        status_items = legal.get_my_legal_status(db=self.db, current_user=self.user)
        self.assertTrue(status_items[0].accepted)
        self.assertIn("legal_acceptance", {row.action for row in self.db.query(AuditLog).all()})

    def test_export_owned_structured_and_no_credentials(self):
        self.db.add(Post(author_id=self.user.id, title="Mine", content="my-private-content"))
        self.db.add(Post(author_id=self.other.id, title="Other", content="other-private-content"))
        self.db.commit()
        payload = account.export_my_data(db=self.db, current_user=self.user)
        rendered = json.dumps(payload, default=str).lower()
        self.assertEqual(payload["metadata"]["user_id"], str(self.user.id))
        self.assertEqual(payload["data"]["posts"][0]["content"], "my-private-content")
        self.assertNotIn("other-private-content", rendered)
        for secret_name in ("password_hash", "refresh_token", "access_token", "jwt", "secret_key"):
            self.assertNotIn(secret_name, rendered)
        actions = {row.action for row in self.db.query(AuditLog).all()}
        self.assertTrue({"data_export_requested", "data_export_generated"}.issubset(actions))

    def test_deletion_duplicate_cancel_and_no_physical_delete(self):
        created = account.request_account_deletion(
            AccountDeletionCreate(reason="Je souhaite fermer mon compte."),
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(created.status, "pending")
        with self.assertRaises(HTTPException) as duplicate:
            account.request_account_deletion(
                AccountDeletionCreate(), db=self.db, current_user=self.user
            )
        self.assertEqual(duplicate.exception.status_code, 409)
        cancelled = account.cancel_account_deletion(db=self.db, current_user=self.user)
        self.assertEqual(cancelled.status, "cancelled")
        self.assertIsNotNone(self.db.query(User).filter(User.id == self.user.id).first())
        actions = {row.action for row in self.db.query(AuditLog).all()}
        self.assertTrue({"account_deletion_requested", "account_deletion_cancelled"}.issubset(actions))

    def test_admin_processing_rbac_transitions_and_no_erasure(self):
        deletion = account.request_account_deletion(
            AccountDeletionCreate(), db=self.db, current_user=self.user
        )
        with self.assertRaises(HTTPException) as forbidden:
            require_admin_or_team_leader(db=self.db, current_user=self.user)
        self.assertEqual(forbidden.exception.status_code, 403)
        approved = account.process_account_deletion_request(
            str(deletion.id),
            AccountDeletionProcess(status="approved", admin_note="Identité contrôlée"),
            db=self.db,
            current_user=self.admin,
        )
        self.assertEqual(approved.status, "approved")
        user_view = AccountDeletionUserRead.model_validate(approved).model_dump()
        admin_view = AccountDeletionRead.model_validate(approved).model_dump()
        self.assertNotIn("admin_note", user_view)
        self.assertEqual(admin_view["admin_note"], "Identité contrôlée")
        completed = account.process_account_deletion_request(
            str(deletion.id),
            AccountDeletionProcess(status="completed"),
            db=self.db,
            current_user=self.admin,
        )
        self.assertEqual(completed.status, "completed")
        self.assertIsNotNone(self.db.query(User).filter(User.id == self.user.id).first())
        self.assertIn("account_deletion_processed", {row.action for row in self.db.query(AuditLog).all()})

    def test_migration_uses_project_guid_instead_of_char_uuid(self):
        migration = (
            Path(__file__).resolve().parent
            / "alembic"
            / "versions"
            / "20260902_0002_account_privacy_legal.py"
        ).read_text(encoding="utf-8")
        self.assertNotIn("sa.CHAR(36)", migration)
        self.assertIn("from app.db.types import GUID", migration)

    def test_login_refresh_rotation_sessions_and_replay_rejection(self):
        request = Request({"type": "http", "headers": [(b"user-agent", b"PR2 test")]})
        token_pair = auth.login(
            LoginRequest(
                email=self.user.email,
                password="ValidPassword123!",
                platform="web",
            ),
            request=request,
            db=self.db,
        )
        self.assertIsNotNone(token_pair.refresh_token)
        self.assertEqual(token_pair.expires_in, 1800)
        rotated = auth.refresh_access_token(
            RefreshTokenRequest(refresh_token=token_pair.refresh_token), db=self.db
        )
        self.assertNotEqual(rotated.refresh_token, token_pair.refresh_token)
        with self.assertRaises(HTTPException) as replay:
            auth.refresh_access_token(
                RefreshTokenRequest(refresh_token=token_pair.refresh_token), db=self.db
            )
        self.assertEqual(replay.exception.status_code, 401)
        current_user = get_current_user(token=rotated.access_token, db=self.db)
        sessions = auth.list_sessions(db=self.db, current_user=current_user)
        self.assertEqual(len(sessions), 1)
        auth.revoke_session(str(sessions[0].id), db=self.db, current_user=current_user)
        with self.assertRaises(HTTPException) as revoked:
            get_current_user(token=rotated.access_token, db=self.db)
        self.assertEqual(revoked.exception.status_code, 401)
        stored = self.db.query(AuthSession).one()
        self.assertNotEqual(stored.refresh_token_hash, token_pair.refresh_token)
        self.assertNotEqual(stored.refresh_token_hash, rotated.refresh_token)
        self.assertIn("session_revoked", {row.action for row in self.db.query(AuditLog).all()})

    def test_logout_all_revokes_refresh_and_audits(self):
        request = Request({"type": "http", "headers": []})
        pair = auth.login(
            LoginRequest(email=self.user.email, password="ValidPassword123!", platform="android"),
            request=request,
            db=self.db,
        )
        current_user = get_current_user(token=pair.access_token, db=self.db)
        result = auth.logout_all(db=self.db, current_user=current_user)
        self.assertEqual(result["revoked_sessions"], 1)
        with self.assertRaises(HTTPException):
            auth.refresh_access_token(RefreshTokenRequest(refresh_token=pair.refresh_token), db=self.db)
        self.assertIn("logout_all", {row.action for row in self.db.query(AuditLog).all()})


if __name__ == "__main__":
    unittest.main()
