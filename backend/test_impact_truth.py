"""PR-2C impact truth, provenance, and aggregation regressions."""

import csv
import io
import os
import secrets
import unittest
from datetime import date, datetime, timedelta
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", secrets.token_urlsafe(48))
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.deps import require_enacchef_or_admin
from app.api.routes import archives as impact_archives
from app.api.routes import impact
from app.db.database import Base
from app.models.archive import HistoricalImpactStatistic
from app.models.document import Document
from app.models.impact import ImpactEvidence, ImpactMetric, ImpactProject
from app.models.project import Project
from app.models.stored_file import StoredFile
from app.models.task import Task
from app.models.user import User
from app.schemas.impact import (
    ImpactEvidenceCreate,
    ImpactMetricCreate,
    ImpactValidationRequest,
)
from app.schemas.archive import HistoricalImpactStatisticCreate


class ImpactTruthTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            poolclass=StaticPool,
            connect_args={"check_same_thread": False},
        )
        Base.metadata.create_all(self.engine)
        self.db = sessionmaker(bind=self.engine, autoflush=False)()
        self.user = User(
            first_name="Impact",
            last_name="Reviewer",
            email=f"{secrets.token_hex(12)}@example.test",
            password_hash="not-used",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.project = Project(
            name="Terrasen",
            description="Description explicite",
            status="completed",
            budget_estimated=100,
        )
        self.db.add_all([self.user, self.project])
        self.db.flush()

    def tearDown(self):
        self.db.rollback()
        self.db.close()
        self.engine.dispose()

    def impact_project(self, **values):
        record = ImpactProject(
            project_id=self.project.id,
            title="Fiche impact",
            created_by_id=self.user.id,
            **values,
        )
        self.db.add(record)
        self.db.flush()
        return record

    def claim(self, record, **values):
        defaults = {
            "impact_project_id": record.id,
            "semantic_key": "direct_beneficiaries",
            "title": "Beneficiaires directs",
            "unit": "personnes",
            "category": "social",
            "claim_type": "MEASURED",
            "validation_status": "VERIFIED",
            "status": "validated",
            "created_by_id": self.user.id,
            "validated_by_id": self.user.id,
            "validated_at": datetime.utcnow(),
        }
        defaults.update(values)
        metric = ImpactMetric(**defaults)
        self.db.add(metric)
        self.db.flush()
        return metric

    def test_project_without_claims_has_unknown_impact_despite_operations_and_name(self):
        self.db.add_all(
            [
                Task(title="Done", project_id=self.project.id, status="completed"),
                Document(
                    title="Official document",
                    file_url="internal/test.pdf",
                    project_id=self.project.id,
                    is_official=True,
                ),
            ]
        )
        self.db.flush()

        payload = impact._project_payload(self.db, self.project)

        for field in (*impact.REALIZED_FIELDS, "planet_impact"):
            self.assertIsNone(payload[field], field)
        self.assertEqual(payload["evidence_count"], 0)
        self.assertEqual(payload["sdgs"], [])
        self.assertIsNone(payload["methodology"])
        self.assertIsNone(payload["competition_readiness_score"])
        self.assertEqual(payload["completed_tasks"], 1)
        self.assertEqual(payload["documents_count"], 1)

    def test_realized_rule_excludes_every_non_measured_or_non_verified_claim(self):
        record = self.impact_project()
        older = datetime.utcnow() - timedelta(days=1)
        self.claim(record, value=12, created_at=older, validated_at=older)
        self.claim(record, value=25)
        for claim_type in ("ESTIMATE", "PROJECTION", "HISTORICAL_CLAIM"):
            self.claim(
                record,
                semantic_key="direct_beneficiaries",
                value=500,
                claim_type=claim_type,
            )
        for validation_status in (
            "DRAFT",
            "EVIDENCE_PENDING",
            "EVIDENCE_ATTACHED",
            "UNDER_REVIEW",
            "REJECTED",
            "SUPERSEDED",
        ):
            self.claim(
                record,
                semantic_key="direct_beneficiaries",
                value=700,
                validation_status=validation_status,
                status="draft",
            )

        payload = impact._project_payload(self.db, self.project)
        summary = impact.get_impact_summary(db=self.db, current_user=self.user)

        self.assertEqual(payload["direct_impact"], 25)
        self.assertEqual(summary["organization"]["direct_impact_total"], 25)
        self.assertIsNone(summary["historical_impact"])
        self.assertEqual(summary["claim_overview"]["by_claim_type"]["PROJECTION"], 1)

    def test_replacement_preserves_old_truth_through_review_and_rejection(self):
        record = self.impact_project()
        old = self.claim(record, value=10, source_reference="OLD-REF")
        replacement = impact.create_impact_metric(
            record.id,
            ImpactMetricCreate(
                semantic_key="direct_beneficiaries",
                title="Replacement",
                value=20,
                claim_type="MEASURED",
                source_reference="NEW-REF",
                supersedes_metric_id=old.id,
            ),
            db=self.db,
            current_user=self.user,
        )

        self.db.refresh(old)
        self.assertEqual(old.validation_status, "VERIFIED")
        self.assertEqual(
            impact._project_payload(self.db, self.project)["direct_impact"],
            10,
        )

        replacement.validation_status = "UNDER_REVIEW"
        replacement.status = "under_review"
        self.db.commit()
        self.assertEqual(
            impact._project_payload(self.db, self.project)["direct_impact"],
            10,
        )

        impact.reject_impact_metric(
            replacement.id,
            ImpactValidationRequest(reason="Mesure a reprendre"),
            db=self.db,
            current_user=self.user,
        )
        self.db.refresh(old)
        self.assertEqual(old.validation_status, "VERIFIED")
        self.assertEqual(
            impact._project_payload(self.db, self.project)["direct_impact"],
            10,
        )

        realized = impact._canonical_realized_claims([old, replacement])

        self.assertEqual([metric.id for metric in realized], [old.id])
        self.assertEqual(impact._realized_value(realized, "direct_beneficiaries"), 10)

        later_replacement = impact.create_impact_metric(
            record.id,
            ImpactMetricCreate(
                semantic_key="direct_beneficiaries",
                title="Later replacement",
                value=20,
                claim_type="MEASURED",
                source_reference="LATER-REF",
                supersedes_metric_id=old.id,
            ),
            db=self.db,
            current_user=self.user,
        )
        self.db.refresh(old)
        self.db.refresh(replacement)
        self.assertEqual(old.validation_status, "VERIFIED")
        self.assertEqual(replacement.validation_status, "REJECTED")
        self.assertEqual(
            impact._project_payload(self.db, self.project)["direct_impact"],
            10,
        )

        impact.validate_impact_metric(
            later_replacement.id,
            db=self.db,
            current_user=self.user,
        )
        self.db.refresh(old)
        self.db.refresh(replacement)
        self.db.refresh(later_replacement)
        self.assertEqual(old.validation_status, "SUPERSEDED")
        self.assertEqual(replacement.validation_status, "REJECTED")
        self.assertEqual(later_replacement.validation_status, "VERIFIED")
        self.assertEqual(
            impact._project_payload(self.db, self.project)["direct_impact"],
            20,
        )
        with self.assertRaises(HTTPException) as failure:
            impact.create_impact_metric(
                record.id,
                ImpactMetricCreate(
                    semantic_key="direct_beneficiaries",
                    title="Competing direct replacement",
                    value=30,
                    claim_type="MEASURED",
                    source_reference="COMPETING-REF",
                    supersedes_metric_id=old.id,
                ),
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(failure.exception.status_code, 409)

    def test_active_replacement_blocks_another_candidate(self):
        record = self.impact_project()
        for replacement_status in ("DRAFT", "UNDER_REVIEW"):
            with self.subTest(replacement_status=replacement_status):
                semantic_key = f"active_{replacement_status.lower()}"
                old = self.claim(
                    record,
                    semantic_key=semantic_key,
                    value=10,
                    source_reference="OLD-REF",
                )
                active = impact.create_impact_metric(
                    record.id,
                    ImpactMetricCreate(
                        semantic_key=semantic_key,
                        title="Active replacement",
                        value=20,
                        claim_type="MEASURED",
                        source_reference="ACTIVE-REF",
                        supersedes_metric_id=old.id,
                    ),
                    db=self.db,
                    current_user=self.user,
                )
                if replacement_status == "UNDER_REVIEW":
                    active.validation_status = "UNDER_REVIEW"
                    active.status = "under_review"
                    self.db.commit()

                with self.assertRaises(HTTPException) as failure:
                    impact.create_impact_metric(
                        record.id,
                        ImpactMetricCreate(
                            semantic_key=semantic_key,
                            title="Competing replacement",
                            value=30,
                            claim_type="MEASURED",
                            source_reference="COMPETING-REF",
                            supersedes_metric_id=old.id,
                        ),
                        db=self.db,
                        current_user=self.user,
                    )
                self.assertEqual(failure.exception.status_code, 409)
                self.db.refresh(old)
                self.assertEqual(old.validation_status, "VERIFIED")

    def test_verified_replacement_supersedes_old_truth_exactly_once(self):
        record = self.impact_project()
        old = self.claim(record, value=10, source_reference="OLD-REF")
        replacement = impact.create_impact_metric(
            record.id,
            ImpactMetricCreate(
                semantic_key="direct_beneficiaries",
                title="Replacement",
                value=20,
                claim_type="MEASURED",
                source_reference="NEW-REF",
                supersedes_metric_id=old.id,
            ),
            db=self.db,
            current_user=self.user,
        )

        impact.validate_impact_metric(
            replacement.id,
            db=self.db,
            current_user=self.user,
        )
        self.db.refresh(old)
        self.db.refresh(replacement)
        self.assertEqual(old.validation_status, "SUPERSEDED")
        self.assertEqual(replacement.validation_status, "VERIFIED")

        realized = impact._canonical_realized_claims([old, replacement])

        self.assertEqual([metric.id for metric in realized], [replacement.id])
        self.assertEqual(impact._realized_value(realized, "direct_beneficiaries"), 20)

    def test_overlapping_scopes_are_not_silently_summed(self):
        record = self.impact_project()
        old = datetime.utcnow() - timedelta(days=1)
        self.claim(
            record,
            value=30,
            population_scope="Site A",
            validated_at=old,
            created_at=old,
        )
        newest = self.claim(
            record,
            value=40,
            population_scope="Site A + Site B",
        )

        realized = impact._canonical_realized_claims(
            self.db.query(ImpactMetric).filter_by(impact_project_id=record.id).all()
        )

        self.assertEqual([claim.id for claim in realized], [newest.id])
        self.assertEqual(impact._realized_value(realized, "direct_beneficiaries"), 40)

    def test_unknown_and_explicit_verified_measured_zero_are_distinct(self):
        unknown = impact._project_payload(self.db, self.project)
        record = self.impact_project()
        self.claim(record, value=0)

        explicit_zero = impact._project_payload(self.db, self.project)

        self.assertIsNone(unknown["direct_impact"])
        self.assertEqual(explicit_zero["direct_impact"], 0)
        self.assertIsNone(explicit_zero["reach"])

    def test_evidence_attachment_does_not_validate_claim(self):
        record = self.impact_project()
        claim = self.claim(
            record,
            value=8,
            validation_status="EVIDENCE_ATTACHED",
            status="submitted",
        )
        self.db.add(
            ImpactEvidence(
                impact_project_id=record.id,
                metric_id=claim.id,
                title="Piece jointe",
                validation_status="EVIDENCE_ATTACHED",
                status="submitted",
                submitted_by_id=self.user.id,
            )
        )
        self.db.flush()

        payload = impact._project_payload(self.db, self.project)

        self.assertEqual(payload["evidence_count"], 1)
        self.assertEqual(payload["claims"][0]["evidence_count"], 1)
        self.assertEqual(payload["claims"][0]["validation_status"], "EVIDENCE_ATTACHED")
        self.assertIsNone(payload["direct_impact"])

    def test_period_and_provenance_contract(self):
        with self.assertRaises(ValidationError):
            ImpactMetricCreate(
                semantic_key="reach",
                title="Reach",
                period_start=date(2026, 2, 2),
                period_end=date(2026, 2, 1),
            )
        record = self.impact_project()
        claim = self.claim(
            record,
            value=3,
            period_start=date(2026, 1, 1),
            period_end=date(2026, 1, 31),
            population_scope="Site A",
            source="Enquete terrain",
            source_reference="REF-2026-01",
            methodology_note="Comptage nominatif deduplique",
            notes_limitations="Periode courte",
        )

        payload = impact._claim_payload(claim)

        self.assertEqual(payload["period_start"], date(2026, 1, 1))
        self.assertEqual(payload["population_scope"], "Site A")
        self.assertEqual(payload["source_reference"], "REF-2026-01")
        self.assertEqual(payload["notes_limitations"], "Periode courte")

    def test_final_validation_states_require_dedicated_actions(self):
        for state in ("VERIFIED", "REJECTED", "SUPERSEDED"):
            with self.subTest(state=state), self.assertRaises(HTTPException):
                impact._ensure_pending_validation({"validation_status": state})
        self.assertEqual(impact._semantic_key(" Direct_Beneficiaries "), "direct_beneficiaries")

    def test_evidence_defaults_to_attached_without_validating_claim(self):
        record = self.impact_project()
        evidence = impact.create_impact_evidence(
            record.id,
            ImpactEvidenceCreate(title="Photo terrain", status="submitted"),
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(evidence.validation_status, "EVIDENCE_ATTACHED")
        self.assertEqual(evidence.status, "submitted")

    def test_unverified_evidence_does_not_satisfy_verified_evidence_count(self):
        record = self.impact_project()
        self.db.add_all(
            [
                ImpactEvidence(
                    impact_project_id=record.id,
                    title="Draft",
                    validation_status="DRAFT",
                    status="draft",
                ),
                ImpactEvidence(
                    impact_project_id=record.id,
                    title="Rejected",
                    validation_status="REJECTED",
                    status="rejected",
                ),
            ]
        )
        self.db.flush()

        payload = impact._project_payload(self.db, self.project)
        report = impact.get_impact_report_summary(
            db=self.db,
            current_user=self.user,
        )

        self.assertEqual(payload["evidence_count"], 2)
        self.assertEqual(payload["verified_evidence_count"], 0)
        self.assertIn(
            "Ajouter des preuves validees",
            report["projects"][0]["improvement_points"],
        )

    def test_claim_verification_requires_structured_provenance_anchor(self):
        record = self.impact_project()
        without_anchor = self.claim(
            record,
            semantic_key="without_anchor",
            value=100,
            validation_status="DRAFT",
            status="draft",
            validated_by_id=None,
            validated_at=None,
        )
        with self.assertRaises(HTTPException) as failure:
            impact.validate_impact_metric(
                without_anchor.id,
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(failure.exception.status_code, 400)
        self.assertEqual(without_anchor.validation_status, "DRAFT")

        with_reference = self.claim(
            record,
            semantic_key="with_reference",
            value=101,
            validation_status="DRAFT",
            status="draft",
            source_reference="FIELD-101",
            validated_by_id=None,
            validated_at=None,
        )
        impact.validate_impact_metric(
            with_reference.id,
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(with_reference.validation_status, "VERIFIED")

        with_evidence = self.claim(
            record,
            semantic_key="with_evidence",
            value=102,
            validation_status="DRAFT",
            status="draft",
            validated_by_id=None,
            validated_at=None,
        )
        self.db.add(
            ImpactEvidence(
                impact_project_id=record.id,
                metric_id=with_evidence.id,
                title="Trace",
                validation_status="EVIDENCE_ATTACHED",
                status="submitted",
            )
        )
        self.db.commit()
        impact.validate_impact_metric(
            with_evidence.id,
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(with_evidence.validation_status, "VERIFIED")

    def test_historical_statistic_validation_requires_and_displays_provenance(self):
        with self.assertRaises(HTTPException) as failure:
            impact_archives.create_historical_impact_statistic(
                HistoricalImpactStatisticCreate(
                    metric_key="no_source",
                    label="No source",
                    value=12,
                    status="validated",
                ),
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(failure.exception.status_code, 400)

        sourced = impact_archives.create_historical_impact_statistic(
            HistoricalImpactStatisticCreate(
                metric_key="sourced",
                label="Sourced",
                value=13,
                source_label="Archive REF-13",
                status="validated",
            ),
            db=self.db,
            current_user=self.user,
        )
        invalid_legacy = HistoricalImpactStatistic(
            metric_key="legacy_without_source",
            label="Legacy",
            value=14,
            status="validated",
        )
        self.db.add(invalid_legacy)
        self.db.commit()

        summary = impact_archives.get_historical_impact_summary(
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(summary["sourced"], 13)
        self.assertNotIn("legacy_without_source", summary)
        self.assertEqual(
            impact_archives._historical_statistic_payload(invalid_legacy)["status"],
            "submitted",
        )
        self.assertEqual(sourced["validated_by_id"], self.user.id)

    def test_foreign_file_cannot_be_attached_as_evidence(self):
        record = self.impact_project()
        other = User(
            first_name="Other",
            last_name="Owner",
            email=f"{secrets.token_hex(12)}@example.test",
            password_hash="not-used",
            status="active",
        )
        self.db.add(other)
        self.db.flush()
        stored_file = StoredFile(
            original_filename="evidence.pdf",
            stored_filename="stored.pdf",
            file_size=1,
            storage_path="impact/stored.pdf",
            uploaded_by_id=other.id,
        )
        self.db.add(stored_file)
        self.db.flush()

        with self.assertRaises(HTTPException) as failure:
            impact.create_impact_evidence(
                record.id,
                ImpactEvidenceCreate(title="Foreign", file_id=stored_file.id),
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(failure.exception.status_code, 403)

    def test_csv_keeps_unknown_blank_and_exports_claim_classification(self):
        rows_without_claim = impact._impact_export_rows(
            [impact._project_payload(self.db, self.project)]
        )
        buffer = io.StringIO()
        csv.writer(buffer).writerows(rows_without_claim)
        parsed = list(csv.reader(io.StringIO(buffer.getvalue())))
        value_index = parsed[0].index("Valeur")
        self.assertEqual(parsed[1][value_index], "")

        record = self.impact_project()
        self.claim(
            record,
            value=0,
            claim_type="ESTIMATE",
            validation_status="UNDER_REVIEW",
            status="under_review",
            source_reference="SOURCE-1",
        )
        rows = impact._impact_export_rows([impact._project_payload(self.db, self.project)])
        header, row = rows
        self.assertEqual(row[header.index("Valeur")], 0)
        self.assertEqual(row[header.index("Type de declaration")], "ESTIMATE")
        self.assertEqual(row[header.index("Statut de validation")], "UNDER_REVIEW")
        self.assertEqual(row[header.index("Reference source")], "SOURCE-1")

    def test_parent_validation_does_not_verify_child_claim_and_rejection_keeps_reason(self):
        record = self.impact_project()
        claim = self.claim(
            record,
            value=9,
            validation_status="DRAFT",
            status="draft",
            validated_by_id=None,
            validated_at=None,
        )
        impact.validate_impact_record(record.id, db=self.db, current_user=self.user)
        self.db.refresh(claim)
        self.assertEqual(record.validation_status, "VERIFIED")
        self.assertEqual(claim.validation_status, "DRAFT")

        impact.reject_impact_metric(
            claim.id,
            ImpactValidationRequest(reason="Source insuffisante"),
            db=self.db,
            current_user=self.user,
        )
        self.assertEqual(claim.validation_status, "REJECTED")
        self.assertEqual(claim.rejection_reason, "Source insuffisante")

    def test_project_routes_keep_existing_rbac_dependency(self):
        project_routes = [
            route
            for route in impact.router.routes
            if getattr(route, "path", None) in {"/impact/projects", "/impact/summary"}
        ]
        self.assertEqual(len(project_routes), 2)
        for route in project_routes:
            dependencies = {dependency.call for dependency in route.dependant.dependencies}
            self.assertIn(require_enacchef_or_admin, dependencies)

    def test_runtime_path_has_no_hard_coded_historical_or_name_fallback(self):
        source = Path(impact.__file__).read_text(encoding="utf-8").lower()
        self.assertNotIn("historical_impact =", source)
        self.assertNotIn("_is_terrasen", source)
        self.assertNotIn('"terrasen" in', source)
        archives = Path("app/api/routes/archives.py").read_text(encoding="utf-8").lower()
        projects_ui = Path(
            "../frontend/lib/features/projects/screens/projects_screen.dart"
        ).read_text(encoding="utf-8").lower()
        self.assertNotIn("default_historical_impact_summary", archives)
        self.assertNotIn("_isterrasenproject", projects_ui)
        self.assertNotIn("préremplir terrasen", projects_ui)


if __name__ == "__main__":
    unittest.main()
