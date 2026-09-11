"""PR-3 acceptance tests against isolated local PostgreSQL 16."""

import os
import secrets
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from threading import Barrier
from types import SimpleNamespace
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from fastapi import HTTPException
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

import app.models.base  # noqa: F401
from app.api.routes import product_services as product
from app.core.config import settings
from app.schemas.product_services import AppVersionPolicyUpdate, ProductPlatform


PRODUCT_TABLES = {
    "app_installations",
    "support_tickets",
    "support_ticket_messages",
    "product_feedback",
    "app_releases",
    "app_version_policies",
}


class PostgreSQLProductServicesTests(unittest.TestCase):
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
            raise RuntimeError("Refusing a non-local or non-test PostgreSQL database")
        cls.schema = "pr3_" + secrets.token_hex(12)
        cls.admin_engine = create_engine(url, connect_args={"connect_timeout": 5})
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA "{cls.schema}"'))
        cls.addClassCleanup(cls._cleanup_schema)
        isolated = url.update_query_dict({"options": f"-csearch_path={cls.schema}"})
        cls.isolated_url = isolated.render_as_string(hide_password=False)
        cls.engine = create_engine(cls.isolated_url, connect_args={"connect_timeout": 5})
        cls.addClassCleanup(cls.engine.dispose)
        cls.config = Config("alembic.ini")
        cls.heads = ScriptDirectory.from_config(cls.config).get_heads()
        if cls.heads != ["20260910_0008"]:
            raise AssertionError(f"Expected current Alembic head, got {cls.heads}")

    @classmethod
    def _upgrade(cls, revision):
        with patch.object(settings, "DATABASE_URL", cls.isolated_url):
            command.upgrade(cls.config, revision)

    @classmethod
    def _downgrade(cls, revision):
        with patch.object(settings, "DATABASE_URL", cls.isolated_url):
            command.downgrade(cls.config, revision)

    @classmethod
    def _cleanup_schema(cls):
        if not cls.schema.startswith("pr3_") or len(cls.schema) != 28:
            raise RuntimeError("Unsafe PR-3 test schema cleanup target")
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{cls.schema}" CASCADE'))
        cls.admin_engine.dispose()

    @staticmethod
    def _insert_user(connection, user_id):
        connection.execute(
            text(
                """
                INSERT INTO users (
                    id, first_name, last_name, email, profile_type,
                    password_hash, status, email_verified, is_active,
                    created_at, updated_at
                ) VALUES (
                    :id, 'PR3', 'Member', :email, 'enacteur', 'unused',
                    'active', true, true, :now, :now
                )
                """
            ),
            {
                "id": user_id,
                "email": f"{secrets.token_hex(8)}@example.test",
                "now": datetime.utcnow(),
            },
        )

    def test_postgresql_lifecycle_constraints_concurrency_and_ownership(self):
        self._upgrade("head")
        inspector = inspect(self.engine)
        self.assertTrue(PRODUCT_TABLES.issubset(inspector.get_table_names()))
        with self.engine.connect() as connection:
            self.assertTrue(
                connection.execute(text("SELECT version()"))
                .scalar_one()
                .startswith("PostgreSQL 16")
            )
            self.assertEqual(
                connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(),
                "20260910_0008",
            )
            self.assertEqual(
                connection.execute(text("SELECT count(*) FROM app_releases")).scalar_one(),
                0,
            )

        self._downgrade("20260905_0004")
        inspector = inspect(self.engine)
        self.assertTrue(PRODUCT_TABLES.isdisjoint(inspector.get_table_names()))
        existing_user = uuid.uuid4()
        notification_id = uuid.uuid4()
        with self.engine.begin() as connection:
            self._insert_user(connection, existing_user)
            connection.execute(
                text(
                    """
                    INSERT INTO user_preferences (
                        user_id, locale, theme, notification_in_app_enabled,
                        notification_email_enabled, created_at, updated_at
                    ) VALUES (:id, 'fr', 'dark', true, false, :now, :now)
                    """
                ),
                {"id": existing_user, "now": datetime.utcnow()},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO notifications (
                        id, user_id, title, message, type, is_read, created_at
                    ) VALUES (:id, :user_id, 'Existing', 'Preserved', 'general', false, :now)
                    """
                ),
                {"id": notification_id, "user_id": existing_user, "now": datetime.utcnow()},
            )
        self._upgrade("head")
        with self.engine.connect() as connection:
            self.assertEqual(
                tuple(connection.execute(
                    text(
                        "SELECT theme, notification_email_enabled, "
                        "notification_push_enabled FROM user_preferences WHERE user_id = :id"
                    ),
                    {"id": existing_user},
                ).one()),
                ("dark", False, False),
            )
            self.assertEqual(
                tuple(connection.execute(
                    text(
                        "SELECT title, in_app_suppressed FROM notifications WHERE id = :id"
                    ),
                    {"id": notification_id},
                ).one()),
                ("Existing", False),
            )

        first_user = uuid.uuid4()
        second_user = uuid.uuid4()
        installation_key = uuid.uuid4()
        with self.engine.begin() as connection:
            self._insert_user(connection, first_user)
            self._insert_user(connection, second_user)

        def claim_installation(user_id):
            try:
                with self.engine.begin() as connection:
                    connection.execute(
                        text(
                            """
                            INSERT INTO app_installations (
                                id, user_id, installation_key, platform,
                                last_seen_at, created_at, updated_at
                            ) VALUES (
                                :id, :user_id, :key, 'android', :now, :now, :now
                            )
                            """
                        ),
                        {
                            "id": uuid.uuid4(), "user_id": user_id,
                            "key": installation_key, "now": datetime.utcnow(),
                        },
                    )
                return True
            except IntegrityError:
                return False

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(claim_installation, (first_user, second_user)))
        self.assertEqual(sorted(results), [False, True])
        with self.engine.connect() as connection:
            owner = connection.execute(
                text("SELECT user_id FROM app_installations WHERE installation_key = :key"),
                {"key": installation_key},
            ).scalar_one()
            self.assertIn(owner, {first_user, second_user})
            self.assertEqual(
                connection.execute(
                    text("SELECT count(*) FROM app_installations WHERE user_id = :owner"),
                    {"owner": owner},
                ).scalar_one(),
                1,
            )

        release_id = uuid.uuid4()
        ios_release_id = uuid.uuid4()
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    """
                    INSERT INTO app_releases (
                        id, platform, version, build_number, status,
                        published_at, created_at, updated_at
                    ) VALUES (
                        :id, 'android', '1.0.0', 100, 'published', :now, :now, :now
                    )
                    """
                ),
                {"id": release_id, "now": datetime.utcnow()},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO app_releases (
                        id, platform, version, build_number, status,
                        published_at, created_at, updated_at
                    ) VALUES (
                        :id, 'ios', '1.0.0', 100, 'published', :now, :now, :now
                    )
                    """
                ),
                {"id": ios_release_id, "now": datetime.utcnow()},
            )
        invalid_statements = (
            (
                """
                INSERT INTO app_releases (
                    id, platform, version, build_number, status,
                    published_at, created_at, updated_at
                ) VALUES (
                    :id, 'android', '1.0.1', 100, 'published', :now, :now, :now
                )
                """,
                {"id": uuid.uuid4(), "now": datetime.utcnow()},
            ),
            (
                """
                INSERT INTO app_version_policies (
                    id, platform, force_update_to_current, maintenance_enabled,
                    maintenance_starts_at, created_at, updated_at
                ) VALUES (
                    :id, 'android', false, true, :now, :now, :now
                )
                """,
                {"id": uuid.uuid4(), "now": datetime.utcnow()},
            ),
        )
        for statement, parameters in invalid_statements:
            with self.assertRaises(IntegrityError):
                with self.engine.begin() as connection:
                    connection.execute(text(statement), parameters)

        with self.engine.begin() as connection:
            connection.execute(
                text(
                    """
                    INSERT INTO app_version_policies (
                        id, platform, current_release_id,
                        minimum_supported_release_id, force_update_to_current,
                        maintenance_enabled, created_at, updated_at
                    ) VALUES (
                        :id, 'android', :release_id, :release_id,
                        false, false, :now, :now
                    )
                    """
                ),
                {
                    "id": uuid.uuid4(),
                    "release_id": release_id,
                    "now": datetime.utcnow(),
                },
            )
            connection.execute(
                text("DELETE FROM app_version_policies WHERE platform = 'android'")
            )
        for release_column in (
            "current_release_id",
            "minimum_supported_release_id",
        ):
            with self.assertRaises(IntegrityError):
                with self.engine.begin() as connection:
                    connection.execute(
                        text(
                            f"""
                            INSERT INTO app_version_policies (
                                id, platform, {release_column},
                                force_update_to_current, maintenance_enabled,
                                created_at, updated_at
                            ) VALUES (
                                :id, 'android', :release_id, false, false, :now, :now
                            )
                            """
                        ),
                        {
                            "id": uuid.uuid4(),
                            "release_id": ios_release_id,
                            "now": datetime.utcnow(),
                        },
                    )

        race_release_id = uuid.uuid4()
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    """
                    INSERT INTO app_releases (
                        id, platform, version, build_number, status,
                        published_at, created_at, updated_at
                    ) VALUES (
                        :id, 'android', '5.0.0', 500, 'published', :now, :now, :now
                    )
                    """
                ),
                {"id": race_release_id, "now": datetime.utcnow()},
            )
        Session = sessionmaker(bind=self.engine, autoflush=False)
        barrier = Barrier(2)
        manager = SimpleNamespace(id=first_user)

        def assign_policy():
            with Session() as db:
                barrier.wait()
                try:
                    product.update_app_version_policy(
                        ProductPlatform.android,
                        AppVersionPolicyUpdate(current_release_id=race_release_id),
                        db=db,
                        current_user=manager,
                    )
                    return "assigned"
                except HTTPException as error:
                    db.rollback()
                    return f"assignment_rejected_{error.status_code}"

        def withdraw_release():
            with Session() as db:
                barrier.wait()
                try:
                    product.withdraw_app_release(
                        str(race_release_id), db=db, current_user=manager
                    )
                    return "withdrawn"
                except HTTPException as error:
                    db.rollback()
                    return f"withdrawal_rejected_{error.status_code}"

        with ThreadPoolExecutor(max_workers=2) as executor:
            assignment = executor.submit(assign_policy)
            withdrawal = executor.submit(withdraw_release)
            race_results = {assignment.result(), withdrawal.result()}
        self.assertEqual(len(race_results & {"assigned", "withdrawn"}), 1)
        with self.engine.connect() as connection:
            release_status = connection.execute(
                text("SELECT status FROM app_releases WHERE id = :id"),
                {"id": race_release_id},
            ).scalar_one()
            policy_references = connection.execute(
                text(
                    """
                    SELECT count(*) FROM app_version_policies
                    WHERE current_release_id = :id
                       OR minimum_supported_release_id = :id
                    """
                ),
                {"id": race_release_id},
            ).scalar_one()
        self.assertFalse(release_status == "withdrawn" and policy_references)

        cascade_user = uuid.uuid4()
        with self.engine.begin() as connection:
            self._insert_user(connection, cascade_user)
            connection.execute(
                text(
                    """
                    INSERT INTO app_installations (
                        id, user_id, installation_key, platform,
                        last_seen_at, created_at, updated_at
                    ) VALUES (:id, :user_id, :key, 'web', :now, :now, :now)
                    """
                ),
                {
                    "id": uuid.uuid4(), "user_id": cascade_user,
                    "key": uuid.uuid4(), "now": datetime.utcnow(),
                },
            )
            connection.execute(text("DELETE FROM users WHERE id = :id"), {"id": cascade_user})
        with self.engine.connect() as connection:
            self.assertEqual(
                connection.execute(
                    text("SELECT count(*) FROM app_installations WHERE user_id = :id"),
                    {"id": cascade_user},
                ).scalar_one(),
                0,
            )


if __name__ == "__main__":
    unittest.main()
