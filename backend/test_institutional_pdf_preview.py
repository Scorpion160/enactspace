import os
import shutil
import unittest
from datetime import date

os.environ.setdefault("DATABASE_URL", "sqlite:///institutional-pdf-preview-import.db")
os.environ.setdefault("SECRET_KEY", "unit-test-institutional-preview-secret")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.database import Base
import app.models.base  # noqa: F401
from app.models.institutional_document import InstitutionalDocumentRequest
from app.models.season import Season
from app.models.user import User
from app.services.institutional_pdf_preview_service import (
    DRAFT_REFERENCE,
    DRAFT_STATUS,
    build_preview_data_tex,
    compile_request_preview_pdf,
)


class InstitutionalPdfPreviewTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.db = self.Session()

        self.season = Season(
            name="2026-2027",
            start_date=date(2026, 9, 1),
            end_date=date(2027, 8, 31),
            is_current=True,
            archived=False,
        )
        self.author = User(
            first_name="Awa",
            last_name="Ndiaye",
            email="preview@example.com",
            phone="770000000",
            password_hash="not-used",
            status="active",
            email_verified=True,
            is_active=True,
        )
        self.db.add_all([self.season, self.author])
        self.db.flush()

        self.request = InstitutionalDocumentRequest(
            template_code="demande_bus",
            template_version="2.0",
            status="draft",
            payload_json={
                "recipient_organization": "École Supérieure Polytechnique",
                "recipient_name": "Cheffe des Services Administratifs",
                "trip_purpose": "mission terrain",
                "departure_at": "2026-10-10T08:00:00",
                "return_at": "2026-10-11T18:00:00",
                "passenger_count": 25,
                "route": [
                    {"from": "ESP", "to": "Thiès", "distance": 70},
                    {"from": "Thiès", "to": "ESP", "distance": 70},
                ],
            },
            requested_by=self.author.id,
            season_id=self.season.id,
            official_reference=None,
        )
        self.db.add(self.request)
        self.db.flush()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def test_preview_data_uses_draft_reference_and_restores_request(self):
        self.assertIsNone(self.request.official_reference)
        data_tex = build_preview_data_tex(self.db, self.request)
        self.assertIn(DRAFT_REFERENCE, data_tex)
        self.assertIn(
            rf"\renewcommand{{\DocStatus}}{{{DRAFT_STATUS}}}",
            data_tex,
        )
        self.assertNotIn(r"\renewcommand{\DocStatus}{OFFICIEL}", data_tex)
        self.assertIn(r"\EnableDraftWatermark", data_tex)
        self.assertIsNone(self.request.official_reference)
        self.assertIsNone(self.request.sequence_number)
        self.assertIsNone(self.request.generated_document_id)

    @unittest.skipUnless(shutil.which("pdflatex"), "pdflatex not installed")
    def test_draft_request_compiles_to_preview_without_officializing(self):
        pdf = compile_request_preview_pdf(self.db, self.request)
        self.assertTrue(pdf.startswith(b"%PDF-"))
        self.assertGreater(len(pdf), 1000)
        self.assertEqual(self.request.status, "draft")
        self.assertIsNone(self.request.official_reference)
        self.assertIsNone(self.request.sequence_number)
        self.assertIsNone(self.request.generated_document_id)


if __name__ == "__main__":
    unittest.main()
