"""PR-2C acceptance tests against an isolated local PostgreSQL 16 schema."""

import os
import secrets
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime
from threading import Barrier
from unittest.mock import patch

from fastapi import HTTPException
from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

import app.models.base  # noqa: F401
from app.api.routes import impact
from app.core.config import settings
from app.models.impact import ImpactEvidence, ImpactMetric, ImpactProject
from app.models.project import Project
from app.models.user import User
from app.schemas.impact import ImpactMetricCreate, ImpactValidationRequest


class IsolatedPostgreSQLSchema(unittest.TestCase):
    schema_prefix = "pr2c_"

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
            raise RuntimeError("Refusing a non-local or non-PR-2B test database")
        cls.schema = cls.schema_prefix + secrets.token_hex(12)
        cls.admin_engine = create_engine(url, connect_args={"connect_timeout": 5})
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA "{cls.schema}"'))
        cls.addClassCleanup(cls._cleanup_schema)
        isolated = url.update_query_dict({"options": f"-csearch_path={cls.schema}"})
        cls.isolated_url = isolated.render_as_string(hide_password=False)
        cls.engine = create_engine(isolated, connect_args={"connect_timeout": 5})
        cls.addClassCleanup(cls.engine.dispose)
        cls.Session = sessionmaker(bind=cls.engine, autoflush=False)
        cls.config = Config("alembic.ini")
        cls.heads = ScriptDirectory.from_config(cls.config).get_heads()
        if len(cls.heads) != 1:
            raise AssertionError(f"Expected one Alembic head, got {cls.heads}")

    @classmethod
    def migrate(cls, revision):
        with patch.object(settings, "DATABASE_URL", cls.isolated_url):
            command.upgrade(cls.config, revision)

    @classmethod
    def _cleanup_schema(cls):
        if (
            not cls.schema.startswith(cls.schema_prefix)
            or len(cls.schema) != len(cls.schema_prefix) + 24
        ):
            raise RuntimeError("Unsafe PR-2C test schema cleanup target")
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{cls.schema}" CASCADE'))
        cls.admin_engine.dispose()


