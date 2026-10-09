"""Prelaunch regressions for token validation and untrusted file responses."""
import os
os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "isolated-prelaunch-secret")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch
from uuid import uuid4
from fastapi import Depends, FastAPI, HTTPException
from fastapi.testclient import TestClient
import jwt
from app.api.deps import get_current_user, require_admin_or_team_leader
from app.api.routes import files
from app.core.config import settings
from app.core.security import create_access_token, decode_access_token_payload
from app.db.database import get_db
from app.services.file_storage_service import file_path, is_storage_path_safe, store_bytes
import test_profile_photo as photo_fixture

class PrelaunchSecurityTests(unittest.TestCase):
    setUp = photo_fixture.ProfilePhotoTests.setUp
    tearDown = photo_fixture.ProfilePhotoTests.tearDown
    upload = photo_fixture.ProfilePhotoTests.upload

    def signed(self, **claims):
        payload = {"sub": str(self.user.id), "exp": datetime.now(timezone.utc) + timedelta(minutes=5)}
        payload.update(claims)
        return jwt.encode(payload, settings.signing_secret, algorithm=settings.ALGORITHM)

    def stored(self, mime="text/html", name="page.html", data=b"<script>alert(1)</script>"):
        row = store_bytes(self.db, data=data, original_filename=name, uploaded_by=self.user,
                          mime_type=mime, storage_scope="temporary", visibility="private")
        self.db.commit()
        return row

    def client(self):
        app=FastAPI()
        app.include_router(files.router, prefix="/api")
        app.dependency_overrides[get_db]=lambda:self.db
        @app.get("/identity")
        def identity(user=Depends(get_current_user)):
            return {"id":str(user.id)}
        @app.get("/admin")
        def admin(user=Depends(require_admin_or_team_leader)):
            return {"ok":True}
        return TestClient(app)

    def test_static_uploads_cannot_bypass_private_files_even_through_symlinks(self):
        from app.services.public_uploads import PublicUploadsStaticFiles
        media_root=self.root/"static"
        private=media_root/"files"/"recruitment"
        private.mkdir(parents=True)
        (private/"cv.pdf").write_bytes(b"test-only-private-file")
        (media_root/"banner.png").write_bytes(b"public-media")
        (media_root/"alias.pdf").symlink_to(private/"cv.pdf")
        app=FastAPI()
        app.mount("/uploads",PublicUploadsStaticFiles(directory=str(media_root)))
        with TestClient(app) as client:
            for path in ["/uploads/files/recruitment/cv.pdf", "/uploads/%66iles/recruitment/cv.pdf", "/uploads/alias.pdf"]:
                self.assertEqual(client.get(path).status_code,404)
            response=client.get("/uploads/banner.png")
            self.assertEqual(response.status_code,200)
            self.assertEqual(response.content,b"public-media")

    def test_malformed_file_identifiers_return_404_not_database_errors(self):
        with self.client() as client:
            headers={"Authorization":"Bearer "+self.signed()}
            for suffix in ["", "/download", "/preview", "/profile-photo"]:
                response=client.get("/api/files/not-a-uuid"+suffix,headers=headers)
                self.assertEqual(response.status_code,404)

    def test_unauthenticated_private_file_and_regular_member_admin_access_are_denied(self):
        row=self.stored()
        with self.client() as client:
            for suffix in ["", "/download", "/preview"]:
                self.assertEqual(client.get(f"/api/files/{row.id}{suffix}").status_code,401)
            self.assertEqual(client.get("/admin",headers={"Authorization":"Bearer "+self.signed()}).status_code,403)

    def test_other_member_cannot_read_private_file(self):
        from app.models.user import User
        other=User(first_name="Other",last_name="Tester",email="other@example.org",
                   password_hash="unused",status="active",is_active=True,email_verified=True)
        self.db.add(other);self.db.commit();row=self.stored()
        with self.client() as client:
            for suffix in ["", "/download", "/preview"]:
                self.assertEqual(client.get(f"/api/files/{row.id}{suffix}",
                    headers={"Authorization":"Bearer "+self.signed(sub=str(other.id))}).status_code,403)

    def test_alumni_legacy_secretary_role_cannot_read_other_private_file_or_cleanup(self):
        from app.models.user import User
        from app.models.role import Role, UserRole
        other=User(first_name="Former",last_name="Secretary",email="former@example.org",
                   password_hash="unused",status="alumni",profile_type="alumni",
                   is_active=True,email_verified=True)
        self.db.add(other);self.db.flush()
        role=Role(name="secretaire_generale");self.db.add(role);self.db.flush()
        self.db.add(UserRole(user_id=other.id,role_id=role.id));self.db.commit()
        row=self.stored()
        with self.client() as client:
            headers={"Authorization":"Bearer "+self.signed(sub=str(other.id))}
            self.assertEqual(client.get(f"/api/files/{row.id}/download",headers=headers).status_code,403)
            self.assertEqual(client.post("/api/files/cleanup",headers=headers).status_code,403)

    def test_html_and_svg_preview_force_attachment_and_restrict_execution(self):
        for mime,name in [("text/html","page.html"),("image/svg+xml","image.svg"),("application/xhtml+xml","page.xhtml")]:
            row=self.stored(mime,name)
            response=files.preview_file(str(row.id),db=self.db,current_user=self.user)
            self.assertEqual(response.media_type,"application/octet-stream")
            self.assertTrue(response.headers["content-disposition"].startswith("attachment;"))
            self.assertEqual(response.headers["x-content-type-options"],"nosniff")
            self.assertIn("sandbox",response.headers["content-security-policy"])

    def test_pdf_preview_remains_inline_with_safe_filename(self):
        row=self.stored("application/pdf",'rapport"final.pdf',b"%PDF-1.4\n")
        response=files.preview_file(str(row.id),db=self.db,current_user=self.user)
        self.assertTrue(response.headers["content-disposition"].startswith("inline;"))
        self.assertEqual(response.media_type,"application/pdf")
        self.assertEqual(response.headers["x-content-type-options"],"nosniff")

    def test_public_profile_route_rejects_script_capable_image_type(self):
        self.upload()
        from app.models.stored_file import StoredFile
        row=self.db.query(StoredFile).one();row.mime_type="image/svg+xml";self.db.commit()
        with self.assertRaises(HTTPException) as error:
            files.profile_photo(str(row.id),db=self.db)
        self.assertEqual(error.exception.status_code,404)

    def test_escaped_storage_path_never_reaches_file_response(self):
        row=self.stored()
        for malicious in ["../outside.txt",str(self.root.parent/"outside.txt"),"."]:
            row.storage_path=malicious
            self.assertFalse(is_storage_path_safe(row))
            with self.assertRaises(HTTPException) as error:file_path(row)
            self.assertEqual(error.exception.status_code,404)
            with self.assertRaises(HTTPException):
                files.download_file(str(row.id),db=self.db,current_user=self.user)

    def test_symlink_outside_storage_is_rejected(self):
        row=self.stored()
        outside=self.root.parent/("owned-security-test-"+uuid4().hex)
        outside.write_bytes(b"test-only")
        link=self.root/"escape"
        try:
            link.symlink_to(outside)
            row.storage_path="escape"
            with self.assertRaises(HTTPException):file_path(row)
        finally:
            link.unlink(missing_ok=True);outside.unlink(missing_ok=True)

    def test_missing_expiry_expired_tampered_and_malformed_tokens_are_rejected(self):
        no_exp=jwt.encode({"sub":str(self.user.id)},settings.signing_secret,algorithm=settings.ALGORITHM)
        expired=self.signed(exp=datetime.now(timezone.utc)-timedelta(seconds=10))
        wrong_key=jwt.encode({"sub":str(self.user.id),"exp":9999999999},"other-test-signing-key",algorithm=settings.ALGORITHM)
        for token in [no_exp,expired,wrong_key,"not-a-token"]:
            self.assertIsNone(decode_access_token_payload(token))

    def test_malformed_subject_and_session_identifiers_return_401_not_500(self):
        with self.client() as client:
            for claims in [{"sub":"invalid-uuid"},{"sid":"invalid-uuid"},{"sid":42}]:
                self.assertEqual(client.get("/identity",headers={"Authorization":"Bearer "+self.signed(**claims)}).status_code,401)

    def test_unknown_and_revoked_sessions_cannot_use_access_token(self):
        unknown=self.signed(sid=str(uuid4()))
        with self.assertRaises(HTTPException) as error:get_current_user(token=unknown,db=self.db)
        self.assertEqual(error.exception.status_code,401)
        from app.services.session_service import utc_now
        from app.models.account import AuthSession
        row=AuthSession(user_id=self.user.id,refresh_token_hash="test-only-hash",
                        expires_at=utc_now()+timedelta(minutes=5),revoked_at=utc_now())
        self.db.add(row);self.db.commit()
        with self.assertRaises(HTTPException) as error:get_current_user(token=self.signed(sid=str(row.id)),db=self.db)
        self.assertEqual(error.exception.status_code,401)

if __name__=="__main__":
    unittest.main()
