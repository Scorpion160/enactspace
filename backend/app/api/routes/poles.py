from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.pole import Pole
from app.schemas.pole import PoleCreate, PoleRead
from app.api.deps import get_current_user
from app.models.user import User


router = APIRouter(prefix="/poles", tags=["Pôles"])


@router.post("/", response_model=PoleRead)
def create_pole(
    payload: PoleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    pole = Pole(
        season_id=payload.season_id,
        name=payload.name,
        short_name=payload.short_name,
        type=payload.type,
        description=payload.description,
        objectives=payload.objectives,
    )

    db.add(pole)
    db.commit()
    db.refresh(pole)

    return pole


@router.get("/", response_model=list[PoleRead])
def list_poles(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Pole).order_by(Pole.name.asc()).all()