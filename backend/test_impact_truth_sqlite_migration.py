"""PR-2C Alembic acceptance against an isolated SQLite database."""

import tempfile
import unittest
import uuid
from datetime import datetime
from pathlib import Path
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.pool import NullPool

import app.models.base  # noqa: F401
from app.core.config import settings


class SQLiteImpactTruthMigrationTests(unittest.TestCase):
    def test_0002_0003_downgrade_and_reupgrade_preserve_truth_and_user_rows(self):
        with tempfile.TemporaryDirectory(prefix="pr2c_sqlite_") as directory:
            database_path = Path(directory) / "impact.sqlite3"
            database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
            config = Config("alembic.ini")
            heads = ScriptDirectory.from_config(config).get_heads()
            self.assertEqual(heads, ["20260913_0009"])

            def migrate(revision: str) -> None:
                with patch.object(settings, "DATABASE_URL", database_url):
                    command.upgrade(config, revision)

            def downgrade(revision: str) -> None:
                with patch.object(settings, "DATABASE_URL", database_url):
                    command.downgrade(config, revision)

            migrate("head")
            downgrade("20260902_0002")

            engine = create_engine(database_url, poolclass=NullPool)
            user_id = str(uuid.uuid4())
            project_id = str(uuid.uuid4())
            impact_id = str(uuid.uuid4())
            user_claim_id = str(uuid.uuid4())
            explicit_zero_id = str(uuid.uuid4())
            now = datetime.utcnow()
            with engine.begin() as connection:
                connection.execute(
                    text(
                        """
                        INSERT INTO users (
                            id, first_name, last_name, email, profile_type,
                            password_hash, status, email_verified, is_active,
                            created_at, updated_at
                        ) VALUES (
                            :id, 'SQLite', 'Owner', :email, 'enacteur', 'unused',
                            'active', 1, 1, :now, :now
                        )
                        """
                    ),
                    {
                        "id": user_id,
                        "email": f"{uuid.uuid4().hex}@example.test",
                        "now": now,
                    },
                )
                connection.execute(
                    text(
                        """
                        INSERT INTO projects (
                            id, name, budget_estimated, status, created_at, updated_at
                        ) VALUES (:id, 'SQLite legacy', 0, 'idee', :now, :now)
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
                            :id, :project_id, 'SQLite legacy impact', 17, 0, 0,
                            0, 0, 0, 0, 0, 0, 0, 0, 0, '[]', 'validated',
                            :user_id, :now, :now
                        )
                        """
                    ),
                    {
                        "id": impact_id,
                        "project_id": project_id,
                        "user_id": user_id,
                        "now": now,
                    },
                )
                connection.execute(
                    text(
                        """
                        INSERT INTO impact_metrics (
                            id, impact_project_id, title, category, unit, value,
                            source, status, created_by_id, created_at, updated_at
                        ) VALUES (
                            :id, :impact_id, 'User claim', 'social', 'personnes',
                            99, 'legacy_impact_project', 'draft', :user_id,
                            :now, :now
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

            migrate("head")
            with engine.begin() as connection:
                record = connection.execute(
                    text(
                        "SELECT direct_beneficiaries, indirect_beneficiaries "
                        "FROM impact_projects WHERE id = :id"
                    ),
                    {"id": impact_id},
                ).one()
                generated_claim_id = connection.execute(
                    text(
                        "SELECT id FROM impact_metrics "
                        "WHERE impact_project_id = :id "
                        "AND semantic_key = 'direct_beneficiaries'"
                    ),
                    {"id": impact_id},
                ).scalar_one()
                connection.execute(
                    text(
                        """
                        INSERT INTO impact_metrics (
                            id, impact_project_id, semantic_key, title, category,
                            unit, value, claim_type, validation_status,
                            source_reference, status, created_by_id, created_at,
                            updated_at
                        ) VALUES (
                            :id, :impact_id, 'explicit_zero', 'Explicit zero',
                            'social', 'personnes', 0, 'MEASURED', 'VERIFIED',
                            'ZERO-REF', 'validated', :user_id, :now, :now
                        )
                        """
                    ),
                    {
                        "id": explicit_zero_id,
                        "impact_id": impact_id,
                        "user_id": user_id,
                        "now": now,
                    },
                )
                explicit_zero = connection.execute(
                    text("SELECT value FROM impact_metrics WHERE id = :id"),
                    {"id": explicit_zero_id},
                ).scalar_one()
            self.assertEqual(record, (17, None))
            self.assertEqual(explicit_zero, 0)
            metric_checks = {
                item["name"]
                for item in inspect(engine).get_check_constraints("impact_metrics")
            }
            self.assertTrue(
                {
                    "ck_impact_metric_claim_type",
                    "ck_impact_metric_validation_status",
                    "ck_impact_metric_period",
                    "ck_impact_metric_semantic_key",
                }.issubset(metric_checks)
            )
            with engine.connect() as connection:
                active_replacement_index = connection.execute(
                    text(
                        "SELECT sql FROM sqlite_master "
                        "WHERE type = 'index' "
                        "AND name = 'uq_impact_metric_active_supersedes'"
                    )
                ).scalar_one()
            self.assertIn("WHERE supersedes_metric_id IS NOT NULL", active_replacement_index)
            for active_status in (
                "DRAFT",
                "EVIDENCE_PENDING",
                "EVIDENCE_ATTACHED",
                "UNDER_REVIEW",
                "VERIFIED",
            ):
                self.assertIn(f"'{active_status}'", active_replacement_index)
            self.assertNotIn("'REJECTED'", active_replacement_index)
            self.assertNotIn("'SUPERSEDED'", active_replacement_index)

            downgrade("20260902_0002")
            with engine.connect() as connection:
                aggregate_value = connection.execute(
                    text(
                        "SELECT direct_beneficiaries FROM impact_projects WHERE id = :id"
                    ),
                    {"id": impact_id},
                ).scalar_one()
                surviving_rows = connection.execute(
                    text(
                        "SELECT id FROM impact_metrics "
                        "WHERE id IN (:user_id, :generated_id, :zero_id)"
                    ),
                    {
                        "user_id": user_claim_id,
                        "generated_id": generated_claim_id,
                        "zero_id": explicit_zero_id,
                    },
                ).scalars()
                surviving_ids = {str(item) for item in surviving_rows}
            self.assertEqual(aggregate_value, 17)
            self.assertEqual(
                surviving_ids,
                {str(user_claim_id), str(explicit_zero_id)},
            )

            migrate("head")
            with engine.connect() as connection:
                regenerated_rows = connection.execute(
                    text(
                        "SELECT id FROM impact_metrics "
                        "WHERE impact_project_id = :id "
                        "AND source = 'legacy_impact_project' "
                        "AND claim_type = 'HISTORICAL_CLAIM'"
                    ),
                    {"id": impact_id},
                ).scalars()
                regenerated_ids = {str(item) for item in regenerated_rows}
                final_revision = connection.execute(
                    text("SELECT version_num FROM alembic_version")
                ).scalar_one()
                final_active_index_count = connection.execute(
                    text(
                        "SELECT count(*) FROM sqlite_master "
                        "WHERE type = 'index' "
                        "AND name = 'uq_impact_metric_active_supersedes'"
                    )
                ).scalar_one()
            self.assertEqual(
                regenerated_ids,
                {str(user_claim_id), str(generated_claim_id)},
            )
            self.assertEqual(final_revision, "20260913_0009")
            self.assertEqual(final_active_index_count, 1)
            engine.dispose()


if __name__ == "__main__":
    unittest.main()
