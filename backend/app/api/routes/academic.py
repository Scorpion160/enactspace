from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user
from app.core.time import utc_now
from app.db.database import get_db
from app.models.academic import UserAcademicHistory
from app.models.season import Season
from app.models.user import User
from app.schemas.academic import AcademicProfileConfirm, AcademicProfileRead, AcademicHistoryRead
from app.services.annual_transition import lock_year_transition
from app.services.operational_integrity import lock_user, assert_operational_actor
from app.services.academic_profile import ACADEMIC_DEPARTMENTS, ACADEMIC_LEVELS, progression_for, validate_academic_path

router = APIRouter(prefix="/academic-profile", tags=["Profil académique"])


def _current_season(db: Session) -> Season:
    seasons = db.query(Season).filter(Season.is_current.is_(True), Season.archived.is_(False)).all()
    if len(seasons) != 1:
        raise HTTPException(409, "Une année courante unique est requise")
    return seasons[0]


def _profile(user: User) -> AcademicProfileRead:
    progression = progression_for(user.cursus, user.study_level)
    return AcademicProfileRead(
        user_id=user.id, department=user.department, cursus=user.cursus,
        level=user.study_level, specialty=user.specialty, promotion=user.promotion,
        confirmed_season_id=user.academic_confirmed_season_id,
        confirmed_at=user.academic_confirmed_at,
        suggested_next_level=progression.suggested_next_level,
        terminal=progression.terminal,
    )


@router.get("/catalog")
def academic_catalog(
    current_user: User = Depends(get_current_active_validated_user),
):
    return {
        "departments": {
            name: {cursus: list(ACADEMIC_LEVELS[cursus]) for cursus in sorted(cursuses)}
            for name, cursuses in ACADEMIC_DEPARTMENTS.items()
        }
    }


@router.get("/me", response_model=AcademicProfileRead)
def read_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current = db.query(Season).filter(Season.is_current.is_(True), Season.archived.is_(False)).first()
    result = _profile(current_user)
    return result.model_copy(update={
        "current_season_id": current.id if current else None,
        "current_season_name": current.name if current else None,
        "confirmed_current_season": bool(current and current.id == current_user.academic_confirmed_season_id)
    })


@router.get("/me/history", response_model=list[AcademicHistoryRead])
def read_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    rows = (db.query(UserAcademicHistory, Season.name)
        .join(Season, Season.id == UserAcademicHistory.season_id)
        .filter(UserAcademicHistory.user_id == current_user.id)
        .order_by(Season.start_date.desc()).all())
    return [AcademicHistoryRead(
        id=row.id, user_id=row.user_id, season_id=row.season_id,
        season_name=name, department=row.department, cursus=row.cursus,
        level=row.study_level, specialty=row.specialty, promotion=row.promotion,
        progression_action=row.progression_action, confirmed_at=row.confirmed_at,
    ) for row, name in rows]

@router.put("/me/confirm", response_model=AcademicProfileRead)
def confirm_profile(
    payload: AcademicProfileConfirm,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current_user = lock_user(db, current_user.id)
    assert_operational_actor(current_user)
    lock_year_transition(db)
    season = _current_season(db)
    if payload.season_id is not None and payload.season_id != season.id:
        raise HTTPException(409, "L’année indiquée n'est pas l’année courante")
    try:
        validate_academic_path(payload.department, payload.cursus, payload.level)
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from exc
    row = (db.query(UserAcademicHistory)
        .filter(UserAcademicHistory.user_id == current_user.id,
                UserAcademicHistory.season_id == season.id)
        .with_for_update().first())
    if row is not None:
        raise HTTPException(409, "Profil déjà confirmé pour cette année")
    previous = (db.query(UserAcademicHistory)
        .join(Season, Season.id == UserAcademicHistory.season_id)
        .filter(UserAcademicHistory.user_id == current_user.id)
        .order_by(Season.start_date.desc()).first())
    action = "initial"
    if previous is not None:
        suggestion = progression_for(previous.cursus, previous.study_level)
        if payload.cursus == previous.cursus and payload.level == previous.study_level:
            action = "repeat"
        elif payload.cursus == previous.cursus and payload.level == suggestion.suggested_next_level:
            action = "progress"
        else:
            action = "change"
    now = utc_now()
    row = UserAcademicHistory(
        user_id=current_user.id, season_id=season.id,
        department=payload.department, cursus=payload.cursus,
        study_level=payload.level, specialty=payload.specialty,
        promotion=payload.promotion, progression_action=action,
        confirmed_at=now,
    )
    db.add(row)
    current_user.department = payload.department
    current_user.cursus = payload.cursus
    current_user.study_level = payload.level
    current_user.specialty = payload.specialty
    current_user.promotion = payload.promotion
    current_user.academic_confirmed_season_id = season.id
    current_user.academic_confirmed_at = now
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "Profil déjà confirmé pour cette année") from exc
    db.refresh(current_user)
    return _profile(current_user).model_copy(update={"confirmed_current_season": True, "current_season_id": season.id, "current_season_name": season.name})
