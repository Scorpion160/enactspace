from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.pole import Pole, PoleMember
from app.schemas.pole import (
    PoleCreate,
    PoleMemberAssign,
    PoleMemberDirectoryRead,
    PoleMemberRead,
    PoleRead,
)
from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
    require_sg_or_admin,
)
from app.models.role import Role, UserRole
from app.models.user import User
from app.services.notification_service import notify_user


router = APIRouter(prefix="/poles", tags=["Pôles"])


VALID_POLE_POSITIONS = {"membre", "chef_pole", "adjoint_chef_pole"}
GLOBAL_POLE_MANAGERS = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}
POLE_LEADERSHIP_POSITIONS = {"chef_pole", "adjoint_chef_pole"}


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


def require_pole_manager(
    db: Session,
    current_user: User,
    pole_id: str,
) -> bool:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_POLE_MANAGERS):
        return True

    membership = (
        db.query(PoleMember.id)
        .filter(
            PoleMember.pole_id == pole_id,
            PoleMember.user_id == current_user.id,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
            PoleMember.position.in_(POLE_LEADERSHIP_POSITIONS),
        )
        .first()
    )
    if membership:
        return False

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Gestion réservée aux responsables de ce pôle",
    )


def sync_pole_responsibility_role(
    db: Session,
    user_id,
    role_name: str,
) -> None:
    role = db.query(Role).filter(Role.name == role_name).first()
    if role is None:
        role = Role(name=role_name, description="Responsabilité de pôle")
        db.add(role)
        db.flush()

    should_have_role = (
        db.query(PoleMember.id)
        .filter(
            PoleMember.user_id == user_id,
            PoleMember.position == role_name,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
        )
        .first()
        is not None
    )
    assignment = (
        db.query(UserRole)
        .filter(
            UserRole.user_id == user_id,
            UserRole.role_id == role.id,
        )
        .first()
    )

    if should_have_role and assignment is None:
        db.add(UserRole(user_id=user_id, role_id=role.id))
    elif not should_have_role and assignment is not None:
        db.delete(assignment)


@router.post("/", response_model=PoleRead)
def create_pole(
    payload: PoleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
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
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(Pole).order_by(Pole.name.asc()).all()


@router.get(
    "/{pole_id}/members",
    response_model=list[PoleMemberDirectoryRead],
)
def list_pole_members(
    pole_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    pole = get_pole_or_404(db, pole_id)
    memberships = (
        db.query(PoleMember)
        .filter(
            PoleMember.pole_id == pole_id,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
        )
        .order_by(PoleMember.position.asc(), PoleMember.joined_at.asc())
        .all()
    )

    result = []
    for membership in memberships:
        user = get_user_or_404(db, str(membership.user_id))
        result.append(
            PoleMemberDirectoryRead(
                id=user.id,
                first_name=user.first_name,
                last_name=user.last_name,
                email=user.email,
                photo_url=user.photo_url,
                department=user.department,
                status=user.status,
                core_pole_id=membership.pole_id,
                pole_position=membership.position,
                roles=sorted(get_user_role_names(db, user.id)),
            )
        )
    return result


@router.post("/{pole_id}/members", response_model=PoleMemberRead)
def assign_pole_member(
    pole_id: str,
    payload: PoleMemberAssign,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    pole = get_pole_or_404(db, pole_id)
    target_user = get_user_or_404(db, str(payload.user_id))
    is_global_manager = require_pole_manager(db, current_user, pole_id)

    if payload.position not in VALID_POLE_POSITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Position pôle invalide",
        )
    if payload.position in POLE_LEADERSHIP_POSITIONS and not is_global_manager:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seuls Admin, Team Leader ou SG nomment les responsables",
        )
    if target_user.status != "active" or not target_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le membre sélectionné n'est pas actif",
        )

    membership = (
        db.query(PoleMember)
        .filter(PoleMember.pole_id == pole_id, PoleMember.user_id == payload.user_id)
        .first()
    )
    previous_position = None
    membership_created = membership is None

    if membership is None:
        membership = PoleMember(
            pole_id=pole_id,
            user_id=payload.user_id,
            position=payload.position,
        )
        db.add(membership)
    else:
        previous_position = membership.position
        membership.position = payload.position
        membership.is_active = True
        membership.left_at = None

    if payload.position in POLE_LEADERSHIP_POSITIONS:
        existing_leaders = (
            db.query(PoleMember)
            .filter(
                PoleMember.pole_id == pole_id,
                PoleMember.user_id != payload.user_id,
                PoleMember.position == payload.position,
                PoleMember.is_active.is_(True),
            )
            .all()
        )
        for existing_leader in existing_leaders:
            existing_leader.position = "membre"
            sync_pole_responsibility_role(
                db,
                existing_leader.user_id,
                payload.position,
            )
            notify_user(
                db,
                user_id=existing_leader.user_id,
                title=f"Responsabilité mise à jour dans {pole.name}",
                message="Votre position est désormais membre du pôle.",
                notification_type="role_assigned",
                related_type="pole",
                related_id=pole.id,
            )

    if previous_position in POLE_LEADERSHIP_POSITIONS:
        sync_pole_responsibility_role(db, payload.user_id, previous_position)
    if payload.position in POLE_LEADERSHIP_POSITIONS:
        sync_pole_responsibility_role(db, payload.user_id, payload.position)

    if membership_created or previous_position != payload.position:
        notify_user(
            db,
            user_id=payload.user_id,
            title=f"Affectation au pôle {pole.name}",
            message=f"Votre position est désormais : {payload.position}.",
            notification_type="role_assigned",
            related_type="pole",
            related_id=pole.id,
        )

    db.commit()
    db.refresh(membership)

    return membership


@router.delete("/{pole_id}/members/{user_id}", response_model=PoleMemberRead)
def remove_pole_member(
    pole_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    pole = get_pole_or_404(db, pole_id)
    is_global_manager = require_pole_manager(db, current_user, pole_id)
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
    if (
        membership.position in POLE_LEADERSHIP_POSITIONS
        and not is_global_manager
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seuls Admin, Team Leader ou SG retirent un responsable",
        )

    previous_position = membership.position
    membership.is_active = False
    membership.left_at = date.today()
    if previous_position in POLE_LEADERSHIP_POSITIONS:
        sync_pole_responsibility_role(db, membership.user_id, previous_position)
    notify_user(
        db,
        user_id=membership.user_id,
        title=f"Fin d'affectation au pôle {pole.name}",
        message="Vous n'êtes plus rattaché à ce pôle.",
        notification_type="role_assigned",
        related_type="pole",
        related_id=pole.id,
    )
    db.commit()
    db.refresh(membership)

    return membership
