from app.core.time import utc_now
import csv
import uuid
from datetime import datetime
from io import StringIO

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
    require_enacchef_or_admin,
)
from app.db.database import get_db
from app.models.academy import (
    AcademyCourse,
    AcademyLesson,
    AcademyProgress,
    AcademyQuestion,
    AcademyQuiz,
    AcademyQuizAttempt,
)
from app.schemas.academy import (
    AcademyCourseCreate,
    AcademyCourseRead,
    AcademyCourseUpdate,
    AcademyLessonCreate,
    AcademyLessonRead,
    AcademyLessonUpdate,
    AcademyProgressRead,
    AcademyQuestionCreate,
    AcademyQuestionRead,
    AcademyQuizCreate,
    AcademyQuizRead,
    AcademyQuizSubmit,
)
from app.services.notification_service import notify_user
from app.models.user import User
from app.services.academy_progression import (LearningAccess, require_learning_access,
    require_quiz_access, validate_prerequisites)


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
                "summary": "Enacteur, Enacchef, alumni, advisor et partenaires.",
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

ROLE_BASED_PATHS = {
    "enacteur": {
        "id": "new-enacteur",
        "title": "Nouveau Enacteur",
        "description": (
            "Découvre Enactus ESP, trouve tes repères dans EnactSpace et prépare "
            "ta première contribution avec les bases du travail en équipe et de l’impact."
        ),
        "course_ids": ["discover-enactus", "new-enacteur-tools", "club-history", "teamwork", "social-entrepreneurship", "immersion", "sdgs-impact"],
    },
    "chef_pole": {
        "id": "pole-leader",
        "title": "Chef de pole",
        "description": (
            "Gestion d'equipe, taches, documents, communication interne et reporting."
        ),
        "course_ids": ["leadership-collaboration", "discover-enactus"],
    },
    "adjoint_chef_pole": {
        "id": "pole-deputy",
        "title": "Adjoint chef de pole",
        "description": "Appui operationnel, suivi des taches et passation.",
        "course_ids": ["leadership-collaboration", "discover-enactus"],
    },
    "chef_projet": {
        "id": "project-leader",
        "title": "Chef de projet",
        "description": (
            "Gestion projet, suivi impact, preuves, rapports et preparation competition."
        ),
        "course_ids": ["sdgs-impact", "pitch-competition"],
    },
    "adjoint_chef_projet": {
        "id": "project-deputy",
        "title": "Adjoint chef de projet",
        "description": "Contribution projet, preuves d'impact et reporting.",
        "course_ids": ["sdgs-impact", "pitch-competition"],
    },
    "secretaire_generale": {
        "id": "secretariat",
        "title": "Secretariat General",
        "description": "PV, documents officiels, presences et organisation interne.",
        "course_ids": ["discover-enactus", "leadership-collaboration"],
    },
    "financier": {
        "id": "finance",
        "title": "Financier",
        "description": "Cotisations, paiements, sanctions, recus, exports et validation.",
        "course_ids": ["business-finance", "discover-enactus"],
    },
    "alumni": {
        "id": "alumni",
        "title": "Alumni",
        "description": "Presentation du club, archives autorisees, contribution et mentorat.",
        "course_ids": ["discover-enactus"],
    },
}

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
    try:
        uuid.UUID(str(course_id))
    except (ValueError, TypeError):
        raise HTTPException(status_code=404, detail="Formation introuvable")
    course = db.query(AcademyCourse).filter(AcademyCourse.id == course_id).first()
    if not course:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Formation introuvable",
        )
    return course


