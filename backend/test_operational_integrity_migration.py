"""Migration acceptance for PR-6.5 operational constraints."""

import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text

from app.core.config import settings


_migration_path = (
    Path(__file__).parent
    / "alembic"
    / "versions"
    / "20260909_0007_operational_integrity.py"
)
_migration_spec = importlib.util.spec_from_file_location(
    "pr65_operational_integrity_migration",
    _migration_path,
)
migration = importlib.util.module_from_spec(_migration_spec)
assert _migration_spec.loader is not None
_migration_spec.loader.exec_module(migration)


class OperationalIntegrityMigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.url = f"sqlite:///{Path(self.temp_dir.name) / 'pr65.sqlite3'}"
        self.config = Config("alembic.ini")

    def _upgrade(self, revision):
        with patch.object(settings, "DATABASE_URL", self.url):
            command.upgrade(self.config, revision)

    def _downgrade(self, revision):
        with patch.object(settings, "DATABASE_URL", self.url):
            command.downgrade(self.config, revision)

    def test_fresh_upgrade_downgrade_reupgrade_and_single_head(self):
        self.assertEqual(
            ScriptDirectory.from_config(self.config).get_heads(),
            ["20260909_0007"],
        )
        self._upgrade("head")
        engine = create_engine(self.url)
        with engine.connect() as connection:
            self.assertEqual(
                connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(),
                "20260909_0007",
            )
        inspector = inspect(engine)
        self.assertIn(
            "uq_attendance_record_session_user",
            {item["name"] for item in inspector.get_unique_constraints("attendance_records")},
        )
        self.assertIn(
            "ux_fees_related_attendance",
            {item["name"] for item in inspector.get_indexes("fees")},
        )
        with engine.connect() as connection:
            self.assertEqual(
                connection.execute(
                    text(
                        "SELECT COUNT(*) FROM sqlite_master "
                        "WHERE type = 'index' AND name = 'ux_users_lower_email'"
                    )
                ).scalar_one(),
                1,
            )
        engine.dispose()

        self._downgrade("20260906_0006")
        self._upgrade("20260909_0007")
        engine = create_engine(self.url)
        with engine.connect() as connection:
            self.assertEqual(
                connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(),
                "20260909_0007",
            )
        engine.dispose()

    def test_duplicate_data_refusal_guards(self):
        cases = [
            (
                "attendance expected-member identity",
                "CREATE TABLE attendance_expected_members (session_id TEXT, user_id TEXT)",
                "INSERT INTO attendance_expected_members VALUES ('s', 'u'), ('s', 'u')",
                "SELECT session_id, user_id FROM attendance_expected_members GROUP BY session_id, user_id HAVING COUNT(*) > 1",
            ),
            (
                "attendance record identity",
                "CREATE TABLE attendance_records (session_id TEXT, user_id TEXT)",
                "INSERT INTO attendance_records VALUES ('s', 'u'), ('s', 'u')",
                "SELECT session_id, user_id FROM attendance_records GROUP BY session_id, user_id HAVING COUNT(*) > 1",
            ),
            (
                "attendance penalty source",
                "CREATE TABLE fees (related_attendance_id TEXT)",
                "INSERT INTO fees VALUES ('r'), ('r')",
                "SELECT related_attendance_id FROM fees WHERE related_attendance_id IS NOT NULL GROUP BY related_attendance_id HAVING COUNT(*) > 1",
            ),
            (
                "fee source identity",
                "CREATE TABLE fees (source_type TEXT, source_id TEXT, user_id TEXT)",
                "INSERT INTO fees VALUES ('bulk', 'x', 'u'), ('bulk', 'x', 'u')",
                "SELECT source_type, source_id, user_id FROM fees WHERE source_type IS NOT NULL AND source_id IS NOT NULL GROUP BY source_type, source_id, user_id HAVING COUNT(*) > 1",
            ),
            (
                "active pole leadership",
                "CREATE TABLE pole_members (pole_id TEXT, position TEXT, is_active BOOLEAN, left_at TEXT)",
                "INSERT INTO pole_members VALUES ('p', 'chef_pole', 1, NULL), ('p', 'chef_pole', 1, NULL)",
                "SELECT pole_id, position FROM pole_members WHERE is_active = true AND left_at IS NULL AND position IN ('chef_pole', 'adjoint_chef_pole') GROUP BY pole_id, position HAVING COUNT(*) > 1",
            ),
            (
                "active project leadership",
                "CREATE TABLE project_members (project_id TEXT, position TEXT, is_active BOOLEAN, left_at TEXT)",
                "INSERT INTO project_members VALUES ('p', 'chef_projet', 1, NULL), ('p', 'chef_projet', 1, NULL)",
                "SELECT project_id, position FROM project_members WHERE is_active = true AND left_at IS NULL AND position IN ('chef_projet', 'adjoint_chef_projet') GROUP BY project_id, position HAVING COUNT(*) > 1",
            ),
        ]
        for label, create_sql, insert_sql, conflict_sql in cases:
            with self.subTest(label=label):
                engine = create_engine("sqlite://")
                with engine.begin() as connection:
                    connection.execute(text(create_sql))
                    connection.execute(text(insert_sql))
                    with patch.object(migration.op, "get_bind", return_value=connection):
                        with self.assertRaisesRegex(RuntimeError, label):
                            migration._refuse_duplicates(label, conflict_sql)
                engine.dispose()

    def test_duplicate_logical_user_email_refuses_upgrade(self):
        self._upgrade("20260906_0006")
        engine = create_engine(self.url)
        with engine.begin() as connection:
            connection.execute(text("DROP INDEX IF EXISTS ux_users_lower_email"))
            connection.execute(
                text(
                    "INSERT INTO users "
                    "(id, first_name, last_name, email, password_hash, profile_type, "
                    "status, email_verified, is_active, created_at, updated_at) VALUES "
                    "('00000000-0000-0000-0000-000000000001', 'Foo', 'One', "
                    "'Foo@Example.test', 'unused', 'enacteur', 'active', 1, 1, "
                    "CURRENT_TIMESTAMP, CURRENT_TIMESTAMP), "
                    "('00000000-0000-0000-0000-000000000002', 'Foo', 'Two', "
                    "'foo@example.test', 'unused', 'enacteur', 'active', 1, 1, "
                    "CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
                )
            )
        engine.dispose()

        with self.assertRaisesRegex(RuntimeError, "user/email identity"):
            self._upgrade("20260909_0007")


if __name__ == "__main__":
    unittest.main()
