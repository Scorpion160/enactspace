import unittest
from sqlalchemy import create_engine, select
from sqlalchemy.orm import Session

from app.db.database import Base
import app.models.base  # Register all foreign key tables.
from app.models.academy import AcademyCourse, AcademyLesson
from app.services.academy_curriculum import COURSES, seed_curriculum


class AcademyCurriculumTests(unittest.TestCase):
    def test_seed_is_idempotent_and_lessons_have_substance(self):
        engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(engine)
        with Session(engine) as db:
            with db.begin():
                first = seed_curriculum(db)
            with db.begin():
                second = seed_curriculum(db)
            courses = db.scalars(select(AcademyCourse)).all()
            lessons = db.scalars(select(AcademyLesson)).all()
            self.assertEqual(first, len(COURSES) + len(lessons))
            self.assertEqual(second, 0)
            self.assertEqual(len(courses), len(COURSES))
            self.assertEqual(len(lessons), sum(len(course[3]) for course in COURSES))
            self.assertTrue(all(course.is_published for course in courses))
            self.assertTrue(all(lesson.content and len(lesson.content.split()) >= 280 for lesson in lessons))
            self.assertIn("Histoire d'Enactus ESP", {course.title for course in courses})
            self.assertIn("Étude de cas : Dimbali", {course.title for course in courses})
            self.assertTrue(all("PV du" not in lesson.content and "mémoire institutionnelle" not in lesson.content.lower() for lesson in lessons))
            self.assertTrue(all(lesson.duration_minutes >= 7 for lesson in lessons))
            self.assertIn("Premiers pas dans EnactSpace", {course.title for course in courses})
        engine.dispose()


if __name__ == "__main__":
    unittest.main()