def _lesson_or_404(db: Session, lesson_id: str) -> AcademyLesson:
    aliases = {
        "l1": ("Découvrir Enactus", "La démarche Enactus"),
        "l2": ("Découvrir Enactus", "Agir avec les communautés"),
        "l3": ("Découvrir Enactus", "Le rôle de l'enacteur"),
        "l4": ("Comprendre les ODD", "Les 17 objectifs"),
        "l5": ("Comprendre les ODD", "Choisir une cible pertinente"),
        "l6": ("Comprendre les ODD", "Éviter l'affichage d'impact"),
    }
    if lesson_id in aliases:
        title, lesson_title = aliases[lesson_id]
        lesson = (db.query(AcademyLesson).join(AcademyCourse)
                  .filter(AcademyCourse.title == title, AcademyLesson.title == lesson_title,
                          AcademyCourse.is_published.is_(True), AcademyCourse.is_archived.is_(False),
                          AcademyLesson.is_published.is_(True)).first())
        if lesson:
            return lesson
        raise HTTPException(status_code=404, detail="Leçon introuvable")
    try:
        uuid.UUID(str(lesson_id))
    except (ValueError, TypeError):
        raise HTTPException(status_code=404, detail="Leçon introuvable")
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
        "content": lesson.content,
        "resource_file_id": str(lesson.resource_file_id) if lesson.resource_file_id else None,
        "external_url": lesson.external_url,
        "order_index": lesson.order_index,
        "completed": False,
        "has_resource": lesson.resource_file_id is not None
        or bool((lesson.external_url or "").strip()),
    }


def _course_payload(db: Session, course: AcademyCourse, user_id=None, access=None) -> dict:
    access = access or LearningAccess(db, user_id)
    learning = access.describe(course)
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

    progress = {
        str(row.lesson_id): row.status for row in
        db.query(AcademyProgress).filter(AcademyProgress.user_id == user_id,
                                       AcademyProgress.course_id == course.id).all()
    } if user_id is not None else {}
    quiz = (db.query(AcademyQuiz).filter(AcademyQuiz.course_id == course.id,
            AcademyQuiz.is_published.is_(True)).order_by(AcademyQuiz.created_at.asc()).first())
    lesson_rows = []
    for lesson in lessons:
        row = _lesson_payload(lesson)
        state = progress.get(str(lesson.id), 'not_started')
        row.update(status=state, started=state != 'not_started',
                   completed=state in {'completed', 'validated'})
        if learning["is_locked"]:
            row.update(content=None, resource_file_id=None, external_url=None, has_resource=False)
        lesson_rows.append(row)
    quiz_passed = bool(quiz and user_id and db.query(AcademyQuizAttempt.id).filter(
        AcademyQuizAttempt.quiz_id == quiz.id, AcademyQuizAttempt.user_id == user_id,
        AcademyQuizAttempt.passed.is_(True)).first())
    return {
        **learning,
        "quiz_passed": quiz_passed,
        "id": str(course.id),
        "title": course.title,
        "category": course.category,
        "level": course.level,
        "description": course.description or "",
        "duration_minutes": duration,
        "points": int(course.points or 0),
        "is_required": bool(course.is_required),
        "target_roles": course.target_roles or [],
        "lessons": lesson_rows,
        "quiz": {
            "id": str(quiz.id) if quiz else "",
            "title": quiz.title if quiz else "",
            "category": course.category,
            "level": course.level,
            "time_limit_minutes": int(quiz.time_limit_minutes or 8) if quiz else 0,
            "questions": [],
        },
    }


def _quiz_payload(db: Session, quiz: AcademyQuiz, *, include_answers: bool) -> dict:
    questions = (
        db.query(AcademyQuestion)
        .filter(AcademyQuestion.quiz_id == quiz.id)
        .order_by(AcademyQuestion.order_index.asc(), AcademyQuestion.created_at.asc())
        .all()
    )
    course = (
        db.query(AcademyCourse).filter(AcademyCourse.id == quiz.course_id).first()
        if quiz.course_id
        else None
    )
    return {
        "id": str(quiz.id),
        "title": quiz.title,
        "category": course.category if course else "Academy",
        "level": course.level if course else "debutant",
        "time_limit_minutes": int(quiz.time_limit_minutes or 0),
        "passing_score": float(quiz.passing_score or 60),
        "questions": [
            {
                "id": str(question.id),
                "question": question.prompt,
                "question_type": question.question_type,
                "choices": question.choices or [],
                "correct_index": (
                    (question.correct_answers or [0])[0] if include_answers else 0
                ),
                "explanation": question.explanation or "",
            }
            for question in questions
        ],
    }


def _quiz_or_404(db: Session, quiz_id: str) -> AcademyQuiz:
    quiz = db.query(AcademyQuiz).filter(AcademyQuiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Quiz introuvable",
        )
    return quiz