class PostgreSQLImpactTruthTests(IsolatedPostgreSQLSchema):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.migrate("head")
        with cls.engine.connect() as connection:
            version = connection.execute(text("SELECT version_num FROM alembic_version"))
            if version.scalar_one() != cls.heads[0]:
                raise AssertionError("Fresh PostgreSQL migration did not reach head")

    def setUp(self):
        self.db = self.Session()
        self.user = User(
            first_name="Postgres",
            last_name="Impact",
            email=f"{secrets.token_hex(12)}@example.test",
            password_hash="not-used",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.project = Project(name=f"Project {secrets.token_hex(4)}")
        self.db.add_all([self.user, self.project])
        self.db.flush()
        self.record = ImpactProject(
            project_id=self.project.id,
            title="PostgreSQL truth",
            created_by_id=self.user.id,
        )
        self.db.add(self.record)
        self.db.commit()

    def tearDown(self):
        self.db.rollback()
        self.db.close()

    def add_claim(self, **values):
        defaults = {
            "impact_project_id": self.record.id,
            "semantic_key": "direct_beneficiaries",
            "title": "Direct",
            "category": "social",
            "unit": "personnes",
            "claim_type": "MEASURED",
            "validation_status": "VERIFIED",
            "status": "validated",
            "created_by_id": self.user.id,
        }
        defaults.update(values)
        claim = ImpactMetric(**defaults)
        self.db.add(claim)
        self.db.flush()
        return claim

    def test_postgresql_constraints_and_provenance_foreign_keys(self):
        inspector = inspect(self.engine)
        metric_checks = {
            item["name"] for item in inspector.get_check_constraints("impact_metrics")
        }
        self.assertTrue(
            {
                "ck_impact_metric_claim_type",
                "ck_impact_metric_validation_status",
                "ck_impact_metric_period",
                "ck_impact_metric_semantic_key",
            }.issubset(metric_checks)
        )
        active_replacement_index = self.db.execute(
            text(
                "SELECT indexdef FROM pg_indexes "
                "WHERE schemaname = current_schema() "
                "AND tablename = 'impact_metrics' "
                "AND indexname = 'uq_impact_metric_active_supersedes'"
            )
        ).scalar_one()
        self.assertIn("CREATE UNIQUE INDEX", active_replacement_index)
        for active_status in impact.ACTIVE_REPLACEMENT_STATUSES:
            self.assertIn(active_status, active_replacement_index)
        self.assertNotIn("REJECTED", active_replacement_index)
        self.assertNotIn("SUPERSEDED", active_replacement_index)

        for invalid in (
            {"claim_type": "FACT"},
            {"validation_status": "VALIDATED"},
            {"period_start": date(2026, 2, 2), "period_end": date(2026, 2, 1)},
            {"semantic_key": " "},
        ):
            with self.subTest(invalid=invalid):
                self.db.add(
                    ImpactMetric(
                        impact_project_id=self.record.id,
                        semantic_key=invalid.get("semantic_key", "invalid"),
                        title="Invalid",
                        category="social",
                        unit="personnes",
                        claim_type=invalid.get("claim_type", "MEASURED"),
                        validation_status=invalid.get("validation_status", "DRAFT"),
                        period_start=invalid.get("period_start"),
                        period_end=invalid.get("period_end"),
                        status="draft",
                    )
                )
                with self.assertRaises((IntegrityError, TypeError)):
                    self.db.flush()
                self.db.rollback()

        claim = self.add_claim(value=0)
        self.db.add(
            ImpactEvidence(
                impact_project_id=self.record.id,
                metric_id=claim.id,
                title="Evidence",
                validation_status="EVIDENCE_ATTACHED",
                status="submitted",
            )
        )
        self.db.commit()
        self.assertEqual(self.db.get(ImpactMetric, claim.id).value, 0)
        self.assertIsNone(self.db.get(ImpactProject, self.record.id).direct_beneficiaries)

        replacement = self.add_claim(value=1, supersedes_metric_id=claim.id)
        self.db.commit()
        self.db.add(
            ImpactMetric(
                impact_project_id=self.record.id,
                semantic_key="direct_beneficiaries",
                title="Duplicate replacement",
                category="social",
                unit="personnes",
                claim_type="MEASURED",
                validation_status="VERIFIED",
                status="validated",
                supersedes_metric_id=claim.id,
            )
        )
        with self.assertRaises(IntegrityError):
            self.db.flush()
        self.db.rollback()
        self.assertIsNotNone(self.db.get(ImpactMetric, replacement.id))

    def test_nullable_value_and_explicit_zero_are_distinct_on_postgresql(self):
        unknown = self.add_claim(semantic_key="unknown", value=None)
        zero = self.add_claim(semantic_key="zero", value=0)
        self.db.commit()
        values = self.db.execute(
            text(
                "SELECT semantic_key, value FROM impact_metrics "
                "WHERE id IN (:unknown_id, :zero_id) ORDER BY semantic_key"
            ),
            {"unknown_id": unknown.id, "zero_id": zero.id},
        ).all()
        self.assertEqual(values, [("unknown", None), ("zero", 0)])

    def test_concurrent_replacement_and_rejected_winner_allows_later_candidate(self):
        predecessor = self.add_claim(value=10, source_reference="OLD")
        self.db.commit()
        record_id = self.record.id
        predecessor_id = predecessor.id
        user_id = self.user.id
        barrier = Barrier(2)

        def create_replacement(index: int):
            db = self.Session()
            try:
                user = db.get(User, user_id)
                barrier.wait(timeout=10)
                try:
                    created = impact.create_impact_metric(
                        record_id,
                        ImpactMetricCreate(
                            semantic_key="direct_beneficiaries",
                            title=f"Replacement {index}",
                            value=20 + index,
                            claim_type="MEASURED",
                            source_reference=f"REF-{index}",
                            supersedes_metric_id=predecessor_id,
                        ),
                        db=db,
                        current_user=user,
                    )
                    return str(created.id)
                except HTTPException as failure:
                    db.rollback()
                    return failure.status_code
            finally:
                db.close()

        with ThreadPoolExecutor(max_workers=2) as executor:
            outcomes = list(executor.map(create_replacement, (1, 2)))

        self.assertEqual(sum(isinstance(item, str) for item in outcomes), 1)
        self.assertEqual(outcomes.count(409), 1)
        replacement_count = self.db.query(ImpactMetric).filter(
            ImpactMetric.supersedes_metric_id == predecessor_id
        ).count()
        self.assertEqual(replacement_count, 1)
        self.db.refresh(predecessor)
        self.assertEqual(predecessor.validation_status, "VERIFIED")

        winner_id = uuid.UUID(next(item for item in outcomes if isinstance(item, str)))
        rejected = impact.reject_impact_metric(
            winner_id,
            ImpactValidationRequest(reason="Proposition concurrente rejetee"),
            db=self.db,
            current_user=self.user,
        )
        later = impact.create_impact_metric(
            record_id,
            ImpactMetricCreate(
                semantic_key="direct_beneficiaries",
                title="Later replacement",
                value=30,
                claim_type="MEASURED",
                source_reference="LATER-REF",
                supersedes_metric_id=predecessor_id,
            ),
            db=self.db,
            current_user=self.user,
        )

        self.db.refresh(predecessor)
        self.db.refresh(rejected)
        self.assertEqual(predecessor.validation_status, "VERIFIED")
        self.assertEqual(rejected.validation_status, "REJECTED")
        self.assertEqual(later.validation_status, "DRAFT")
        replacements = self.db.query(ImpactMetric).filter(
            ImpactMetric.supersedes_metric_id == predecessor_id
        ).all()
        self.assertEqual(len(replacements), 2)
        self.assertEqual(
            sum(
                item.validation_status in impact.ACTIVE_REPLACEMENT_STATUSES
                for item in replacements
            ),
            1,
        )


class PostgreSQLLegacyImpactMigrationTests(IsolatedPostgreSQLSchema):
    schema_prefix = "pr2clegacy_"

    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.migrate("head")
        with patch.object(settings, "DATABASE_URL", cls.isolated_url):
            command.downgrade(cls.config, "20260902_0002")

    def test_representative_legacy_values_migrate_without_becoming_realized(self):
        user_id = uuid.uuid4()
        project_id = uuid.uuid4()
        impact_id = uuid.uuid4()
        user_claim_id = uuid.uuid4()
        now = datetime.utcnow()
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    """
                    INSERT INTO users (
                        id, first_name, last_name, email, profile_type,
                        password_hash, status, email_verified, is_active,
                        created_at, updated_at
                    ) VALUES (
                        :id, 'Legacy', 'Owner', :email, 'enacteur', 'unused',
                        'active', true, true, :now, :now
                    )
                    """
                ),
                {"id": user_id, "email": f"{secrets.token_hex(8)}@example.test", "now": now},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO projects (
                        id, name, budget_estimated, status, created_at, updated_at
                    ) VALUES (:id, 'Legacy project', 0, 'idee', :now, :now)
                    """
                ),
                {"id": project_id, "now": now},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO impact_projects (
                        id, project_id, title, direct_beneficiaries,
                        indirect_beneficiaries, reach, jobs_created,
                        lives_impacted, revenue_generated, profit_or_surplus,
                        cost_savings, trees_planted, waste_reduced, water_saved,
                        co2_reduced, sdgs, status, created_by_id, created_at,
                        updated_at
                    ) VALUES (
                        :id, :project_id, 'Legacy impact', 17, 0, 0, 0, 0,
                        0, 0, 0, 0, 0, 0, 0, '[]', 'validated', :user_id,
                        :now, :now
                    )
                    """
                ),
                {"id": impact_id, "project_id": project_id, "user_id": user_id, "now": now},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO impact_metrics (
                        id, impact_project_id, title, category, unit, value,
                        source, status, created_by_id, created_at, updated_at
                    ) VALUES (
                        :id, :impact_id, 'User historical claim', 'social',
                        'personnes', 99, 'legacy_impact_project', 'draft',
                        :user_id, :now, :now
                    )
                    """
                ),
                {
                    "id": user_claim_id,
                    "impact_id": impact_id,
                    "user_id": user_id,
                    "now": now,
                },
            )

        self.migrate("head")

        with self.engine.connect() as connection:
            record = connection.execute(
                text(
                    "SELECT direct_beneficiaries, indirect_beneficiaries, "
                    "validation_status FROM impact_projects WHERE id = :id"
                ),
                {"id": impact_id},
            ).one()
            claim = connection.execute(
                text(
                    "SELECT id, value, claim_type, validation_status, source, period_start "
                    "FROM impact_metrics WHERE impact_project_id = :id "
                    "AND semantic_key = 'direct_beneficiaries'"
                ),
                {"id": impact_id},
            ).one()
        self.assertEqual(record, (17, None, "VERIFIED"))
        self.assertEqual(
            claim[1:],
            (17, "HISTORICAL_CLAIM", "DRAFT", "legacy_impact_project", None),
        )
        generated_claim_id = claim[0]

        with patch.object(settings, "DATABASE_URL", self.isolated_url):
            command.downgrade(self.config, "20260902_0002")
        with self.engine.connect() as connection:
            aggregate_value = connection.execute(
                text(
                    "SELECT direct_beneficiaries FROM impact_projects WHERE id = :id"
                ),
                {"id": impact_id},
            ).scalar_one()
            surviving_ids = set(
                connection.execute(
                    text(
                        "SELECT id FROM impact_metrics WHERE id IN (:user_id, :generated_id)"
                    ),
                    {"user_id": user_claim_id, "generated_id": generated_claim_id},
                ).scalars()
            )
        self.assertEqual(aggregate_value, 17)
        self.assertEqual(surviving_ids, {user_claim_id})

        self.migrate("head")
        with self.engine.connect() as connection:
            regenerated_ids = set(
                connection.execute(
                    text(
                        "SELECT id FROM impact_metrics WHERE impact_project_id = :id "
                        "AND source = 'legacy_impact_project' "
                        "AND claim_type = 'HISTORICAL_CLAIM'"
                    ),
                    {"id": impact_id},
                ).scalars()
            )
        self.assertEqual(regenerated_ids, {user_claim_id, generated_claim_id})


if __name__ == "__main__":
    unittest.main()
