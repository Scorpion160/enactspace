from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.season import Season
from app.schemas.season import SeasonCreate, SeasonRead
from app.api.deps import get_current_user
from app.models.user import User


router = APIRouter(prefix="/seasons", tags=["Saisons"])


@router.post("/", response_model=SeasonRead)
def create_season(
    payload: SeasonCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.is_current:
        db.query(Season).update({"is_current": False})

    season = Season(
        name=payload.name,
        start_date=payload.start_date,
        end_date=payload.end_date,
        is_current=payload.is_current,
    )

    db.add(season)
    db.commit()
    db.refresh(season)

    return season


@router.get("/", response_model=list[SeasonRead])
def list_seasons(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Season).order_by(Season.start_date.desc()).all()