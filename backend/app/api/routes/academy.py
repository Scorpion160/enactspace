from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, require_enacchef_or_admin
from app.db.database import get_db
from app.models.academy import AcademyCourse, AcademyLesson
from app.schemas.academy import (
    AcademyCourseCreate,
    AcademyCourseRead,
    AcademyCourseUpdate,
    AcademyLessonCreate,
    AcademyLessonRead,
    AcademyLessonUpdate,
)
from app.services.notification_service import notify_user


router = APIRouter(prefix="/academy", tags=["Academy"])


COURSES = [
    {
        "id": "discover-enactus",
        "title": "Découvrir Enactus",
        "category": "Culture Enactus",
        "level": "Débutant",
        "description": "Mission, vision, esprit Enactus ESP et rôle d’un Enacteur.",
        "duration_minutes": 25,
        "points": 180,
        "lessons": [
            {
                "id": "l1",
                "title": "Qu’est-ce que Enactus ?",
                "summary": "Comprendre l’entrepreneuriat social par l’action.",
                "duration_minutes": 8,
            },
            {
                "id": "l2",
                "title": "People, Planet, Prosperity",
                "summary": "Lire un projet avec les trois piliers Enactus.",
                "duration_minutes": 10,
            },
            {
                "id": "l3",
                "title": "Rôles dans Enactus ESP",
                "summary": "Enacteur, EnacChef, alumni, advisor et partenaires.",
                "duration_minutes": 7,
            },
        ],
        "quiz": {
            "id": "discover-enactus-quiz",
            "title": "Les bases de Enactus",
            "category": "Culture Enactus",
            "level": "Débutant",
            "time_limit_minutes": 8,
            "questions": [
                {
                    "question": "Quel est le cœur de l’approche Enactus ?",
                    "choices": [
                        "Entrepreneuriat social",
                        "Simple bénévolat",
                        "Compétition uniquement",
                        "Gestion administrative",
                    ],
                    "correct_index": 0,
                    "explanation": "Enactus combine leadership entrepreneurial et impact positif durable.",
                }
            ],
        },
    },
    {
        "id": "sdgs-impact",
        "title": "ODD et mesure d’impact",
        "category": "Impact",
        "level": "Intermédiaire",
        "description": "Relier un problème aux ODD, distinguer reach, impact direct et indirect.",
        "duration_minutes": 39,
        "points": 180,
        "lessons": [
            {
                "id": "l4",
                "title": "ODD / SDGs",
                "summary": "Choisir les ODD pertinents sans forcer l’alignement.",
                "duration_minutes": 12,
            },
            {
                "id": "l5",
                "title": "Direct impact vs indirect impact",
                "summary": "Mesurer ce qui change réellement pour les bénéficiaires.",
                "duration_minutes": 14,
            },
            {
                "id": "l6",
                "title": "Preuves et méthodologie",
                "summary": "Structurer photos, enquêtes, registres et hypothèses.",
                "duration_minutes": 13,
            },
        ],
        "quiz": {
            "id": "sdgs-impact-quiz",
            "title": "Impact direct ou indirect ?",
            "category": "Impact",
            "level": "Intermédiaire",
            "time_limit_minutes": 8,
            "questions": [
                {
                    "question": "Le reach mesure surtout...",
                    "choices": [
                        "Les personnes touchées ou exposées",
                        "Le profit net",
                        "Les dépenses",
                        "Le nombre de réunions",
                    ],
                    "correct_index": 0,
                    "explanation": "Le reach est la portée. Il ne remplace pas la mesure d’impact.",
                }
            ],
        },
    },
]

VALID_COURSE_LEVELS = {"debutant", "intermediaire", "avance", "responsable"}
VALID_LESSON_TYPES = {"texte", "video", "document", "quiz", "activite"}


def _normalize_level(value: str) -> str:
    level = (value or "debutant").strip().lower()
    level = level.replace("é", "e").replace("è", "e").replace("ç", "c")
    if level not in VALID_COURSE_LEVELS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Niveau de formation invalide",
        )
    return level


