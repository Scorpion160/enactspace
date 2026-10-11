"""Profile photo lifecycle and public-file access regressions."""

import asyncio
import base64
import io
import os
import secrets
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", secrets.token_urlsafe(48))
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException, UploadFile
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool
from starlette.datastructures import Headers

import app.models.base  # noqa: F401
from app.api.routes import files, users
from app.db.database import Base
from app.models.stored_file import StoredFile
from app.models.user import User

PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8"
    "/x8AAwMCAO+jRZkAAAAASUVORK5CYII="
)


class ProfilePhotoTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://", poolclass=StaticPool,
            connect_args={"check_same_thread": False},
        )
        Base.metadata.create_all(self.engine)
        self.db = sessionmaker(bind=self.engine, autoflush=False)()
        self.user = User(
            first_name="Photo", last_name="Tester",
            email=f"{secrets.token_hex(12)}@example.test",
            password_hash="not-used", status="active",
            is_active=True, email_verified=True,
        )
        self.db.add(self.user)
        self.db.commit()
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.storage_patch = patch(
            "app.services.file_storage_service.UPLOAD_ROOT", self.root
        )
        self.storage_patch.start()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()
        self.storage_patch.stop()
        self.temp.cleanup()

    def upload(self, data=PNG, filename="photo.png", mime="image/png"):
        upload = UploadFile(
            file=io.BytesIO(data), filename=filename,
            headers=Headers({"content-type": mime}),
        )
        return asyncio.run(users.upload_my_profile_photo(
            file=upload, db=self.db, current_user=self.user,
        ))

    def test_upload_replacement_and_deletion_remove_previous_files(self):
        self.upload()
        first = self.db.query(StoredFile).one()
        first_id = first.id
        first_path = self.root / first.storage_path
        self.assertEqual(first_path.read_bytes(), PNG)
        self.assertEqual(first.storage_scope, "profile")
        self.assertEqual(first.visibility, "public_club")
        self.assertEqual(
            self.user.photo_url, f"/api/files/{first_id}/profile-photo"
        )
        response = files.profile_photo(str(first_id), db=self.db)
        self.assertEqual(Path(response.path).read_bytes(), PNG)

        self.upload(filename="replacement.png")
        second = self.db.query(StoredFile).one()
        self.assertNotEqual(second.id, first_id)
        self.assertFalse(first_path.exists())
        second_path = self.root / second.storage_path
        self.assertTrue(second_path.exists())

        users.delete_my_profile_photo(db=self.db, current_user=self.user)
        self.assertIsNone(self.user.photo_url)
        self.assertEqual(self.db.query(StoredFile).count(), 0)
        self.assertFalse(second_path.exists())

    def test_public_photo_route_rejects_private_or_unrelated_files(self):
        self.upload()
        stored = self.db.query(StoredFile).one()
        for field, invalid in (
            ("visibility", "private"),
            ("storage_scope", "finance"),
            ("entity_type", "document"),
        ):
            with self.subTest(field=field):
                original = getattr(stored, field)
                setattr(stored, field, invalid)
                self.db.commit()
                with self.assertRaises(HTTPException) as error:
                    files.profile_photo(str(stored.id), db=self.db)
                self.assertEqual(error.exception.status_code, 404)
                setattr(stored, field, original)
                self.db.commit()

    def test_invalid_uploads_do_not_change_profile_or_create_files(self):
        for data, mime, expected in (
            (b"", "image/png", 400),
            (PNG, "application/pdf", 400),
            (b"x" * (users.PROFILE_PHOTO_MAX_BYTES + 1), "image/png", 413),
        ):
            with self.subTest(mime=mime, size=len(data)):
                with self.assertRaises(HTTPException) as error:
                    self.upload(data=data, mime=mime)
                self.assertEqual(error.exception.status_code, expected)
                self.assertIsNone(self.user.photo_url)
                self.assertEqual(self.db.query(StoredFile).count(), 0)


if __name__ == "__main__":
    unittest.main()
