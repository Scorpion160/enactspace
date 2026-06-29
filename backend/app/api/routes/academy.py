from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user
from app.db.database import get_db
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


@router.get("/courses")
def list_courses(current_user=Depends(get_current_active_validated_user)):
    return COURSES


@router.get("/me/progress")
def get_my_progress(current_user=Depends(get_current_active_validated_user)):
    total_lessons = sum(len(course["lessons"]) for course in COURSES)
    return {
        "completed_lessons": 0,
        "total_lessons": total_lessons,
        "passed_quizzes": 0,
        "total_quizzes": len(COURSES),
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
