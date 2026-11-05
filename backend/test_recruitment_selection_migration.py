"""Selection schema supports both a fresh bootstrap and a deployed previous revision."""
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text

from app.core.config import settings


class RecruitmentSelectionMigrationTests(TestCase):
    def test_fresh_head_and_repeated_upgrade_preserve_the_selection_schema(self):
        with TemporaryDirectory() as directory:
            url = f"sqlite:///{Path(directory) / 'selection.sqlite3'}"
            config = Config("alembic.ini")
            engine = create_engine(url)
            self.addCleanup(engine.dispose)
            with patch.object(settings, "DATABASE_URL", url):
                command.upgrade(config, "head")
                command.upgrade(config, "head")
            inspector = inspect(engine)
            self.assertTrue(inspector.has_table("application_screening_assignments"))
            self.assertIn("selection_policy_version", {column["name"] for column in inspector.get_columns("recruitment_campaigns")})
            self.assertIn("stage", {column["name"] for column in inspector.get_columns("application_reviews")})
            with engine.connect() as connection:
                self.assertEqual(connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(), "20261105_0035")

    def test_previous_revision_upgrade_and_downgrade_are_reversible_without_reviews(self):
        with TemporaryDirectory() as directory:
            url = f"sqlite:///{Path(directory) / 'previous.sqlite3'}"
            config = Config("alembic.ini")
            engine = create_engine(url)
            self.addCleanup(engine.dispose)
            with patch.object(settings, "DATABASE_URL", url):
                command.upgrade(config, "head")
                command.downgrade(config, "20261104_0034")
                self.assertNotIn("selection_policy_version", {
                    column["name"] for column in inspect(engine).get_columns("recruitment_campaigns")
                })
                command.upgrade(config, "head")
                self.assertTrue(inspect(engine).has_table("application_screening_assignments"))