def _score_db_quiz(db: Session, quiz: AcademyQuiz, answers: list) -> dict:
    questions = (
        db.query(AcademyQuestion)
        .filter(AcademyQuestion.quiz_id == quiz.id)
        .order_by(AcademyQuestion.order_index.asc(), AcademyQuestion.created_at.asc())
        .all()
    )
    max_score = sum(float(question.points or 0) for question in questions)
    score = 0.0
    correct = 0
    for index, question in enumerate(questions):
        expected = sorted(int(item) for item in (question.correct_answers or []))
        raw_answer = answers[index] if index < len(answers) else None
        selected = raw_answer if isinstance(raw_answer, list) else [raw_answer]
        selected = sorted(
            int(item)
            for item in selected
            if isinstance(item, int) or str(item).isdigit()
        )
        if selected == expected:
            score += float(question.points or 0)
            correct += 1
    percent = (score / max_score) * 100 if max_score else 0
    return {
        "score": percent,
        "raw_score": score,
        "max_score": max_score,
        "passed": percent >= float(quiz.passing_score or 60),
        "correct_answers": correct,
        "total_questions": len(questions),
        "feedback": [{"question": q.prompt, "correct_indices": q.correct_answers or [],
            "explanation": q.explanation or "", "choices": q.choices or []}
            for q in questions],
    }


def _lesson_progress(
    db: Session,
    *,
    user_id,
    lesson: AcademyLesson,
) -> AcademyProgress:
    progress = (
        db.query(AcademyProgress)
        .filter(
            AcademyProgress.user_id == user_id,
            AcademyProgress.lesson_id == lesson.id,
        )
        .first()
    )
    if progress:
        return progress
    progress = AcademyProgress(
        user_id=user_id,
        course_id=lesson.course_id,
        lesson_id=lesson.id,
        status="not_started",
        progress_percent=0,
    )
    db.add(progress)
    db.flush()
    return progress


def _course_completion_percent(db: Session, *, user_id, course_id) -> float:
    total = (
        db.query(AcademyLesson)
        .filter(
            AcademyLesson.course_id == course_id,
            AcademyLesson.is_published.is_(True),
        )
        .count()
    )
    if total <= 0:
        return 0
    completed = (
        db.query(AcademyProgress)
        .filter(
            AcademyProgress.user_id == user_id,
            AcademyProgress.course_id == course_id,
            AcademyProgress.status.in_(["completed", "validated"]),
        )
        .count()
    )
    return min(100, (completed / total) * 100)


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
    access = LearningAccess(db, current_user.id)
    return [_course_payload(db, course, current_user.id, access) for course in published_courses]


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
    data["prerequisite_course_ids"] = validate_prerequisites(db, payload.prerequisite_course_ids)
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
    if "prerequisite_course_ids" in data:
        data["prerequisite_course_ids"] = validate_prerequisites(db, data["prerequisite_course_ids"], course.id)
    if "level" in data:
        data["level"] = _normalize_level(data["level"])
    for field, value in data.items():
        setattr(course, field, value)
    course.updated_at = utc_now()
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
    course.updated_at = utc_now()
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
    course.updated_at = utc_now()
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
    course.updated_at = utc_now()
    db.commit()
    db.refresh(course)
    return course