def _normalize_lesson_type(value: str) -> str:
    lesson_type = (value or "texte").strip().lower()
    lesson_type = lesson_type.replace("é", "e").replace("è", "e")
    if lesson_type not in VALID_LESSON_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de lecon invalide",
        )
    return lesson_type


def _course_or_404(db: Session, course_id: str) -> AcademyCourse:
    course = db.query(AcademyCourse).filter(AcademyCourse.id == course_id).first()
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Formation introuvable",
        )
    return course


def _lesson_or_404(db: Session, lesson_id: str) -> AcademyLesson:
    lesson = db.query(AcademyLesson).filter(AcademyLesson.id == lesson_id).first()
    if not lesson:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Lecon introuvable",
        )
    return lesson


def _lesson_payload(lesson: AcademyLesson) -> dict:
    return {
        "id": str(lesson.id),
        "title": lesson.title,
        "summary": lesson.summary or "",
        "duration_minutes": int(lesson.duration_minutes or 0),
        "lesson_type": lesson.lesson_type,
        "completed": False,
        "has_resource": lesson.resource_file_id is not None
        or bool((lesson.external_url or "").strip()),
    }


def _course_payload(db: Session, course: AcademyCourse) -> dict:
    lessons = (
        db.query(AcademyLesson)
        .filter(AcademyLesson.course_id == course.id)
        .filter(AcademyLesson.is_published.is_(True))
        .order_by(AcademyLesson.order_index.asc(), AcademyLesson.created_at.asc())
        .all()
    )
    duration = int(course.estimated_duration_minutes or 0)
    if duration <= 0:
        duration = sum(int(lesson.duration_minutes or 0) for lesson in lessons)

    return {
        "id": str(course.id),
        "title": course.title,
        "category": course.category,
        "level": course.level,
        "description": course.description or "",
        "duration_minutes": duration,
        "points": int(course.points or len(lessons) * 40),
        "is_required": bool(course.is_required),
        "target_roles": course.target_roles or [],
        "lessons": [_lesson_payload(lesson) for lesson in lessons],
        "quiz": {
            "id": f"{course.id}-quiz",
            "title": f"Quiz - {course.title}",
            "category": course.category,
            "level": course.level,
            "time_limit_minutes": 8,
            "questions": [],
        },
    }


