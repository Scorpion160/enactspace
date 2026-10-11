"""Academy quiz concurrency tests on isolated PostgreSQL."""

import os
import secrets
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import sessionmaker

import app.models.base  # noqa: F401
from app.api.routes import academy
from app.core.config import settings
from app.models.academy import (
    AcademyQuestion,
    AcademyQuiz,
    AcademyQuizAttempt,
)
from app.models.user import User
from app.schemas.academy import AcademyQuizSubmit


class AcademyQuizPostgreSQLTests(unittest.TestCase):
    schema_prefix = "academy_"

    @classmethod
    def setUpClass(cls):
        raw_url = os.environ.get("TEST_DATABASE_URL")
        if not raw_url:
            raise unittest.SkipTest(
                "TEST_DATABASE_URL missing: PostgreSQL test not run"
            )

        url = make_url(raw_url)
        allowed_hosts = {
            "localhost",
            "127.0.0.1",
            "::1",
            "enactspace_academy_pg_test_postgres",
        }

        if (
            url.get_backend_name() != "postgresql"
            or url.host not in allowed_hosts
            or not (url.database or "").startswith(
                "enactspace_academy_pg_test"
            )
        ):
            raise RuntimeError(
                "Refusing a non-isolated Academy test database"
            )

        cls.schema = cls.schema_prefix + secrets.token_hex(12)
        cls.admin_engine = create_engine(
            url,
            connect_args={"connect_timeout": 5},
        )

        with cls.admin_engine.begin() as connection:
            connection.execute(
                text(f'CREATE SCHEMA "{cls.schema}"')
            )

        cls.addClassCleanup(cls._cleanup_schema)

        isolated = url.update_query_dict(
            {"options": f"-csearch_path={cls.schema}"}
        )
        cls.isolated_url = isolated.render_as_string(
            hide_password=False
        )
        cls.engine = create_engine(
            isolated,
            connect_args={"connect_timeout": 5},
        )
        cls.addClassCleanup(cls.engine.dispose)
        cls.Session = sessionmaker(
            bind=cls.engine,
            autoflush=False,
        )

        config = Config("alembic.ini")
        heads = ScriptDirectory.from_config(config).get_heads()

        if len(heads) != 1:
            raise AssertionError(
                f"Expected one Alembic head, got {heads}"
            )

        with patch.object(
            settings,
            "DATABASE_URL",
            cls.isolated_url,
        ):
            command.upgrade(config, "head")

        with cls.engine.connect() as connection:
            revision = connection.execute(
                text("SELECT version_num FROM alembic_version")
            ).scalar_one()

        if revision != heads[0]:
            raise AssertionError(
                "Fresh Academy PostgreSQL schema did not reach head"
            )

    @classmethod
    def _cleanup_schema(cls):
        expected_length = len(cls.schema_prefix) + 24

        if (
            not cls.schema.startswith(cls.schema_prefix)
            or len(cls.schema) != expected_length
        ):
            raise RuntimeError(
                "Unsafe Academy test schema cleanup target"
            )

        with cls.admin_engine.begin() as connection:
            connection.execute(
                text(f'DROP SCHEMA "{cls.schema}" CASCADE')
            )

        cls.admin_engine.dispose()

    def setUp(self):
        self.db = self.Session()

        self.user = User(
            first_name="Concurrent",
            last_name="Academy",
            email=f"academy-pg-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(self.user)
        self.db.flush()

        self.quiz = AcademyQuiz(
            title="PostgreSQL concurrent quiz",
            description="Concurrent offline synchronization test.",
            passing_score=60,
            time_limit_minutes=8,
            allow_retake=True,
            is_published=True,
            created_by_id=self.user.id,
        )
        self.db.add(self.quiz)
        self.db.flush()

        self.db.add(
            AcademyQuestion(
                quiz_id=self.quiz.id,
                question_type="single_choice",
                prompt="Select the correct answer.",
                choices=["Correct", "Incorrect"],
                correct_answers=[0],
                points=1,
                order_index=0,
            )
        )
        self.db.commit()

        self.user_id = self.user.id
        self.quiz_id = self.quiz.id

    def tearDown(self):
        self.db.rollback()
        self.db.close()

    def test_concurrent_duplicate_submission_creates_one_attempt(self):
        submission_id = f"concurrent-{uuid.uuid4().hex}"
        ready = Barrier(2, timeout=10)
        original_score = academy._score_db_quiz

        def synchronized_score(db, quiz, answers):
            result = original_score(db, quiz, answers)
            ready.wait()
            return result

        def submit(answer):
            with self.Session() as db:
                db.execute(
                    text("SET LOCAL lock_timeout = '10s'")
                )
                backend_pid = db.execute(
                    text("SELECT pg_backend_pid()")
                ).scalar_one()
                actor = db.get(User, self.user_id)

                result = academy.submit_quiz(
                    str(self.quiz_id),
                    AcademyQuizSubmit(
                        answers=[answer],
                        client_submission_id=submission_id,
                    ),
                    db,
                    actor,
                )
                return backend_pid, result

        with patch.object(
            academy,
            "_score_db_quiz",
            side_effect=synchronized_score,
        ):
            with ThreadPoolExecutor(max_workers=2) as pool:
                results = list(pool.map(submit, (1, 0)))

        backend_pids = {pid for pid, _ in results}
        responses = [response for _, response in results]

        self.assertEqual(len(backend_pids), 2)
        self.assertEqual(responses[0], responses[1])

        self.db.expire_all()

        attempts = (
            self.db.query(AcademyQuizAttempt)
            .filter(
                AcademyQuizAttempt.user_id == self.user_id,
                AcademyQuizAttempt.client_submission_id
                == submission_id,
            )
            .all()
        )

        self.assertEqual(len(attempts), 1)
        self.assertEqual(attempts[0].attempt_number, 1)
        self.assertEqual(attempts[0].result_payload, responses[0])
        self.assertEqual(responses[0]["attempt_number"], 1)


if __name__ == "__main__":
    unittest.main()