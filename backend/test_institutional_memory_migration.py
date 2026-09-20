"""PR-2D Alembic acceptance against an isolated SQLite database."""

import os
import secrets
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.pool import NullPool

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", secrets.token_urlsafe(48))
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

import app.models.base  # noqa: F401
from app.core.config import settings


MEMORY_TABLES = {
    "institutional_sources",
    "institutional_territories",
    "institutional_generations",
    "institutional_canonical_projects",
    "institutional_leadership_terms",
    "institutional_project_aliases",
    "institutional_project_years",
    "institutional_project_relationships",
    "institutional_events",
    "institutional_frameworks",
    "institutional_competition_participations",
}
COMPETITION_COLUMNS = {
    "territory_id",
    "source_id",
    "validation_status",
    "created_by_id",
    "validated_by_id",
    "validated_at",
}
AWARD_COLUMNS = {
    "competition_record_id",
    "canonical_project_id",
    "source_id",
    "validation_status",
    "created_by_id",
    "validated_by_id",
    "validated_at",
}
MEMORY_EVENT_PROVENANCE_COLUMNS = {
    "origin",
    "capture_key",
    "source_entity_type",
    "source_entity_id",
    "source_entity_version",
    "captured_at",
    "operational_project_id",
    "pole_id",
    "operational_event_id",
}
MEMORY_EVENT_PROVENANCE_INDEXES = {
    "ix_memory_event_capture_key",
    "ix_memory_event_origin",
    "ix_memory_event_source_entity",
    "ix_memory_event_operational_project",
    "ix_memory_event_pole",
    "ix_memory_event_operational_event",
}


