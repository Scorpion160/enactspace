"""Learning prerequisites use course IDs and server-confirmed achievements."""
import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.academy import (
    AcademyCourse, AcademyLesson, AcademyProgress, AcademyQuiz, AcademyQuizAttempt,
)

# Branches let members advance coherently without requiring unrelated topics.
DEFAULT_PREREQUISITES = {
    "Premiers pas dans EnactSpace": ["Découvrir Enactus"],
    "Histoire d'Enactus ESP": ["Premiers pas dans EnactSpace"],
    "Travail d'équipe et transmission": ["Histoire d'Enactus ESP"],
    "Entrepreneuriat social : de l’idée à l’impact": ["Travail d'équipe et transmission"],
    "Immersion : écouter avant d’agir": ["Entrepreneuriat social : de l’idée à l’impact"],
    "Comprendre les ODD": ["Immersion : écouter avant d’agir"],
    "Social business avec Muhammad Yunus": ["Entrepreneuriat social : de l’idée à l’impact"],
    "Enquête terrain": ["Immersion : écouter avant d’agir"],
    "Ciblage : choisir avec qui agir": ["Enquête terrain"],
    "Brainstorming et idéation : ouvrir le champ": ["Ciblage : choisir avec qui agir"],
    "Design thinking : du terrain au prototype": ["Brainstorming et idéation : ouvrir le champ"],
    "Concevoir et tester une solution": ["Design thinking : du terrain au prototype"],
    "Mesurer les résultats": ["Comprendre les ODD", "Concevoir et tester une solution"],
    "Modèle économique et pérennité": ["Social business avec Muhammad Yunus", "Concevoir et tester une solution"],
    "Présenter un projet": ["Mesurer les résultats", "Modèle économique et pérennité"],
    "Apprendre des projets précédents": ["Histoire d'Enactus ESP"],
    "Vivre et transmettre Enactus ESP": ["Travail d'équipe et transmission"],
    "Étude de cas : Dimbali": ["Entrepreneuriat social : de l’idée à l’impact"],
    "Étude de cas : Deconaane": ["Entrepreneuriat social : de l’idée à l’impact"],
    "Étude de cas : SunCuiz et Ville Light": ["Histoire d'Enactus ESP"],
    "Étude de cas : Mën Nañ": ["Entrepreneuriat social : de l’idée à l’impact"],
    "Étude de cas : Aquatus": ["Concevoir et tester une solution"],
    "Études de terrain : Terrasen et SHERY": ["Immersion : écouter avant d’agir"],
}


def seed_prerequisites(db: Session) -> None:
    courses = db.query(AcademyCourse).all()
    by_title = {course.title: course for course in courses}
    for course in courses:
        # [] is an explicit administrator choice; None means legacy unconfigured.
        if course.prerequisite_course_ids is None:
            course.prerequisite_course_ids = [
                str(by_title[title].id)
                for title in DEFAULT_PREREQUISITES.get(course.title, [])
                if title in by_title
            ]


def validate_prerequisites(db: Session, values, course_id=None) -> list[str]:
    if values is None:
        raise HTTPException(400, "Choisissez les prérequis ou une liste vide pour un accès libre.")
    ids = list(dict.fromkeys(str(value) for value in values))
    own = str(course_id) if course_id else None
    graph = {str(course.id): list(course.prerequisite_course_ids or [])
             for course in db.query(AcademyCourse).all()}
    for value in ids:
        if value == own:
            raise HTTPException(400, "Une formation ne peut pas être son propre prérequis.")
        if value not in graph:
            raise HTTPException(400, "Une formation prérequise est introuvable.")
    if own:
        graph[own] = ids
        def visit(node, chain):
            if node in chain:
                raise HTTPException(400, "Ces prérequis créeraient un parcours circulaire.")
            for parent in graph.get(node, []):
                visit(parent, chain | {node})
        visit(own, set())
    return ids


class LearningAccess:
    """Read progress once per request so the catalogue does not issue N² queries."""
    def __init__(self, db: Session, user_id):
        self.courses = {str(c.id): c for c in db.query(AcademyCourse).all()}
        self.lessons = {}
        for lesson in db.query(AcademyLesson).filter(AcademyLesson.is_published.is_(True)).all():
            self.lessons.setdefault(str(lesson.course_id), set()).add(str(lesson.id))
        self.done = set()
        self.started = set()
        for progress in db.query(AcademyProgress).filter(AcademyProgress.user_id == user_id).all():
            if progress.status in {"in_progress", "completed", "validated"}:
                self.started.add(str(progress.course_id))
            if progress.status in {"completed", "validated"}:
                self.done.add(str(progress.lesson_id))
        self.quizzes = {}
        for quiz in db.query(AcademyQuiz).filter(AcademyQuiz.is_published.is_(True)).all():
            if quiz.course_id:
                self.quizzes.setdefault(str(quiz.course_id), set()).add(str(quiz.id))
        self.passed = {str(row[0]) for row in db.query(AcademyQuizAttempt.quiz_id).filter(
            AcademyQuizAttempt.user_id == user_id, AcademyQuizAttempt.passed.is_(True)).all()}
        self.previous_attempts = {str(row[0]) for row in db.query(AcademyQuiz.course_id).join(
            AcademyQuizAttempt, AcademyQuizAttempt.quiz_id == AcademyQuiz.id).filter(
            AcademyQuizAttempt.user_id == user_id).all() if row[0]}

    def lessons_complete(self, course_id) -> bool:
        lessons = self.lessons.get(str(course_id), set())
        return bool(lessons) and lessons.issubset(self.done)

    def mastered(self, course_id) -> bool:
        quizzes = self.quizzes.get(str(course_id), set())
        return self.lessons_complete(course_id) and (not quizzes or quizzes.issubset(self.passed))

    def describe(self, course: AcademyCourse) -> dict:
        prerequisites = []
        for value in course.prerequisite_course_ids or []:
            parent = self.courses.get(str(value))
            complete = bool(parent and self.mastered(parent.id))
            prerequisites.append({
                "id": str(value), "title": parent.title if parent else "Formation indisponible",
                "completed": complete,
                "available": bool(parent and parent.is_published and not parent.is_archived),
            })
        # Existing learning remains available when prerequisites are introduced.
        acquired_access = str(course.id) in self.started or str(course.id) in self.previous_attempts
        missing = [item["title"] for item in prerequisites if not item["completed"]]
        locked = bool(missing) and not acquired_access
        return {
            "prerequisite_course_ids": list(course.prerequisite_course_ids or []),
            "prerequisites": prerequisites,
            "is_locked": locked,
            "lock_reason": "Termine les leçons et réussis le quiz de : " + ", ".join(missing) if locked else "",
            "is_mastered": self.mastered(course.id),
        }


def require_learning_access(db: Session, user_id, course_id) -> AcademyCourse:
    course = db.get(AcademyCourse, uuid.UUID(str(course_id)))
    if not course or not course.is_published or course.is_archived:
        raise HTTPException(404, "Formation indisponible.")
    access = LearningAccess(db, user_id).describe(course)
    if access["is_locked"]:
        raise HTTPException(403, access["lock_reason"])
    return course


def require_quiz_access(db: Session, user_id, quiz: AcademyQuiz) -> None:
    if quiz.course_id is None:
        return
    require_learning_access(db, user_id, quiz.course_id)
    access = LearningAccess(db, user_id)
    if access.lessons.get(str(quiz.course_id)) and not access.lessons_complete(quiz.course_id):
        raise HTTPException(403, "Termine toutes les leçons de cette formation avant d’ouvrir son quiz.")
