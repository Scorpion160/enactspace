from typing import Iterable

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.security import decode_access_token
from app.core.roles import (
    ENACCHEF_ROLES,
    FINANCE_MANAGEMENT_ROLES,
    GLOBAL_MANAGEMENT_ROLES,
    JOIN_REQUEST_REVIEWER_ROLES,
    RECRUITMENT_ACCESS_ROLES,
    SECRETARIAT_ROLES,
    normalize_role_name,
)
from app.models.user import User
from app.models.role import Role, UserRole
from app.models.pole import Pole, PoleMember


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/token")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    user_id = decode_access_token(token)

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalide ou expiré",
        )

    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utilisateur introuvable",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte désactivé",
        )

    return user


def get_current_active_validated_user(
    current_user: User = Depends(get_current_user),
) -> User:
    if current_user.status not in {"active", "alumni"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte en attente de validation par l'administration",
        )

    if not current_user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email non vérifié",
        )

    return current_user


def get_user_role_names(db: Session, user_id) -> set[str]:
    rows = (
        db.query(Role.name)
        .join(UserRole, UserRole.role_id == Role.id)
        .filter(UserRole.user_id == user_id)
        .all()
    )

    return {normalize_role_name(row[0]) for row in rows}


def user_has_role(db: Session, user_id, role_name: str) -> bool:
    return normalize_role_name(role_name) in get_user_role_names(db, user_id)


def user_has_any_role(db: Session, user_id, role_names: Iterable[str]) -> bool:
    current_roles = get_user_role_names(db, user_id)
    allowed_roles = {normalize_role_name(role) for role in role_names}
    return bool(current_roles.intersection(allowed_roles))


def require_roles(*allowed_roles: str):
    def dependency(
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_active_validated_user),
    ) -> User:
        if not user_has_any_role(db, current_user.id, allowed_roles):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Permission insuffisante",
            )

        return current_user

    return dependency


def require_enacchef_or_admin(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if not user_has_any_role(db, current_user.id, ENACCHEF_ROLES):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée à Enacchef ou à l'administration",
        )

    return current_user


def require_admin_or_team_leader(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if not user_has_any_role(db, current_user.id, GLOBAL_MANAGEMENT_ROLES):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée au Team Leader ou à l'administrateur",
        )

    return current_user


def require_sg_or_admin(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if not user_has_any_role(db, current_user.id, SECRETARIAT_ROLES):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée à la Secrétaire Générale, au Team Leader ou à l'administrateur",
        )

    return current_user


def can_review_join_requests(
    db: Session,
    user: User,
) -> bool:
    roles = get_user_role_names(db, user.id)
    if roles.intersection(JOIN_REQUEST_REVIEWER_ROLES):
        return True

    return (
        db.query(PoleMember.id)
        .join(Pole, Pole.id == PoleMember.pole_id)
        .filter(
            PoleMember.user_id == user.id,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
            PoleMember.position.in_({"chef_pole", "adjoint_chef_pole"}),
            func.lower(Pole.name).like("%veille%"),
        )
        .first()
        is not None
    )


def require_join_request_reviewer(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if not can_review_join_requests(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Action réservée à la SG, au Team Leader, à l'administration "
                "ou aux responsables du pôle Veille"
            ),
        )

    return current_user


def require_finance_or_admin(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if not user_has_any_role(db, current_user.id, FINANCE_MANAGEMENT_ROLES):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée au financier, au Team Leader ou à l'administrateur",
        )

    return current_user


def require_recruitment_access(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if user_has_any_role(db, current_user.id, RECRUITMENT_ACCESS_ROLES):
        return current_user

    veille_membership = (
        db.query(PoleMember.id)
        .join(Pole, Pole.id == PoleMember.pole_id)
        .filter(
            PoleMember.user_id == current_user.id,
            PoleMember.is_active == True,
            PoleMember.left_at.is_(None),
            func.lower(Pole.name) == "veille",
        )
        .first()
    )

    if veille_membership:
        return current_user

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Action réservée au pôle Veille et aux Enacchefs autorisés",
    )
