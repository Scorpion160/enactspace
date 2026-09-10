"""PR-2D Alembic acceptance against an isolated SQLite database."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.pool import NullPool

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


class SQLiteInstitutionalMemoryMigrationTests(unittest.TestCase):
    def test_fresh_downgrade_and_reupgrade_preserve_archive_rows(self):
        with tempfile.TemporaryDirectory(prefix="pr2d_sqlite_") as directory:
            database_path = Path(directory) / "memory.sqlite3"
            database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
            config = Config("alembic.ini")
            heads = ScriptDirectory.from_config(config).get_heads()
            self.assertEqual(heads, ["20260909_0007"])

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
            self.assertEqual(revision, "20260909_0007")

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
            self.assertEqual(revision, "20260909_0007")
            engine.dispose()


if __name__ == "__main__":
    unittest.main()