@router.post("/admin/courses/{course_id}/restore", response_model=AcademyCourseRead)
def restore_course(
    course_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    course = _course_or_404(db, course_id)
    course.is_archived = False
    course.updated_at = utc_now()
    db.commit()
    db.refresh(course)
    return course


@router.get("/admin/summary")
def get_admin_academy_summary(
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    total_courses = db.query(AcademyCourse).count()
    published_courses = (
        db.query(AcademyCourse).filter(AcademyCourse.is_published.is_(True)).count()
    )
    required_courses = (
        db.query(AcademyCourse).filter(AcademyCourse.is_required.is_(True)).count()
    )
    archived_courses = (
        db.query(AcademyCourse).filter(AcademyCourse.is_archived.is_(True)).count()
    )
    total_lessons = db.query(AcademyLesson).count()
    quiz_count = db.query(AcademyQuiz).count()
    attempts = db.query(AcademyQuizAttempt).count()
    passed_attempts = (
        db.query(AcademyQuizAttempt)
        .filter(AcademyQuizAttempt.passed.is_(True))
        .count()
    )
    completed_lessons = (
        db.query(AcademyProgress)
        .filter(AcademyProgress.status.in_(["completed", "validated"]))
        .count()
    )
    completion_rate = (
        (completed_lessons / max(1, total_lessons)) * 100 if total_lessons else 0
    )
    return {
        "total_courses": total_courses,
        "published_courses": published_courses,
        "required_courses": required_courses,
        "archived_courses": archived_courses,
        "total_lessons": total_lessons,
        "quiz_count": quiz_count,
        "quiz_attempts": attempts,
        "quiz_passed": passed_attempts,
        "lesson_completion_rate": completion_rate,
    }


def _csv_download(filename: str, rows: list[list]) -> Response:
    output = StringIO()
    writer = csv.writer(output)
    writer.writerows(rows)
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/admin/export/progress.csv")
def export_academy_progress_csv(
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    rows = [
        [
            "Nom",
            "Prenom",
            "Email",
            "Formation",
            "Lecon",
            "Progression",
            "Statut",
            "Debut",
            "Fin",
        ]
    ]
    progress_rows = (
        db.query(AcademyProgress, User, AcademyCourse, AcademyLesson)
        .join(User, User.id == AcademyProgress.user_id)
        .join(AcademyCourse, AcademyCourse.id == AcademyProgress.course_id)
        .outerjoin(AcademyLesson, AcademyLesson.id == AcademyProgress.lesson_id)
        .order_by(AcademyProgress.updated_at.desc())
        .all()
    )
    for progress, user, course, lesson in progress_rows:
        rows.append(
            [
                user.last_name,
                user.first_name,
                user.email,
                course.title,
                lesson.title if lesson else "",
                float(progress.progress_percent or 0),
                progress.status,
                progress.started_at,
                progress.completed_at,
            ]
        )
    return _csv_download("enactspace_academy_progress.csv", rows)


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
    course.updated_at = utc_now()
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
    lesson.updated_at = utc_now()
    db.commit()
    db.refresh(lesson)
    return lesson


@router.delete("/admin/lessons/{lesson_id}")
def delete_lesson(
    lesson_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    lesson = _lesson_or_404(db, lesson_id)
    db.delete(lesson)
    db.commit()
    return {"deleted": True, "lesson_id": lesson_id}


@router.post("/lessons/{lesson_id}/start", response_model=AcademyProgressRead)
def start_lesson(
    lesson_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    lesson = _lesson_or_404(db, lesson_id)
    if not lesson.is_published:
        raise HTTPException(404, "Leçon indisponible.")
    require_learning_access(db, current_user.id, lesson.course_id)
    progress = _lesson_progress(db, user_id=current_user.id, lesson=lesson)
    if progress.status == "not_started":
        progress.status = "in_progress"
        progress.progress_percent = 10
        progress.started_at = utc_now()
    progress.updated_at = utc_now()
    db.commit()
    db.refresh(progress)
    return progress


@router.post("/lessons/{lesson_id}/complete", response_model=AcademyProgressRead)
def complete_lesson(
    lesson_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    lesson = _lesson_or_404(db, lesson_id)
    if not lesson.is_published:
        raise HTTPException(404, "Leçon indisponible.")
    require_learning_access(db, current_user.id, lesson.course_id)
    progress = _lesson_progress(db, user_id=current_user.id, lesson=lesson)
    progress.status = "completed"
    progress.progress_percent = 100
    if progress.started_at is None:
        progress.started_at = utc_now()
    progress.completed_at = utc_now()
    progress.updated_at = utc_now()

    db.flush()
    course = _course_or_404(db, lesson.course_id)
    completion = _course_completion_percent(
        db,
        user_id=current_user.id,
        course_id=course.id,
    )
    if course.is_required and completion >= 100:
        notify_user(
            db,
            user_id=current_user.id,
            title="Formation obligatoire terminee",
            message=f"Vous avez termine {course.title}.",
            notification_type="academy_completed",
            related_type="academy_course",
            related_id=course.id,
            dedupe=True,
        )

    db.commit()
    db.refresh(progress)
    return progress


@router.post("/admin/quizzes", response_model=AcademyQuizRead)
def create_admin_quiz(
    payload: AcademyQuizCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    if payload.course_id:
        _course_or_404(db, payload.course_id)
    if payload.lesson_id:
        _lesson_or_404(db, payload.lesson_id)
    quiz = AcademyQuiz(**payload.model_dump(), created_by_id=current_user.id)
    db.add(quiz)
    db.commit()
    db.refresh(quiz)
    data = AcademyQuizRead.model_validate(quiz).model_dump()
    data["questions"] = []
    return data


@router.post(
    "/admin/quizzes/{quiz_id}/questions",
    response_model=AcademyQuestionRead,
)
def create_admin_question(
    quiz_id: str,
    payload: AcademyQuestionCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    _quiz_or_404(db, quiz_id)
    if payload.question_type not in {"single_choice", "multiple_choice", "true_false"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de question invalide",
        )
    question = AcademyQuestion(quiz_id=quiz_id, **payload.model_dump())
    db.add(question)
    db.commit()
    db.refresh(question)
    return question


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
    total_lessons = db_lessons
    completed_lessons = (
        db.query(AcademyProgress)
        .join(AcademyLesson, AcademyProgress.lesson_id == AcademyLesson.id)
        .join(AcademyCourse, AcademyLesson.course_id == AcademyCourse.id)
        .filter(
            AcademyCourse.is_published.is_(True), AcademyCourse.is_archived.is_(False),
            AcademyLesson.is_published.is_(True),
            AcademyProgress.user_id == current_user.id,
            AcademyProgress.status.in_(["completed", "validated"]),
            AcademyProgress.lesson_id.isnot(None),
        )
        .count()
    )
    passed_quizzes = (
        db.query(AcademyQuizAttempt.quiz_id)
        .join(AcademyQuiz, AcademyQuizAttempt.quiz_id == AcademyQuiz.id)
        .join(AcademyCourse, AcademyQuiz.course_id == AcademyCourse.id)
        .filter(
            AcademyQuiz.is_published.is_(True), AcademyCourse.is_published.is_(True),
            AcademyCourse.is_archived.is_(False),
            AcademyQuizAttempt.user_id == current_user.id,
            AcademyQuizAttempt.passed.is_(True),
        )
        .distinct().count()
    )
    db_courses = (
        db.query(AcademyCourse)
        .filter(
            AcademyCourse.is_published.is_(True),
            AcademyCourse.is_archived.is_(False),
        )
        .count()
    )
    return {
        "completed_lessons": completed_lessons,
        "total_lessons": total_lessons,
        "passed_quizzes": passed_quizzes,
        "total_quizzes": (db.query(AcademyQuiz).join(AcademyCourse)
            .filter(AcademyQuiz.is_published.is_(True), AcademyCourse.is_published.is_(True),
                    AcademyCourse.is_archived.is_(False)).count()),
        "points": 0,
        "rank": 0,
        "monthly_progress": 0,
    }


@router.get("/me/paths")
def get_my_academy_paths(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    roles = get_user_role_names(db, current_user.id) or {"enacteur"}
    if current_user.status == "alumni":
        roles.add("alumni")
    published = db.query(AcademyCourse).filter(AcademyCourse.is_published.is_(True),
                                              AcademyCourse.is_archived.is_(False)).all()
    by_title = {course.title: course for course in published}
    titles = {
        "discover-enactus": "Découvrir Enactus", "sdgs-impact": "Comprendre les ODD",
        "leadership-collaboration": "Travail d'équipe et transmission",
        "pitch-competition": "Présenter un projet", "business-finance": "Modèle économique et pérennité",
        "new-enacteur-tools": "Premiers pas dans EnactSpace",
        "club-history": "Histoire d'Enactus ESP", "teamwork": "Travail d'équipe et transmission",
        "social-entrepreneurship": "Entrepreneuriat social : de l’idée à l’impact",
        "immersion": "Immersion : écouter avant d’agir",
    }
    access = LearningAccess(db, current_user.id)
    paths = []
    for role in sorted(roles):
        path = ROLE_BASED_PATHS.get(role)
        if not path:
            continue
        selected = [by_title[titles[key]] for key in path['course_ids']
                    if titles.get(key) in by_title]
        paths.append({**path, "course_ids": [str(c.id) for c in selected],
                      "progress": sum(100 if access.mastered(c.id) else 0 for c in selected) / len(selected) if selected else 0})
    if not any(p["id"] == "new-enacteur" for p in paths):
        path = ROLE_BASED_PATHS["enacteur"]
        selected = [by_title[titles[key]] for key in path["course_ids"] if titles.get(key) in by_title]
        paths.insert(0, {**path, "course_ids": [str(c.id) for c in selected],
            "progress": sum(100 if access.mastered(c.id) else 0 for c in selected) / len(selected) if selected else 0})
    return paths


def _resolve_quiz_id(db: Session, quiz_id: str) -> str:
    legacy = {"discover-enactus-quiz": "Découvrir Enactus", "sdgs-impact-quiz": "Comprendre les ODD"}
    if quiz_id in legacy:
        row = (db.query(AcademyQuiz).join(AcademyCourse)
               .filter(AcademyCourse.title == legacy[quiz_id], AcademyQuiz.is_published.is_(True)).first())
        if row:
            return str(row.id)
    try:
        uuid.UUID(str(quiz_id))
        return quiz_id
    except (ValueError, TypeError):
        raise HTTPException(status_code=404, detail="Quiz introuvable")


@router.get("/quizzes/{quiz_id}")
def get_quiz(
    quiz_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    quiz_id = _resolve_quiz_id(db, quiz_id)
    db_quiz = db.query(AcademyQuiz).filter(AcademyQuiz.id == quiz_id).first()
    if db_quiz and db_quiz.is_published:
        require_quiz_access(db, current_user.id, db_quiz)
        return _quiz_payload(db, db_quiz, include_answers=False)

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
    payload: AcademyQuizSubmit,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    answers = payload.answers
    quiz_id = _resolve_quiz_id(db, quiz_id)
    db_quiz = db.query(AcademyQuiz).filter(AcademyQuiz.id == quiz_id).first()
    if db_quiz and db_quiz.is_published:
        if payload.client_submission_id:
            existing_attempt = (
                db.query(AcademyQuizAttempt)
                .filter(
                    AcademyQuizAttempt.user_id == current_user.id,
                    AcademyQuizAttempt.client_submission_id
                    == payload.client_submission_id,
                )
                .first()
            )
            if existing_attempt and existing_attempt.result_payload:
                return existing_attempt.result_payload
        require_quiz_access(db, current_user.id, db_quiz)
        result = _score_db_quiz(db, db_quiz, answers)
        attempts_count = (
            db.query(AcademyQuizAttempt)
            .filter(
                AcademyQuizAttempt.quiz_id == db_quiz.id,
                AcademyQuizAttempt.user_id == current_user.id,
            )
            .count()
        )
        response_payload = {
            "quiz_id": quiz_id,
            "score": result["score"],
            "passed": result["passed"],
            "correct_answers": result["correct_answers"],
            "total_questions": result["total_questions"],
            "feedback": result["feedback"],
            "points": 60 if result["passed"] else 0,
            "attempt_number": attempts_count + 1,
        }
        attempt = AcademyQuizAttempt(
            quiz_id=db_quiz.id,
            user_id=current_user.id,
            answers=answers,
            client_submission_id=payload.client_submission_id,
            result_payload=response_payload,
            score=result["score"],
            max_score=100,
            passed=result["passed"],
            attempt_number=attempts_count + 1,
            submitted_at=utc_now(),
        )
        db.add(attempt)
        try:
            db.flush()
        except IntegrityError:
            db.rollback()
            if payload.client_submission_id:
                concurrent_attempt = (
                    db.query(AcademyQuizAttempt)
                    .filter(
                        AcademyQuizAttempt.user_id == current_user.id,
                        AcademyQuizAttempt.client_submission_id
                        == payload.client_submission_id,
                    )
                    .first()
                )
                if concurrent_attempt and concurrent_attempt.result_payload:
                    return concurrent_attempt.result_payload
            raise

        if result["passed"]:
            notify_user(
                db,
                user_id=current_user.id,
                title=f"Quiz reussi : {db_quiz.title}",
                message=f"Score obtenu : {result['score']:.0f}%.",
                notification_type="quiz_passed",
                related_type="academy_quiz",
                related_id=db_quiz.id,
                dedupe=True,
            )
        db.commit()
        return response_payload

    quiz = get_quiz(quiz_id, db=db, current_user=current_user)
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
