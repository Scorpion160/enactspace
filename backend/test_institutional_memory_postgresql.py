"""PR-2D acceptance tests against isolated local PostgreSQL 16."""

import os
import secrets
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from threading import Barrier
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker

import app.models.base  # noqa: F401
from app.api.routes import institutional_memory as memory
from app.core.config import settings
from app.models.attendance import AttendanceSession
from app.models.institutional_memory import InstitutionalEvent, InstitutionalSource
from app.models.project import Project
from app.models.user import User
from app.services.institutional_memory_capture import (
    capture_attendance_archive,
    capture_project_completion,
)


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


class PostgreSQLInstitutionalMemoryTests(unittest.TestCase):
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
        cls.schema = "pr2d_" + secrets.token_hex(12)
        cls.admin_engine = create_engine(url, connect_args={"connect_timeout": 5})
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'CREATE SCHEMA "{cls.schema}"'))
        cls.addClassCleanup(cls._cleanup_schema)
        isolated = url.update_query_dict({"options": f"-csearch_path={cls.schema}"})
        cls.isolated_url = isolated.render_as_string(hide_password=False)
        cls.engine = create_engine(isolated, connect_args={"connect_timeout": 5})
        cls.Session = sessionmaker(bind=cls.engine, autoflush=False)
        cls.addClassCleanup(cls.engine.dispose)
        cls.config = Config("alembic.ini")
        cls.heads = ScriptDirectory.from_config(cls.config).get_heads()
        if cls.heads != ["20260910_0008"]:
            raise AssertionError(f"Expected current Alembic head, got {cls.heads}")
        with patch.object(settings, "DATABASE_URL", cls.isolated_url):
            command.upgrade(cls.config, "head")

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
        if not cls.schema.startswith("pr2d_") or len(cls.schema) != 29:
            raise RuntimeError("Unsafe PR-2D test schema cleanup target")
        with cls.admin_engine.begin() as connection:
            connection.execute(text(f'DROP SCHEMA "{cls.schema}" CASCADE'))
        cls.admin_engine.dispose()

    def _user(self):
        db = self.Session()
        try:
            user = User(
                first_name="PR66",
                last_name="PostgreSQL",
                email=f"{secrets.token_hex(8)}@example.test",
                password_hash="unused",
                status="active",
                is_active=True,
                email_verified=True,
            )
            db.add(user)
            db.commit()
            return user.id
        finally:
            db.close()

    def test_capture_key_project_and_attendance_concurrency(self):
        actor_id = self._user()
        db = self.Session()
        try:
            project = Project(name="Projet PR66 concurrent", status="termine")
            attendance_session = AttendanceSession(
                title="Séance PR66 concurrente",
                session_type="general_meeting",
                scope_type="club",
                status="archived",
                is_closed=True,
                created_by=actor_id,
            )
            db.add_all([project, attendance_session])
            db.commit()
            project_id = project.id
            attendance_id = attendance_session.id
        finally:
            db.close()

        def race(model, entity_id, capture):
            barrier = Barrier(2)

            def worker():
                worker_db = self.Session()
                try:
                    entity = worker_db.query(model).filter(model.id == entity_id).one()
                    barrier.wait(timeout=10)
                    result = capture(worker_db, entity, actor_id=actor_id)
                    worker_db.commit()
                    return result.id
                finally:
                    worker_db.close()

            with ThreadPoolExecutor(max_workers=2) as executor:
                return [future.result(timeout=20) for future in [
                    executor.submit(worker),
                    executor.submit(worker),
                ]]

        project_results = race(Project, project_id, capture_project_completion)
        attendance_results = race(
            AttendanceSession,
            attendance_id,
            capture_attendance_archive,
        )
        self.assertEqual(len(set(project_results)), 1)
        self.assertEqual(len(set(attendance_results)), 1)
        db = self.Session()
        try:
            self.assertEqual(
                db.query(InstitutionalEvent)
                .filter(
                    InstitutionalEvent.capture_key.in_(
                        [
                            f"project:{project_id}:termine",
                            f"attendance_session:{attendance_id}:archived",
                        ]
                    )
                )
                .count(),
                2,
            )
        finally:
            db.close()

    def test_timeline_keyset_and_private_source_on_postgresql(self):
        reader_id = self._user()
        db = self.Session()
        try:
            private_source = InstitutionalSource(
                source_type="minutes",
                title="Source privée PR66",
                visibility="private",
                validation_status="VERIFIED",
            )
            db.add(private_source)
            db.flush()
            db.add(
                InstitutionalEvent(
                    title="Repère privé PR66",
                    event_type="milestone",
                    year=2026,
                    visibility="internal",
                    source_id=private_source.id,
                    validation_status="VERIFIED",
                    origin="manual",
                )
            )
            db.add_all(
                [
                    InstitutionalEvent(
                        title=f"Repère PostgreSQL {index:04d}",
                        event_type="milestone",
                        year=2000 + (index % 26),
                        visibility="internal",
                        validation_status="VERIFIED",
                        origin="manual",
                    )
                    for index in range(1001)
                ]
            )
            db.commit()
            reader = db.query(User).filter(User.id == reader_id).one()
            seen = []
            cursor = None
            while True:
                page = memory.list_timeline(
                    start_year=None,
                    end_year=None,
                    resource_type=None,
                    project_id=None,
                    pole_id=None,
                    member_id=None,
                    event_id=None,
                    validation_status=None,
                    search="Repère PostgreSQL",
                    review=False,
                    limit=100,
                    cursor=cursor,
                    db=db,
                    current_user=reader,
                )
                seen.extend(item["id"] for item in page["items"])
                cursor = page["next_cursor"]
                if cursor is None:
                    break
            self.assertEqual(len(seen), 1001)
            self.assertEqual(len(set(seen)), 1001)
            private_page = memory.list_timeline(
                start_year=None,
                end_year=None,
                resource_type=None,
                project_id=None,
                pole_id=None,
                member_id=None,
                event_id=None,
                validation_status=None,
                search="Repère privé PR66",
                review=False,
                limit=25,
                cursor=None,
                db=db,
                current_user=reader,
            )
            self.assertEqual(private_page["items"], [])
        finally:
            db.close()

    def test_postgresql_lifecycle_foreign_keys_and_uniqueness(self):
        self._upgrade("head")
        inspector = inspect(self.engine)
        self.assertTrue(MEMORY_TABLES.issubset(inspector.get_table_names()))
        with self.engine.connect() as connection:
            self.assertTrue(
                connection.execute(text("SELECT version()"))
                .scalar_one()
                .startswith("PostgreSQL 16")
            )
            self.assertEqual(
                connection.execute(
                    text("SELECT version_num FROM alembic_version")
                ).scalar_one(),
                "20260910_0008",
            )

        self._downgrade("20260903_0003")
        inspector = inspect(self.engine)
        self.assertTrue(MEMORY_TABLES.isdisjoint(inspector.get_table_names()))
        self._upgrade("head")
        inspector = inspect(self.engine)
        self.assertTrue(MEMORY_TABLES.issubset(inspector.get_table_names()))

        now = datetime.utcnow()
        user_id = uuid.uuid4()
        source_id = uuid.uuid4()
        first_project_id = uuid.uuid4()
        second_project_id = uuid.uuid4()
        competition_id = uuid.uuid4()
        with self.engine.begin() as connection:
            connection.execute(
                text(
                    """
                    INSERT INTO users (
                        id, first_name, last_name, email, profile_type,
                        password_hash, status, email_verified, is_active,
                        created_at, updated_at
                    ) VALUES (
                        :id, 'Memory', 'Owner', :email, 'enacteur', 'unused',
                        'active', true, true, :now, :now
                    )
                    """
                ),
                {
                    "id": user_id,
                    "email": f"{secrets.token_hex(8)}@example.test",
                    "now": now,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO institutional_sources (
                        id, source_type, title, source_label, visibility,
                        validation_status, created_by_id, created_at, updated_at
                    ) VALUES (
                        :id, 'document', 'Source', 'REF-2024', 'internal',
                        'HISTORICAL_REPORTED', :user_id, :now, :now
                    )
                    """
                ),
                {"id": source_id, "user_id": user_id, "now": now},
            )
            for project_id, name, slug in (
                (first_project_id, "Project A", "project-a"),
                (second_project_id, "Project B", "project-b"),
            ):
                connection.execute(
                    text(
                        """
                        INSERT INTO institutional_canonical_projects (
                            id, canonical_name, slug, status, source_id,
                            validation_status, created_at, updated_at
                        ) VALUES (
                            :id, :name, :slug, 'historical', :source_id,
                            'HISTORICAL_REPORTED', :now, :now
                        )
                        """
                    ),
                    {
                        "id": project_id,
                        "name": name,
                        "slug": slug,
                        "source_id": source_id,
                        "now": now,
                    },
                )
            connection.execute(
                text(
                    """
                    INSERT INTO archive_competition_records (
                        id, name, year, project_ids, award_ids, is_featured,
                        source_id, validation_status, created_at, updated_at
                    ) VALUES (
                        :id, 'Competition', 2024, '[]', '[]', false,
                        :source_id, 'HISTORICAL_REPORTED', :now, :now
                    )
                    """
                ),
                {"id": competition_id, "source_id": source_id, "now": now},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO institutional_project_aliases (
                        id, canonical_project_id, alias, source_id,
                        validation_status, created_at, updated_at
                    ) VALUES (
                        :id, :project_id, 'EcoTerra', :source_id,
                        'HISTORICAL_REPORTED', :now, :now
                    )
                    """
                ),
                {
                    "id": uuid.uuid4(),
                    "project_id": first_project_id,
                    "source_id": source_id,
                    "now": now,
                },
            )

        invalid_statements = (
            (
                """
                INSERT INTO institutional_project_aliases (
                    id, canonical_project_id, alias, validation_status,
                    created_at, updated_at
                ) VALUES (
                    :id, :project_id, 'ecoterra', 'HISTORICAL_REPORTED',
                    :now, :now
                )
                """,
                {"id": uuid.uuid4(), "project_id": second_project_id, "now": now},
            ),
            (
                """
                INSERT INTO institutional_project_relationships (
                    id, source_project_id, target_project_id, relationship_type,
                    validation_status, created_at, updated_at
                ) VALUES (
                    :id, :project_id, :project_id, 'continued_as',
                    'HISTORICAL_REPORTED', :now, :now
                )
                """,
                {"id": uuid.uuid4(), "project_id": first_project_id, "now": now},
            ),
            (
                """
                INSERT INTO institutional_events (
                    id, title, event_type, year, visibility, status, source_id,
                    validation_status, created_at, updated_at
                ) VALUES (
                    :id, 'Broken source', 'milestone', 2024, 'internal',
                    'reported', :missing_source, 'HISTORICAL_REPORTED', :now, :now
                )
                """,
                {"id": uuid.uuid4(), "missing_source": uuid.uuid4(), "now": now},
            ),
        )
        for statement, parameters in invalid_statements:
            with self.subTest(statement=statement.split("INSERT INTO", 1)[1].split("(", 1)[0]):
                with self.assertRaises(IntegrityError):
                    with self.engine.begin() as connection:
                        connection.execute(text(statement), parameters)

        with self.engine.begin() as connection:
            connection.execute(
                text(
                    """
                    INSERT INTO institutional_project_years (
                        id, canonical_project_id, year, status,
                        validation_status, created_at, updated_at
                    ) VALUES (
                        :id, :project_id, 2024, 'reported',
                        'HISTORICAL_REPORTED', :now, :now
                    )
                    """
                ),
                {"id": uuid.uuid4(), "project_id": first_project_id, "now": now},
            )
        with self.assertRaises(IntegrityError):
            with self.engine.begin() as connection:
                connection.execute(
                    text(
                        """
                        INSERT INTO institutional_project_years (
                            id, canonical_project_id, year, status,
                            validation_status, created_at, updated_at
                        ) VALUES (
                            :id, :project_id, 2024, 'reported',
                            'HISTORICAL_REPORTED', :now, :now
                        )
                        """
                    ),
                    {"id": uuid.uuid4(), "project_id": first_project_id, "now": now},
                )


if __name__ == "__main__":
    unittest.main()
