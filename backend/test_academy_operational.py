import os
os.environ.setdefault('DATABASE_URL', 'sqlite://')
os.environ.setdefault('SECRET_KEY', 'academy-test-secret')
os.environ.setdefault('APP_ENV', 'test')
import unittest
import tempfile, subprocess, sys
import uuid
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from fastapi import HTTPException
import app.models.base
from app.db.database import Base
from app.models.academy import AcademyCourse, AcademyLesson, AcademyQuiz, AcademyProgress
from app.models.user import User
from app.api.routes import academy
from app.services.academy_curriculum import COURSES, seed_curriculum

class AcademyOperationalTests(unittest.TestCase):
 def setUp(self):
  self.engine=create_engine('sqlite://')
  Base.metadata.create_all(self.engine)
  self.db=Session(self.engine,autoflush=False)
  self.user=User(first_name='Test',last_name='Academy',email='academy@example.test',password_hash='unused',status='active',is_active=True,email_verified=True)
  self.db.add(self.user);self.db.flush()
  seed_curriculum(self.db);self.db.commit()
 def tearDown(self):
  self.db.close();self.engine.dispose()
 def test_catalog_has_real_ids_assessments_and_user_progress(self):
  courses=academy.list_courses(db=self.db,current_user=self.user)
  self.assertEqual(len(courses),len(COURSES))
  for c in courses:
   uuid.UUID(c['id']);uuid.UUID(c['quiz']['id'])
   self.assertTrue(c['lessons'])
   for l in c['lessons']:uuid.UUID(l['id'])
  lesson=academy._lesson_or_404(self.db,'l1')
  self.db.add(AcademyProgress(user_id=self.user.id,course_id=lesson.course_id,lesson_id=lesson.id,status='completed'))
  self.db.commit()
  course=next(c for c in academy.list_courses(db=self.db,current_user=self.user) if c['id']==str(lesson.course_id))
  row=next(l for l in course['lessons'] if l['id']==str(lesson.id))
  self.assertTrue(row['started']);self.assertTrue(row['completed'])
  self.assertEqual(academy.get_my_progress(db=self.db,current_user=self.user)['completed_lessons'],1)
  other=User(first_name='Other',last_name='Member',email='other@example.test',password_hash='unused',status='active',is_active=True,email_verified=True)
  self.db.add(other);self.db.flush()
  self.assertFalse(academy._course_payload(self.db,self.db.get(AcademyCourse,lesson.course_id),other.id)['lessons'][0]['completed'])
 def test_seed_preserves_edits_and_creates_idempotent_quizzes(self):
  lesson=self.db.query(AcademyLesson).first();lesson.content='Administrator content stays'
  self.db.commit()
  self.assertEqual(seed_curriculum(self.db),0)
  self.assertEqual(self.db.query(AcademyQuiz).count(),len(COURSES))
  self.assertEqual(lesson.content,'Administrator content stays')
 def test_upgrade_keeps_lesson_and_question_ids_and_preserves_custom_edits(self):
  from app.services.academy_curriculum import LEGACY_CONTENT, _legacy_items
  from app.models.academy import AcademyQuestion
  course=self.db.query(AcademyCourse).filter(AcademyCourse.title=='Découvrir Enactus').one()
  lesson=self.db.query(AcademyLesson).filter(AcademyLesson.course_id==course.id).order_by(AcademyLesson.order_index).first()
  original_id=lesson.id
  lesson.content=LEGACY_CONTENT[(course.title,lesson.title)]
  quiz=self.db.query(AcademyQuiz).filter(AcademyQuiz.course_id==course.id).one()
  questions=self.db.query(AcademyQuestion).filter(AcademyQuestion.quiz_id==quiz.id).order_by(AcademyQuestion.order_index).all()
  ids=[q.id for q in questions]
  for q,(prompt,choices,answer) in zip(questions,_legacy_items(course.title)):
   q.prompt=prompt;q.choices=choices;q.correct_answers=[answer];q.explanation=choices[answer]
  self.db.commit();seed_curriculum(self.db);self.db.commit()
  self.assertEqual(lesson.id,original_id);self.assertGreaterEqual(len(lesson.content.split()),280)
  self.assertEqual([q.id for q in questions],ids)
  self.assertNotIn('Quel repère correspond',questions[0].prompt)
  self.assertEqual([q.correct_answers for q in questions],[[0],[1],[2]])
  questions[0].prompt='Question personnalisée';lesson.content='Leçon personnalisée'
  self.db.commit();seed_curriculum(self.db);self.db.commit()
  self.assertEqual(questions[0].prompt,'Question personnalisée');self.assertEqual(lesson.content,'Leçon personnalisée')
 def test_complete_lesson_accepts_database_uuid_and_is_idempotent(self):
  lesson=self.db.query(AcademyLesson).first()
  academy.start_lesson(str(lesson.id), db=self.db, current_user=self.user)
  completed=academy.complete_lesson(str(lesson.id), db=self.db, current_user=self.user)
  self.assertEqual(completed.status, 'completed')
  again=academy.complete_lesson(str(lesson.id), db=self.db, current_user=self.user)
  self.assertEqual(again.id, completed.id)
  self.assertEqual(self.db.query(AcademyProgress).filter(AcademyProgress.lesson_id==lesson.id).count(), 1)
  self.assertEqual(academy.get_my_progress(db=self.db,current_user=self.user)['completed_lessons'],1)
 def test_new_enacteur_path_is_available_even_to_admin(self):
  from unittest.mock import patch
  with patch.object(academy,'get_user_role_names', return_value={'admin'}):
   paths=academy.get_my_academy_paths(db=self.db,current_user=self.user)
  path=next(p for p in paths if p['id']=='new-enacteur')
  self.assertEqual(len(path['course_ids']),7)
  self.assertTrue(all(self.db.get(AcademyCourse,uuid.UUID(value)) is not None for value in path['course_ids']))
 def test_bad_legacy_or_unknown_ids_are_404(self):
  for value in ['l999','bad-course','not-a-uuid']:
   with self.assertRaises(HTTPException) as result:academy._lesson_or_404(self.db,value)
   self.assertEqual(result.exception.status_code,404)
  self.assertEqual(academy._resolve_quiz_id(self.db,'discover-enactus-quiz'), str(self.db.query(AcademyQuiz).join(AcademyCourse).filter(AcademyCourse.title=='Découvrir Enactus').first().id))
 def test_no_invented_year_for_undated_minutes_and_memorial(self):
  from app.services.club_voices import MINUTES,HOMMAGE
  self.assertEqual(len({m['id'] for m in MINUTES}),len(MINUTES))
  # Preserve the original archive baseline while allowing new contributions.
  self.assertGreaterEqual(len(MINUTES),29)
  self.assertIsNone(HOMMAGE['year'])
  self.assertTrue(all(m['year'] == 2020 for m in MINUTES[:6]))
  self.assertTrue(all(m['source_label'] == 'Archives Enactus ESP' for m in MINUTES if m['spoken_on']))


class AcademySeedCommandTests(unittest.TestCase):
 def test_standalone_seed_command_registers_all_models(self):
  with tempfile.TemporaryDirectory() as directory:
   url='sqlite:///'+directory+'/academy.db'
   engine=create_engine(url);Base.metadata.create_all(engine);engine.dispose()
   environment=dict(os.environ,DATABASE_URL=url)
   first=subprocess.run([sys.executable,'-m','app.services.academy_curriculum'],env=environment,capture_output=True,text=True)
   self.assertEqual(first.returncode,0,first.stderr)
   second=subprocess.run([sys.executable,'-m','app.services.academy_curriculum'],env=environment,capture_output=True,text=True)
   self.assertEqual(second.returncode,0,second.stderr)
   self.assertIn('0 cours',second.stdout)
