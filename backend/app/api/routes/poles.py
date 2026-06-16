from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.pole import Pole, PoleMember
from app.schemas.pole import PoleCreate, PoleMemberAssign, PoleMemberRead, PoleRead
from app.api.deps import get_current_user, require_enacchef_or_admin
from app.models.user import User


router = APIRouter(prefix="/poles", tags=["Pôles"])


VALID_POLE_POSITIONS = {"membre", "chef_pole", "adjoint_chef_pole"}


def get_pole_or_404(db: Session, pole_id: str) -> Pole:
    pole = db.query(Pole).filter(Pole.id == pole_id).first()
    if pole is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pôle introuvable",
        )
    return pole


def get_user_or_404(db: Session, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utilisateur introuvable",
        )
    return user


@router.post("/", response_model=PoleRead)
def create_pole(
    payload: PoleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
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


@router.post("/{pole_id}/members", response_model=PoleMemberRead)
def assign_pole_member(
    pole_id: str,
    payload: PoleMemberAssign,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    get_pole_or_404(db, pole_id)
    get_user_or_404(db, str(payload.user_id))

    if payload.position not in VALID_POLE_POSITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Position pôle invalide",
        )

    membership = (
        db.query(PoleMember)
        .filter(PoleMember.pole_id == pole_id, PoleMember.user_id == payload.user_id)
        .first()
    )

    if membership is None:
        membership = PoleMember(
            pole_id=pole_id,
            user_id=payload.user_id,
            position=payload.position,
        )
        db.add(membership)
    else:
        membership.position = payload.position
        membership.is_active = True
        membership.left_at = None

    db.commit()
    db.refresh(membership)

    return membership


@router.delete("/{pole_id}/members/{user_id}", response_model=PoleMemberRead)
def remove_pole_member(
    pole_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    membership = (
        db.query(PoleMember)
        .filter(PoleMember.pole_id == pole_id, PoleMember.user_id == user_id)
        .first()
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Membre non rattaché à ce pôle",
        )

    membership.is_active = False
    membership.left_at = date.today()
    db.commit()
    db.refresh(membership)

    return membership