class SQLiteInstitutionalMemoryMigrationTests(unittest.TestCase):
    def test_0007_to_0008_provenance_contract_and_round_trip(self):
        with tempfile.TemporaryDirectory(prefix="pr66_sqlite_") as directory:
            database_path = Path(directory) / "memory.sqlite3"
            database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
            config = Config("alembic.ini")

            def upgrade(revision: str) -> None:
                with patch.object(settings, "DATABASE_URL", database_url):
                    command.upgrade(config, revision)

            def downgrade(revision: str) -> None:
                with patch.object(settings, "DATABASE_URL", database_url):
                    command.downgrade(config, revision)

            upgrade("20260909_0007")
            engine = create_engine(database_url, poolclass=NullPool)
            with engine.begin() as connection:
                # The baseline revision builds from the current ORM metadata. Recreate
                # the event table at its actual 0007 contract so this fixture cannot
                # accidentally inherit columns introduced by the revision under test.
                connection.execute(text("DROP TABLE institutional_events"))
                connection.execute(
                    text(
                        """
                        CREATE TABLE institutional_events (
                            id CHAR(32) NOT NULL PRIMARY KEY,
                            title VARCHAR(220) NOT NULL,
                            event_type VARCHAR(60) NOT NULL,
                            event_date DATE,
                            year INTEGER NOT NULL,
                            end_date DATE,
                            description TEXT,
                            territory_id CHAR(32) REFERENCES institutional_territories(id) ON DELETE SET NULL,
                            canonical_project_id CHAR(32) REFERENCES institutional_canonical_projects(id) ON DELETE SET NULL,
                            generation_id CHAR(32) REFERENCES institutional_generations(id) ON DELETE SET NULL,
                            visibility VARCHAR(30) NOT NULL,
                            status VARCHAR(40) NOT NULL,
                            source_id CHAR(32) REFERENCES institutional_sources(id) ON DELETE RESTRICT,
                            validation_status VARCHAR(32) NOT NULL,
                            created_by_id CHAR(32) REFERENCES users(id) ON DELETE SET NULL,
                            validated_by_id CHAR(32) REFERENCES users(id) ON DELETE SET NULL,
                            validated_at DATETIME,
                            created_at DATETIME NOT NULL,
                            updated_at DATETIME NOT NULL,
                            CONSTRAINT ck_memory_event_validation CHECK (
                                validation_status IN (
                                    'HISTORICAL_REPORTED', 'EVIDENCE_PENDING',
                                    'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED',
                                    'REJECTED', 'SUPERSEDED'
                                )
                            ),
                            CONSTRAINT ck_memory_event_year CHECK (year BETWEEN 1000 AND 9999),
                            CONSTRAINT ck_memory_event_dates CHECK (
                                end_date IS NULL OR event_date IS NULL OR end_date >= event_date
                            ),
                            CONSTRAINT ck_memory_event_visibility CHECK (
                                visibility IN ('private', 'internal')
                            )
                        )
                        """
                    )
                )
                connection.execute(
                    text(
                        "CREATE INDEX ix_memory_event_timeline "
                        "ON institutional_events (year, event_date)"
                    )
                )
                connection.execute(
                    text(
                        "CREATE INDEX ix_memory_event_project "
                        "ON institutional_events (canonical_project_id, year)"
                    )
                )
                connection.execute(
                    text(
                        "CREATE INDEX ix_memory_event_territory "
                        "ON institutional_events (territory_id, year)"
                    )
                )
                connection.execute(
                    text(
                        "INSERT INTO institutional_events "
                        "(id, title, event_type, year, visibility, status, "
                        "validation_status, created_at, updated_at) VALUES "
                        "('10000000-0000-0000-0000-000000000001', "
                        "'Repere existant', 'milestone', 2025, 'internal', "
                        "'completed', 'VERIFIED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                )

            upgrade("20260910_0008")
            inspector = inspect(engine)
            self.assertTrue(
                MEMORY_EVENT_PROVENANCE_COLUMNS.issubset(
                    column["name"]
                    for column in inspector.get_columns("institutional_events")
                )
            )
            self.assertTrue(
                MEMORY_EVENT_PROVENANCE_INDEXES.issubset(
                    index["name"]
                    for index in inspector.get_indexes("institutional_events")
                )
            )
            foreign_keys = {
                (
                    tuple(foreign_key["constrained_columns"]),
                    foreign_key["referred_table"],
                    tuple(foreign_key["referred_columns"]),
                )
                for foreign_key in inspector.get_foreign_keys("institutional_events")
            }
            self.assertTrue(
                {
                    (("operational_project_id",), "projects", ("id",)),
                    (("pole_id",), "poles", ("id",)),
                    (("operational_event_id",), "events", ("id",)),
                }.issubset(foreign_keys)
            )
            checks = {
                check["name"]
                for check in inspector.get_check_constraints("institutional_events")
            }
            self.assertTrue(
                {"ck_memory_event_origin", "ck_memory_event_operational_provenance"}.issubset(
                    checks
                )
            )
            with engine.begin() as connection:
                historical_provenance = connection.execute(
                    text(
                        "SELECT origin, capture_key, source_entity_type, "
                        "source_entity_id, source_entity_version, captured_at, "
                        "operational_project_id, pole_id, operational_event_id "
                        "FROM institutional_events "
                        "WHERE id = '10000000-0000-0000-0000-000000000001'"
                    )
                ).one()
                self.assertEqual(
                    tuple(historical_provenance),
                    ("manual", None, None, None, None, None, None, None, None),
                )
                connection.execute(
                    text(
                        "INSERT INTO institutional_events "
                        "(id, title, event_type, year, visibility, status, "
                        "validation_status, created_at, updated_at, origin, "
                        "capture_key, source_entity_type, source_entity_id, captured_at) "
                        "VALUES ('10000000-0000-0000-0000-000000000002', "
                        "'Capture', 'project_completed', 2026, 'internal', "
                        "'completed', 'VERIFIED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, "
                        "'operational', 'project:one:termine', 'project', "
                        "'20000000-0000-0000-0000-000000000001', CURRENT_TIMESTAMP)"
                    )
                )
            with self.assertRaises(Exception):
                with engine.begin() as connection:
                    connection.execute(
                        text(
                            "INSERT INTO institutional_events "
                            "(id, title, event_type, year, visibility, status, "
                            "validation_status, created_at, updated_at, origin, "
                            "capture_key, source_entity_type, source_entity_id, captured_at) "
                            "VALUES ('10000000-0000-0000-0000-000000000003', "
                            "'Duplicate', 'project_completed', 2026, 'internal', "
                            "'completed', 'VERIFIED', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, "
                            "'operational', 'project:one:termine', 'project', "
                            "'20000000-0000-0000-0000-000000000002', CURRENT_TIMESTAMP)"
                        )
                    )

            downgrade("20260909_0007")
            inspector = inspect(engine)
            self.assertTrue(
                MEMORY_EVENT_PROVENANCE_COLUMNS.isdisjoint(
                    column["name"]
                    for column in inspector.get_columns("institutional_events")
                )
            )
            with engine.connect() as connection:
                self.assertEqual(
                    connection.execute(
                        text(
                            "SELECT title FROM institutional_events "
                            "WHERE id = '10000000-0000-0000-0000-000000000001'"
                        )
                    ).scalar_one(),
                    "Repere existant",
                )

            upgrade("20260910_0008")
            with engine.connect() as connection:
                historical_provenance = connection.execute(
                    text(
                        "SELECT origin, capture_key, source_entity_type, "
                        "source_entity_id, source_entity_version, captured_at, "
                        "operational_project_id, pole_id, operational_event_id "
                        "FROM institutional_events "
                        "WHERE id = '10000000-0000-0000-0000-000000000001'"
                    )
                ).one()
                self.assertEqual(
                    tuple(historical_provenance),
                    ("manual", None, None, None, None, None, None, None, None),
                )
                self.assertEqual(
                    connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(),
                    "20260910_0008",
                )
            engine.dispose()

    def test_fresh_downgrade_and_reupgrade_preserve_archive_rows(self):
        with tempfile.TemporaryDirectory(prefix="pr2d_sqlite_") as directory:
            database_path = Path(directory) / "memory.sqlite3"
            database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
            config = Config("alembic.ini")
            heads = ScriptDirectory.from_config(config).get_heads()
            self.assertEqual(heads, ["20260913_0009"])

            def upgrade(revision: str) -> None:
                with patch.object(settings, "DATABASE_URL", database_url):
                    command.upgrade(config, revision)

            def downgrade(revision: str) -> None:
                with patch.object(settings, "DATABASE_URL", database_url):
                    command.downgrade(config, revision)

            upgrade("head")
            engine = create_engine(database_url, poolclass=NullPool)
            inspector = inspect(engine)
            self.assertTrue(MEMORY_TABLES.issubset(inspector.get_table_names()))
            self.assertTrue(
                COMPETITION_COLUMNS.issubset(
                    column["name"]
                    for column in inspector.get_columns("archive_competition_records")
                )
            )
            self.assertTrue(
                AWARD_COLUMNS.issubset(
                    column["name"]
                    for column in inspector.get_columns("archive_awards")
                )
            )
            with engine.begin() as connection:
                connection.execute(
                    text(
                        "INSERT INTO archive_competition_records "
                        "(id, name, year, validation_status, project_ids, award_ids, "
                        "is_featured, created_at, updated_at) VALUES "
                        "('competition-legacy', 'Legacy competition', 2018, "
                        "'HISTORICAL_REPORTED', '[]', '[]', 0, CURRENT_TIMESTAMP, "
                        "CURRENT_TIMESTAMP)"
                    )
                )
                connection.execute(
                    text(
                        "INSERT INTO archive_awards "
                        "(id, title, year, validation_status, is_featured, created_at, "
                        "updated_at) VALUES ('award-legacy', 'Legacy award', 2018, "
                        "'HISTORICAL_REPORTED', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                    )
                )
                revision = connection.execute(
                    text("SELECT version_num FROM alembic_version")
                ).scalar_one()
            self.assertEqual(revision, "20260913_0009")

            downgrade("20260903_0003")
            inspector = inspect(engine)
            self.assertTrue(MEMORY_TABLES.isdisjoint(inspector.get_table_names()))
            self.assertTrue(
                COMPETITION_COLUMNS.isdisjoint(
                    column["name"]
                    for column in inspector.get_columns("archive_competition_records")
                )
            )
            self.assertTrue(
                AWARD_COLUMNS.isdisjoint(
                    column["name"]
                    for column in inspector.get_columns("archive_awards")
                )
            )
            with engine.connect() as connection:
                self.assertEqual(
                    connection.execute(
                        text(
                            "SELECT name FROM archive_competition_records "
                            "WHERE id = 'competition-legacy'"
                        )
                    ).scalar_one(),
                    "Legacy competition",
                )
                self.assertEqual(
                    connection.execute(
                        text("SELECT title FROM archive_awards WHERE id = 'award-legacy'")
                    ).scalar_one(),
                    "Legacy award",
                )

            upgrade("head")
            inspector = inspect(engine)
            self.assertTrue(MEMORY_TABLES.issubset(inspector.get_table_names()))
            with engine.connect() as connection:
                rows = connection.execute(
                    text(
                        "SELECT validation_status FROM archive_competition_records "
                        "WHERE id = 'competition-legacy' UNION ALL "
                        "SELECT validation_status FROM archive_awards "
                        "WHERE id = 'award-legacy'"
                    )
                ).scalars()
                self.assertEqual(list(rows), ["HISTORICAL_REPORTED"] * 2)
                revision = connection.execute(
                    text("SELECT version_num FROM alembic_version")
                ).scalar_one()
            self.assertEqual(revision, "20260913_0009")
            engine.dispose()


if __name__ == "__main__":
    unittest.main()
