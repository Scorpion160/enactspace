"""Prerequisites cannot be bypassed through lesson or quiz endpoints."""
import os
os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "academy-progression-test")
os.environ.setdefault("APP_ENV", "test")
import unittest
import uuid
from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
import app.models.base
from app.db.database import Base
from app.models.academy import AcademyCourse, AcademyLesson, AcademyProgress, AcademyQuiz, AcademyQuizAttempt
from app.models.user import User
from app.schemas.academy import AcademyCourseUpdate, AcademyQuizSubmit
from app.api.routes import academy
from app.services.academy_curriculum import seed_curriculum
from app.services.academy_progression import LearningAccess, validate_prerequisites


class AcademyProgressionTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite://")
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine, autoflush=False)
        self.user = User(first_name="Learning", last_name="Member", email="learning@example.test",
            password_hash="unused", status="active", is_active=True, email_verified=True)
        self.db.add(self.user)
        seed_curriculum(self.db)
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def course(self, title):
        return self.db.query(AcademyCourse).filter(AcademyCourse.title == title).one()

    def lessons(self, course):
        return self.db.query(AcademyLesson).filter(AcademyLesson.course_id == course.id).order_by(AcademyLesson.order_index).all()

    def quiz(self, course):
        return self.db.query(AcademyQuiz).filter(AcademyQuiz.course_id == course.id).one()

    def finish(self, course):
        for lesson in self.lessons(course):
            academy.complete_lesson(str(lesson.id), db=self.db, current_user=self.user)

    def passed(self, course):
        quiz = self.quiz(course)
        from app.models.academy import AcademyQuestion
        questions = self.db.query(AcademyQuestion).filter(AcademyQuestion.quiz_id == quiz.id).order_by(AcademyQuestion.order_index).all()
        return academy.submit_quiz(str(quiz.id), AcademyQuizSubmit(answers=[q.correct_answers[0] for q in questions]), db=self.db, current_user=self.user)

    def test_fresh_catalogue_has_one_entry_point_and_hides_locked_content(self):
        rows = academy.list_courses(db=self.db, current_user=self.user)
        self.assertEqual([c["title"] for c in rows if not c["is_locked"]], ["Découvrir Enactus"])
        for course in rows:
            if course["is_locked"]:
                self.assertTrue(course["lock_reason"])
                self.assertTrue(course["prerequisites"])
                for lesson in course["lessons"]:
                    self.assertIsNone(lesson["content"])
                    self.assertIsNone(lesson["external_url"])

    def test_locked_course_rejects_direct_start_complete_and_quiz_requests(self):
        course = self.course("Premiers pas dans EnactSpace")
        lesson = self.lessons(course)[0]
        quiz = self.quiz(course)
        calls = [
            lambda: academy.start_lesson(str(lesson.id), db=self.db, current_user=self.user),
            lambda: academy.complete_lesson(str(lesson.id), db=self.db, current_user=self.user),
            lambda: academy.get_quiz(str(quiz.id), db=self.db, current_user=self.user),
            lambda: academy.submit_quiz(str(quiz.id), AcademyQuizSubmit(answers=[0,1,2]), db=self.db, current_user=self.user),
        ]
        for call in calls:
            with self.assertRaises(HTTPException) as result:
                call()
            self.assertEqual(result.exception.status_code, 403)
        self.assertEqual(self.db.query(AcademyProgress).count(), 0)
        self.assertEqual(self.db.query(AcademyQuizAttempt).count(), 0)

    def test_lessons_alone_do_not_unlock_next_course_and_success_does(self):
        first = self.course("Découvrir Enactus")
        next_course = self.course("Premiers pas dans EnactSpace")
        self.finish(first)
        self.assertTrue(LearningAccess(self.db,self.user.id).describe(next_course)["is_locked"])
        self.assertFalse(LearningAccess(self.db,self.user.id).mastered(first.id))
        self.assertTrue(self.passed(first)["passed"])
        self.assertTrue(LearningAccess(self.db,self.user.id).mastered(first.id))
        row = academy._course_payload(self.db,next_course,self.user.id)
        self.assertFalse(row["is_locked"])
        self.assertTrue(row["lessons"][0]["content"])
        academy.start_lesson(str(self.lessons(next_course)[0].id), db=self.db, current_user=self.user)

    def test_failed_quiz_keeps_next_course_locked_then_retake_unlocks(self):
        course = self.course("Découvrir Enactus")
        self.finish(course)
        failed = academy.submit_quiz(str(self.quiz(course).id), AcademyQuizSubmit(answers=[-1,-1,-1]), db=self.db, current_user=self.user)
        self.assertFalse(failed["passed"])
        self.assertTrue(LearningAccess(self.db,self.user.id).describe(self.course("Premiers pas dans EnactSpace"))["is_locked"])
        self.assertTrue(self.passed(course)["passed"])

    def test_course_quiz_waits_for_all_lessons(self):
        course = self.course("Découvrir Enactus")
        with self.assertRaises(HTTPException) as result:
            academy.get_quiz(str(self.quiz(course).id),db=self.db,current_user=self.user)
        self.assertEqual(result.exception.status_code,403)
        academy.complete_lesson(str(self.lessons(course)[0].id),db=self.db,current_user=self.user)
        with self.assertRaises(HTTPException):
            academy.submit_quiz(str(self.quiz(course).id),AcademyQuizSubmit(answers=[0,1,2]),db=self.db,current_user=self.user)

    def test_progress_does_not_unlock_another_members_courses(self):
        self.finish(self.course("Découvrir Enactus"))
        self.passed(self.course("Découvrir Enactus"))
        other = User(first_name="Other",last_name="Member",email="other@example.test",password_hash="unused")
        self.db.add(other);self.db.flush()
        self.assertTrue(LearningAccess(self.db,other.id).describe(self.course("Premiers pas dans EnactSpace"))["is_locked"])

    def test_prior_learning_remains_accessible_without_unlocking_further_courses(self):
        course=self.course("Concevoir et tester une solution")
        lesson=self.lessons(course)[0]
        self.db.add(AcademyProgress(user_id=self.user.id,course_id=course.id,lesson_id=lesson.id,status="in_progress"))
        self.db.commit()
        self.assertFalse(LearningAccess(self.db,self.user.id).describe(course)["is_locked"])
        academy.complete_lesson(str(lesson.id),db=self.db,current_user=self.user)
        self.assertTrue(LearningAccess(self.db,self.user.id).describe(self.course("Mesurer les résultats"))["is_locked"])

    def test_admin_can_choose_prerequisites_and_cannot_create_cycles(self):
        first=self.course("Découvrir Enactus")
        second=self.course("Premiers pas dans EnactSpace")
        for ids in [[first.id],[second.id],[uuid.uuid4()]]:
            with self.assertRaises(HTTPException):
                validate_prerequisites(self.db,ids,first.id)
        updated=academy.update_course(str(second.id),AcademyCourseUpdate(prerequisite_course_ids=[]),db=self.db,current_user=self.user)
        self.assertEqual(updated.prerequisite_course_ids,[])
        seed_curriculum(self.db);self.db.commit()
        self.assertEqual(updated.prerequisite_course_ids,[])

    def test_renaming_preserves_id_based_dependency(self):
        first=self.course("Découvrir Enactus")
        second=self.course("Premiers pas dans EnactSpace")
        first.title="Les fondations du club";self.db.commit()
        access=LearningAccess(self.db,self.user.id).describe(second)
        self.assertTrue(access["is_locked"])
        self.assertEqual(access["prerequisites"][0]["title"],first.title)

    def test_archived_course_and_unpublished_lessons_cannot_be_completed(self):
        course=self.course("Découvrir Enactus")
        lesson=self.lessons(course)[0]
        course.is_archived=True;self.db.commit()
        with self.assertRaises(HTTPException) as result:
            academy.complete_lesson(str(lesson.id),db=self.db,current_user=self.user)
        self.assertEqual(result.exception.status_code,404)
        course.is_archived=False;lesson.is_published=False;self.db.commit()
        with self.assertRaises(HTTPException):
            academy.start_lesson(str(lesson.id),db=self.db,current_user=self.user)

    def test_each_seeded_prerequisite_is_real_and_graph_is_acyclic(self):
        for course in self.db.query(AcademyCourse).all():
            ids=validate_prerequisites(self.db,course.prerequisite_course_ids,course.id)
            self.assertEqual(ids,course.prerequisite_course_ids)


if __name__ == "__main__":
    unittest.main()
