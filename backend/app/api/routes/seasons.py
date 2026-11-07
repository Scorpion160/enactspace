from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.models.season import Season
from app.schemas.season import SeasonCreate, SeasonRead, YearActivation
from app.api.deps import get_current_active_validated_user, require_sg_or_admin, get_user_role_names
from app.core.roles import SECRETARIAT_ROLES
from app.models.user import User
from app.services.annual_transition import activate_year, lock_year_transition
from app.services.operational_integrity import assert_operational_actor, lock_row

router = APIRouter(prefix="/seasons", tags=["Années"])


@router.get("/context")
def year_context(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_validated_user)):
    operational = (current_user.status == "active" and current_user.is_active
                   and current_user.email_verified and current_user.profile_type in {"enacteur", "enactrice"})
    return {"can_manage": operational and bool(get_user_role_names(db, current_user.id).intersection(SECRETARIAT_ROLES))}


@router.post("/", response_model=SeasonRead)
def create_season(payload: SeasonCreate, db: Session = Depends(get_db),
                  current_user: User = Depends(require_sg_or_admin)):
    current_user = lock_row(db, User, current_user.id)
    assert_operational_actor(current_user)
    if not get_user_role_names(db, current_user.id).intersection(SECRETARIAT_ROLES):
        raise HTTPException(403, "Gestion des années réservée à la direction du club.")
    lock_year_transition(db)
    if db.query(Season).filter(Season.name == payload.name).first():
        raise HTTPException(409, "Une année porte déjà ce nom.")
    current = db.query(Season).filter(Season.is_current.is_(True)).first()
    year = Season(name=payload.name, start_date=payload.start_date,
                  end_date=payload.end_date, is_current=False)
    db.add(year)
    db.flush()
    if payload.is_current:
        activate_year(db, year, expected_current_id=current.id if current else None,
                      actor_id=current_user.id)
    db.commit()
    db.refresh(year)
    return year


@router.get("/", response_model=list[SeasonRead])
def list_seasons(db: Session = Depends(get_db), current_user: User = Depends(get_current_active_validated_user)):
    return db.query(Season).order_by(Season.start_date.desc()).all()


@router.post("/{year_id}/activate", response_model=SeasonRead)
def activate_season(year_id: UUID, payload: YearActivation, db: Session = Depends(get_db),
                    current_user: User = Depends(require_sg_or_admin)):
    current_user = lock_row(db, User, current_user.id)
    assert_operational_actor(current_user)
    if not get_user_role_names(db, current_user.id).intersection(SECRETARIAT_ROLES):
        raise HTTPException(403, "Gestion des années réservée à la direction du club.")
    lock_year_transition(db)
    year = db.query(Season).filter(Season.id == year_id).first()
    if year is None:
        raise HTTPException(404, "Année introuvable.")
    activate_year(db, year, expected_current_id=payload.expected_current_id,
                  actor_id=current_user.id)
    db.commit()
    db.refresh(year)
    return year
