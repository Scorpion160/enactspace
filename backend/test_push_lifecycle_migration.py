"""PR-5 Alembic acceptance against fresh and upgraded SQLite schemas."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text

from app.core.config import settings


class PushLifecycleMigrationTests(unittest.TestCase):
    def test_0005_upgrade_downgrade_reupgrade_and_fresh_head(self):
        self.assertEqual(
            ScriptDirectory.from_config(Config("alembic.ini")).get_heads(),
            ["20260910_0008"],
        )
        for start_at_0005 in (True, False):
            with self.subTest(start_at_0005=start_at_0005), tempfile.TemporaryDirectory(prefix="pr5_sqlite_") as directory:
                url = f"sqlite+pysqlite:///{(Path(directory) / 'push.sqlite3').as_posix()}"
                config = Config("alembic.ini")
                with patch.object(settings, "DATABASE_URL", url):
                    if start_at_0005:
                        command.upgrade(config, "20260906_0005")
                    command.upgrade(config, "head")
                engine = create_engine(url)
                inspector = inspect(engine)
                self.assertIn("push_deliveries", inspector.get_table_names())
                delivery_columns = {
                    item["name"] for item in inspector.get_columns("push_deliveries")
                }
                self.assertIn("processing_started_at", delivery_columns)
                columns = {item["name"] for item in inspector.get_columns("app_installations")}
                self.assertTrue({
                    "push_provider", "push_token_ciphertext", "push_token_hash",
                    "push_token_updated_at",
                }.issubset(columns))
                with engine.connect() as connection:
                    self.assertEqual(
                        connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(),
                        "20260910_0008",
                    )
                if start_at_0005:
                    engine.dispose()
                    with patch.object(settings, "DATABASE_URL", url):
                        command.downgrade(config, "20260906_0005")
                    downgraded_engine = create_engine(url)
                    inspector = inspect(downgraded_engine)
                    self.assertNotIn("push_deliveries", inspector.get_table_names())
                    downgraded_engine.dispose()
                    with patch.object(settings, "DATABASE_URL", url):
                        command.upgrade(config, "20260906_0006")
                else:
                    engine.dispose()


if __name__ == "__main__":
    unittest.main()
