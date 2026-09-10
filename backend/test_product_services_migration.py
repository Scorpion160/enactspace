"""PR-3 Alembic acceptance against an isolated SQLite database."""

import tempfile
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, event, inspect, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.pool import NullPool

import app.models.base  # noqa: F401
from app.core.config import settings


PRODUCT_TABLES = {
    "app_installations",
    "support_tickets",
    "support_ticket_messages",
    "product_feedback",
    "app_releases",
    "app_version_policies",
}


class SQLiteProductServicesMigrationTests(unittest.TestCase):
    def test_fresh_downgrade_reupgrade_and_existing_data_preservation(self):
        with tempfile.TemporaryDirectory(prefix="pr3_sqlite_") as directory:
            database_path = Path(directory) / "product.sqlite3"
            database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
            config = Config("alembic.ini")
            self.assertEqual(
                ScriptDirectory.from_config(config).get_heads(),
                ["20260909_0007"],
            )

            def upgrade(revision: str) -> None:
                with patch.object(settings, "DATABASE_URL", database_url):
                    command.upgrade(config, revision)

            def downgrade(revision: str) -> None:
                with patch.object(settings, "DATABASE_URL", database_url):
                    command.downgrade(config, revision)

            upgrade("head")
            engine = create_engine(database_url, poolclass=NullPool)

            @event.listens_for(engine, "connect")
            def enable_sqlite_foreign_keys(dbapi_connection, connection_record):
                del connection_record
                cursor = dbapi_connection.cursor()
                cursor.execute("PRAGMA foreign_keys=ON")
                cursor.close()

            inspector = inspect(engine)
            self.assertTrue(PRODUCT_TABLES.issubset(inspector.get_table_names()))
            with engine.connect() as connection:
                self.assertEqual(
                    connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(),
                    "20260909_0007",
                )
                for table in ("app_installations", "app_releases", "app_version_policies"):
                    self.assertEqual(
                        connection.execute(text(f"SELECT count(*) FROM {table}")).scalar_one(),
                        0,
                    )

            downgrade("20260905_0004")
            inspector = inspect(engine)
            self.assertTrue(PRODUCT_TABLES.isdisjoint(inspector.get_table_names()))
            self.assertNotIn(
                "notification_push_enabled",
                {column["name"] for column in inspector.get_columns("user_preferences")},
            )
            self.assertNotIn(
                "in_app_suppressed",
                {column["name"] for column in inspector.get_columns("notifications")},
            )
            user_id = str(uuid.uuid4())
            notification_id = str(uuid.uuid4())
            with engine.begin() as connection:
                connection.execute(
                    text(
                        """
                        INSERT INTO users (
                            id, first_name, last_name, email, profile_type,
                            password_hash, status, email_verified, is_active,
                            created_at, updated_at
                        ) VALUES (
                            :id, 'Existing', 'Member', :email, 'enacteur', 'unused',
                            'active', 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                        )
                        """
                    ),
                    {"id": user_id, "email": f"{uuid.uuid4().hex}@example.test"},
                )
                connection.execute(
                    text(
                        """
                        INSERT INTO user_preferences (
                            user_id, locale, theme, notification_in_app_enabled,
                            notification_email_enabled, created_at, updated_at
                        ) VALUES (
                            :user_id, 'fr', 'dark', 1, 0,
                            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                        )
                        """
                    ),
                    {"user_id": user_id},
                )
                connection.execute(
                    text(
                        """
                        INSERT INTO notifications (
                            id, user_id, title, message, type, is_read, created_at
                        ) VALUES (
                            :id, :user_id, 'Historique', 'Conserve', 'general', 0,
                            CURRENT_TIMESTAMP
                        )
                        """
                    ),
                    {"id": notification_id, "user_id": user_id},
                )

            upgrade("head")
            inspector = inspect(engine)
            self.assertTrue(PRODUCT_TABLES.issubset(inspector.get_table_names()))
            with engine.begin() as connection:
                preference = connection.execute(
                    text(
                        "SELECT theme, notification_email_enabled, "
                        "notification_push_enabled FROM user_preferences "
                        "WHERE user_id = :user_id"
                    ),
                    {"user_id": user_id},
                ).one()
                self.assertEqual(tuple(preference), ("dark", 0, 0))
                notification = connection.execute(
                    text(
                        "SELECT title, in_app_suppressed FROM notifications "
                        "WHERE id = :id"
                    ),
                    {"id": notification_id},
                ).one()
                self.assertEqual(tuple(notification), ("Historique", 0))
                connection.execute(
                    text(
                        """
                        INSERT INTO app_releases (
                            id, platform, version, build_number, status,
                            created_at, updated_at
                        ) VALUES (
                            :id, 'android', '1.0.0', 1, 'draft',
                            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                        )
                        """
                    ),
                    {"id": str(uuid.uuid4())},
                )
                connection.execute(
                    text(
                        """
                        INSERT INTO app_releases (
                            id, platform, version, build_number, status,
                            created_at, updated_at
                        ) VALUES (
                            :id, 'ios', '1.0.0', 1, 'draft',
                            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                        )
                        """
                    ),
                    {"id": str(uuid.uuid4())},
                )
            with self.assertRaises(IntegrityError):
                with engine.begin() as connection:
                    connection.execute(
                        text(
                            """
                            INSERT INTO app_releases (
                                id, platform, version, build_number, status,
                                created_at, updated_at
                            ) VALUES (
                                :id, 'android', '1.0.1', 1, 'draft',
                                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                            )
                            """
                        ),
                        {"id": str(uuid.uuid4())},
                    )
            with self.assertRaises(IntegrityError):
                with engine.begin() as connection:
                    connection.execute(
                        text(
                            """
                            INSERT INTO app_releases (
                                id, platform, version, build_number, status,
                                created_at, updated_at
                            ) VALUES (
                                :id, 'android', 'broken', 0, 'draft',
                                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                            )
                            """
                        ),
                        {"id": str(uuid.uuid4())},
                    )

            android_release = str(uuid.uuid4())
            ios_release = str(uuid.uuid4())
            with engine.begin() as connection:
                for release_id, platform, build in (
                    (android_release, "android", 10),
                    (ios_release, "ios", 10),
                ):
                    connection.execute(
                        text(
                            """
                            INSERT INTO app_releases (
                                id, platform, version, build_number, status,
                                published_at, created_at, updated_at
                            ) VALUES (
                                :id, :platform, '2.0.0', :build, 'published',
                                CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                            )
                            """
                        ),
                        {"id": release_id, "platform": platform, "build": build},
                    )
                connection.execute(
                    text(
                        """
                        INSERT INTO app_version_policies (
                            id, platform, current_release_id,
                            minimum_supported_release_id, force_update_to_current,
                            maintenance_enabled, created_at, updated_at
                        ) VALUES (
                            :id, 'android', :release_id, :release_id,
                            0, 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                        )
                        """
                    ),
                    {"id": str(uuid.uuid4()), "release_id": android_release},
                )
                connection.execute(
                    text("DELETE FROM app_version_policies WHERE platform = 'android'")
                )
            for release_column in (
                "current_release_id",
                "minimum_supported_release_id",
            ):
                with self.assertRaises(IntegrityError):
                    with engine.begin() as connection:
                        connection.execute(
                            text(
                                f"""
                                INSERT INTO app_version_policies (
                                    id, platform, {release_column},
                                    force_update_to_current, maintenance_enabled,
                                    created_at, updated_at
                                ) VALUES (
                                    :id, 'android', :release_id, 0, 0,
                                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                                )
                                """
                            ),
                            {"id": str(uuid.uuid4()), "release_id": ios_release},
                        )

            downgrade("20260905_0004")
            with engine.connect() as connection:
                self.assertEqual(
                    connection.execute(
                        text("SELECT theme FROM user_preferences WHERE user_id = :id"),
                        {"id": user_id},
                    ).scalar_one(),
                    "dark",
                )
                self.assertEqual(
                    connection.execute(
                        text("SELECT title FROM notifications WHERE id = :id"),
                        {"id": notification_id},
                    ).scalar_one(),
                    "Historique",
                )
            upgrade("head")
            with engine.connect() as connection:
                self.assertEqual(
                    connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(),
                    "20260909_0007",
                )
            engine.dispose()


if __name__ == "__main__":
    unittest.main()
