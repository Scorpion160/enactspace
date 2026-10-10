from typing import Iterable
from uuid import UUID

from fastapi import Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.core.security import decode_access_token_payload
from app.models.account import AuthSession
from app.services.session_service import session_seconds_remaining
from app.core.roles import (
    ENACCHEF_ROLES,
    FINANCE_MANAGEMENT_ROLES,
    GLOBAL_MANAGEMENT_ROLES,
    JOIN_REQUEST_REVIEWER_ROLES,
    MEMORY_CURATOR_ROLES,
    RECRUITMENT_ACCESS_ROLES,
    SECRETARIAT_ROLES,
    normalize_role_name,
    is_veille_pole_name,
)
from app.models.user import User
from app.models.role import Role, UserRole
from app.models.pole import Pole, PoleMember


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/token")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
    request: Request = None,
) -> User:
    payload = decode_access_token_payload(token)
    user_id = payload.get("sub") if payload else None

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalide ou expiré",
        )

    try:
        user_id = UUID(str(user_id))
        session_id = payload.get("sid")
        if session_id is not None:
            session_id = UUID(str(session_id))
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=401, detail="Token invalide ou expiré")

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

    if session_id:
        auth_session = db.query(AuthSession).filter(
            AuthSession.id == session_id,
            AuthSession.user_id == user.id,
        ).first()
        if (
            auth_session is None
            or auth_session.revoked_at is not None
            or session_seconds_remaining(auth_session) <= 0
        ):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Session révoquée ou expirée",
            )

    from app.services.first_access import check_session_access
    check_session_access(user, request.url.path.rstrip("/") if request is not None else "")
    db.info["actor_id"] = user.id
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
            detail="Action réservée à EnacChef ou à l'administration",
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


def require_memory_curator(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if not user_has_any_role(db, current_user.id, MEMORY_CURATOR_ROLES):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action reservee aux curateurs de la memoire institutionnelle",
        )

    return current_user


def can_review_join_requests(db: Session, user: User) -> bool:
    if (user.status != "active" or not user.is_active or not user.email_verified
            or user.profile_type not in {"enacteur", "enactrice"}):
        return False
    roles = get_user_role_names(db, user.id)
    if roles.intersection(JOIN_REQUEST_REVIEWER_ROLES):
        return True
    names = db.query(Pole.name).join(PoleMember, Pole.id == PoleMember.pole_id).filter(
        PoleMember.user_id == user.id, PoleMember.is_active.is_(True),
        PoleMember.left_at.is_(None),
        PoleMember.position.in_({"chef_pole", "adjoint_chef_pole"}),
    ).all()
    return any(is_veille_pole_name(name) for name, in names)


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


def can_manage_finance(db: Session, current_user: User) -> bool:
    return (
        current_user.status == "active"
        and current_user.is_active
        and current_user.email_verified
        and user_has_any_role(db, current_user.id, FINANCE_MANAGEMENT_ROLES)
    )


def require_finance_or_admin(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if not can_manage_finance(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée au financier, au Team Leader ou à l'administrateur",
        )

    return current_user


def can_access_recruitment(db: Session, current_user: User) -> bool:
    if current_user.status != "active" or not current_user.is_active:
        return False
    if user_has_any_role(db, current_user.id, RECRUITMENT_ACCESS_ROLES):
        return True
    names = db.query(Pole.name).join(PoleMember, PoleMember.pole_id == Pole.id).filter(
        PoleMember.user_id == current_user.id, PoleMember.is_active.is_(True),
        PoleMember.left_at.is_(None),
    ).all()
    return any(is_veille_pole_name(name) for name, in names)


def require_recruitment_access(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
) -> User:
    if can_access_recruitment(db, current_user):
        return current_user

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Action réservée au pôle Veille et aux responsables habilités du recrutement",
    )
