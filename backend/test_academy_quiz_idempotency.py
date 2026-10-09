"""Focused Academy quiz idempotency regressions."""

import os
import unittest
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "academy-idempotency-test-secret")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.routes import academy
from app.db.database import Base
from app.models.academy import (
    AcademyQuestion,
    AcademyQuiz,
    AcademyQuizAttempt,
)
from app.models.user import User
from app.schemas.academy import AcademyQuizSubmit


class AcademyQuizIdempotencyTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(
            bind=self.engine,
            autoflush=False,
        )
        self.db = self.Session()

        self.user = User(
            first_name="Academy",
            last_name="Member",
            email=f"academy-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(self.user)
        self.db.flush()

        self.quiz = AcademyQuiz(
            title="Offline Academy test",
            description="Quiz used to verify idempotent submissions.",
            passing_score=60,
            time_limit_minutes=8,
            allow_retake=True,
            is_published=True,
            created_by_id=self.user.id,
        )
        self.db.add(self.quiz)
        self.db.flush()

        self.question = AcademyQuestion(
            quiz_id=self.quiz.id,
            question_type="single_choice",
            prompt="Which answer is correct?",
            choices=["Correct", "Incorrect"],
            correct_answers=[0],
            points=1,
            order_index=0,
        )
        self.db.add(self.question)
        self.db.commit()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def test_repeated_client_submission_returns_original_result(self):
        submission_id = f"offline-quiz-{uuid.uuid4().hex}"

        first = academy.submit_quiz(
            str(self.quiz.id),
            AcademyQuizSubmit(
                answers=[1],
                client_submission_id=submission_id,
            ),
            self.db,
            self.user,
        )

        second = academy.submit_quiz(
            str(self.quiz.id),
            AcademyQuizSubmit(
                answers=[0],
                client_submission_id=submission_id,
            ),
            self.db,
            self.user,
        )

        attempts = (
            self.db.query(AcademyQuizAttempt)
            .filter(
                AcademyQuizAttempt.user_id == self.user.id,
                AcademyQuizAttempt.client_submission_id
                == submission_id,
            )
            .all()
        )

        self.assertEqual(first, second)
        self.assertEqual(len(attempts), 1)
        self.assertEqual(first["attempt_number"], 1)
        self.assertEqual(attempts[0].attempt_number, 1)
        self.assertEqual(attempts[0].answers, [1])
        self.assertEqual(attempts[0].result_payload, first)

    def test_same_identifier_is_scoped_to_user(self):
        second_user = User(
            first_name="Second",
            last_name="Member",
            email=f"academy-second-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(second_user)
        self.db.commit()

        submission_id = f"shared-device-{uuid.uuid4().hex}"

        academy.submit_quiz(
            str(self.quiz.id),
            AcademyQuizSubmit(
                answers=[1],
                client_submission_id=submission_id,
            ),
            self.db,
            self.user,
        )

        academy.submit_quiz(
            str(self.quiz.id),
            AcademyQuizSubmit(
                answers=[1],
                client_submission_id=submission_id,
            ),
            self.db,
            second_user,
        )

        attempts = (
            self.db.query(AcademyQuizAttempt)
            .filter(
                AcademyQuizAttempt.client_submission_id
                == submission_id,
            )
            .all()
        )

        self.assertEqual(len(attempts), 2)
        self.assertEqual(
            {attempt.user_id for attempt in attempts},
            {self.user.id, second_user.id},
        )


if __name__ == "__main__":
    unittest.main()