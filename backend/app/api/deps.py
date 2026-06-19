from typing import Iterable

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.security import decode_access_token
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

    return {row[0] for row in rows}


def user_has_role(db: Session, user_id, role_name: str) -> bool:
    return role_name in get_user_role_names(db, user_id)


def user_has_any_role(db: Session, user_id, role_names: Iterable[str]) -> bool:
    current_roles = get_user_role_names(db, user_id)
    return bool(current_roles.intersection(set(role_names)))


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
    allowed_roles = {
        "team_leader",
        "secretaire_generale",
        "financier",
        "chef_pole",
        "adjoint_chef_pole",
        "chef_projet",
        "adjoint_chef_projet",
        "administrateur",
        "faculty_advisor",
    }

    if not user_has_any_role(db, current_user.id, allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée à Enacchef ou à l'administration",
        )

    return current_user


def require_admin_or_team_leader(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    allowed_roles = {
        "administrateur",
        "team_leader",
    }

    if not user_has_any_role(db, current_user.id, allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée au Team Leader ou à l'administrateur",
        )

    return current_user


def require_sg_or_admin(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    allowed_roles = {
        "secretaire_generale",
        "team_leader",
        "administrateur",
    }

    if not user_has_any_role(db, current_user.id, allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée à la Secrétaire Générale, au Team Leader ou à l'administrateur",
        )

    return current_user


def require_finance_or_admin(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    allowed_roles = {
        "financier",
        "team_leader",
        "administrateur",
    }

    if not user_has_any_role(db, current_user.id, allowed_roles):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée au financier, au Team Leader ou à l'administrateur",
        )

    return current_user


def require_recruitment_access(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    allowed_roles = {
        "administrateur",
        "team_leader",
        "secretaire_generale",
        "chef_pole",
        "adjoint_chef_pole",
        "chef_projet",
        "adjoint_chef_projet",
        "pole_veille",
        "veille",
        "chef_pole_veille",
        "adjoint_pole_veille",
        "recrutement",
        "recruiter",
    }

    if user_has_any_role(db, current_user.id, allowed_roles):
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