@router.get("/courses")
def list_courses(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    published_courses = (
        db.query(AcademyCourse)
        .filter(
            AcademyCourse.is_published.is_(True),
            AcademyCourse.is_archived.is_(False),
        )
        .order_by(AcademyCourse.updated_at.desc())
        .all()
    )
    return [_course_payload(db, course) for course in published_courses] + COURSES


@router.get("/admin/courses", response_model=list[AcademyCourseRead])
def list_admin_courses(
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    return db.query(AcademyCourse).order_by(AcademyCourse.updated_at.desc()).all()


@router.post("/admin/courses", response_model=AcademyCourseRead)
def create_course(
    payload: AcademyCourseCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    data = payload.model_dump()
    data["level"] = _normalize_level(payload.level)
    course = AcademyCourse(**data, created_by_id=current_user.id)
    db.add(course)
    db.commit()
    db.refresh(course)
    return course


@router.patch("/admin/courses/{course_id}", response_model=AcademyCourseRead)
def update_course(
    course_id: str,
    payload: AcademyCourseUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    course = _course_or_404(db, course_id)
    data = payload.model_dump(exclude_unset=True)
    if "level" in data:
        data["level"] = _normalize_level(data["level"])
    for field, value in data.items():
        setattr(course, field, value)
    course.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(course)
    return course


@router.post("/admin/courses/{course_id}/publish", response_model=AcademyCourseRead)
def publish_course(
    course_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    course = _course_or_404(db, course_id)
    course.is_published = True
    course.is_archived = False
    course.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(course)
    return course


@router.post("/admin/courses/{course_id}/unpublish", response_model=AcademyCourseRead)
def unpublish_course(
    course_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    course = _course_or_404(db, course_id)
    course.is_published = False
    course.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(course)
    return course


@router.post("/admin/courses/{course_id}/archive", response_model=AcademyCourseRead)
def archive_course(
    course_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    course = _course_or_404(db, course_id)
    course.is_archived = True
    course.is_published = False
    course.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(course)
    return course


@router.get(
    "/admin/courses/{course_id}/lessons",
    response_model=list[AcademyLessonRead],
)
def list_course_lessons(
    course_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    _course_or_404(db, course_id)
    return (
        db.query(AcademyLesson)
        .filter(AcademyLesson.course_id == course_id)
        .order_by(AcademyLesson.order_index.asc(), AcademyLesson.created_at.asc())
        .all()
    )


@router.post(
    "/admin/courses/{course_id}/lessons",
    response_model=AcademyLessonRead,
)
def create_lesson(
    course_id: str,
    payload: AcademyLessonCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    course = _course_or_404(db, course_id)
    data = payload.model_dump()
    data["lesson_type"] = _normalize_lesson_type(payload.lesson_type)
    lesson = AcademyLesson(course_id=course.id, **data)
    db.add(lesson)
    course.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(lesson)
    return lesson


@router.patch("/admin/lessons/{lesson_id}", response_model=AcademyLessonRead)
def update_lesson(
    lesson_id: str,
    payload: AcademyLessonUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    lesson = _lesson_or_404(db, lesson_id)
    data = payload.model_dump(exclude_unset=True)
    if "lesson_type" in data:
        data["lesson_type"] = _normalize_lesson_type(data["lesson_type"])
    for field, value in data.items():
        setattr(lesson, field, value)
    lesson.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(lesson)
    return lesson


@router.get("/me/progress")
def get_my_progress(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    db_lessons = (
        db.query(AcademyLesson)
        .join(AcademyCourse, AcademyCourse.id == AcademyLesson.course_id)
        .filter(
            AcademyCourse.is_published.is_(True),
            AcademyCourse.is_archived.is_(False),
            AcademyLesson.is_published.is_(True),
        )
        .count()
    )
    total_lessons = sum(len(course["lessons"]) for course in COURSES) + db_lessons
    db_courses = (
        db.query(AcademyCourse)
        .filter(
            AcademyCourse.is_published.is_(True),
            AcademyCourse.is_archived.is_(False),
        )
        .count()
    )
    return {
        "completed_lessons": 0,
        "total_lessons": total_lessons,
        "passed_quizzes": 0,
        "total_quizzes": len(COURSES) + db_courses,
        "points": 0,
        "rank": 0,
        "monthly_progress": 0,
    }


@router.get("/quizzes/{quiz_id}")
def get_quiz(quiz_id: str, current_user=Depends(get_current_active_validated_user)):
    for course in COURSES:
        if course["quiz"]["id"] == quiz_id:
            return course["quiz"]

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Quiz introuvable",
    )


@router.post("/quizzes/{quiz_id}/submit")
def submit_quiz(
    quiz_id: str,
    payload: dict,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    quiz = get_quiz(quiz_id, current_user=current_user)
    answers = payload.get("answers", [])
    questions = quiz["questions"]
    correct = 0

    for index, question in enumerate(questions):
        answer = answers[index] if index < len(answers) else None
        if answer == question["correct_index"]:
            correct += 1

    score = (correct / len(questions)) * 100 if questions else 0
    passed = score >= 60
    if passed:
        notify_user(
            db,
            user_id=current_user.id,
            title=f"Quiz reussi : {quiz['title']}",
            message=f"Score obtenu : {score:.0f}%.",
            notification_type="quiz_passed",
            related_type="academy_quiz",
            dedupe=True,
        )
        db.commit()

    return {
        "quiz_id": quiz_id,
        "score": score,
        "passed": passed,
        "correct_answers": correct,
        "total_questions": len(questions),
        "points": 60 if passed else 0,
    }
