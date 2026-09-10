from __future__ import annotations

from datetime import date, datetime, timezone
from typing import TypeVar

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.roles import (
    ALUMNI_ROLE,
    BASE_ACTIVE_ROLE,
    normalize_role_name,
)
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.role import Role, UserRole
from app.models.user import User


ModelT = TypeVar("ModelT")


def conflict(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail)


def lock_row(db: Session, model: type[ModelT], row_id) -> ModelT | None:
    """Lock one aggregate root on PostgreSQL; harmless on SQLite."""
    return (
        db.query(model)
        .filter(model.id == row_id)
        .populate_existing()
        .with_for_update()
        .first()
    )


def to_naive_utc(value: datetime | None) -> datetime | None:
    """Normalize API datetimes to the repository's existing naive-UTC convention."""
    if value is None or value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def assert_active_operational_member(user: User) -> None:
    if (
        user.status != "active"
        or not user.is_active
        or user.profile_type not in {BASE_ACTIVE_ROLE, "enactrice"}
    ):
        raise conflict("Le membre sélectionné n'est pas un membre opérationnel actif")


def assert_suspendable_lifecycle(user: User) -> None:
    is_active_operational = (
        user.status == "active"
        and user.is_active
        and user.profile_type in {BASE_ACTIVE_ROLE, "enactrice"}
    )
    is_active_alumni = (
        user.status == ALUMNI_ROLE
        and user.is_active
        and user.profile_type == ALUMNI_ROLE
    )
    if not (is_active_operational or is_active_alumni):
        raise conflict("Ce compte ne peut pas être suspendu depuis son état actuel")


def assert_can_make_alumni(user: User) -> None:
    if (
        user.status != "active"
        or not user.is_active
        or user.profile_type not in {BASE_ACTIVE_ROLE, "enactrice"}
    ):
        raise conflict("Seul un membre opérationnel actif peut devenir Alumni")


def _role(db: Session, role_name: str, *, lock: bool = False) -> Role:
    query = db.query(Role).filter(Role.name == role_name)
    if lock:
        query = query.with_for_update()
    role = query.first()
    if role is None:
        role = Role(name=role_name, description=f"Rôle {role_name}")
        db.add(role)
        db.flush()
    return role


def ensure_user_role(db: Session, user_id, role_name: str) -> bool:
    role = _role(db, role_name)
    existing = db.query(UserRole).filter(
        UserRole.user_id == user_id,
        UserRole.role_id == role.id,
    ).first()
    if existing is not None:
        return False
    db.add(UserRole(user_id=user_id, role_id=role.id))
    return True


def remove_user_roles(db: Session, user_id, role_names: set[str]) -> list[str]:
    normalized = {normalize_role_name(name) for name in role_names}
    links = (
        db.query(UserRole)
        .join(Role, Role.id == UserRole.role_id)
        .filter(UserRole.user_id == user_id)
        .order_by(UserRole.id.asc())
        .all()
    )
    removed: list[str] = []
    for link in links:
        name = normalize_role_name(link.role.name)
        if name in normalized:
            removed.append(name)
            db.delete(link)
    return removed


def retain_user_roles(db: Session, user_id, retained_role_names: set[str]) -> list[str]:
    retained = {normalize_role_name(name) for name in retained_role_names}
    links = (
        db.query(UserRole)
        .join(Role, Role.id == UserRole.role_id)
        .filter(UserRole.user_id == user_id)
        .order_by(UserRole.id.asc())
        .all()
    )
    removed: list[str] = []
    for link in links:
        name = normalize_role_name(link.role.name)
        if name not in retained:
            removed.append(name)
            db.delete(link)
    return removed


def deactivate_operational_memberships(db: Session, user_id) -> None:
    today = date.today()
    pole_rows = (
        db.query(PoleMember)
        .filter(PoleMember.user_id == user_id, PoleMember.is_active.is_(True))
        .order_by(PoleMember.id.asc())
        .with_for_update()
        .all()
    )
    project_rows = (
        db.query(ProjectMember)
        .filter(ProjectMember.user_id == user_id, ProjectMember.is_active.is_(True))
        .order_by(ProjectMember.id.asc())
        .with_for_update()
        .all()
    )
    for membership in [*pole_rows, *project_rows]:
        membership.is_active = False
        membership.left_at = today


def reconcile_user_lifecycle(db: Session, user: User, lifecycle: str) -> None:
    """Apply one lifecycle invariant after the caller has locked ``user``."""
    if lifecycle == "active":
        if user.profile_type not in {BASE_ACTIVE_ROLE, "enactrice"}:
            raise conflict(
                "Ce type de profil exige le parcours de cycle de vie approprié"
            )
        user.status = "active"
        user.is_active = True
        retain_user_roles(db, user.id, {BASE_ACTIVE_ROLE})
        ensure_user_role(db, user.id, BASE_ACTIVE_ROLE)
    elif lifecycle == "suspended":
        user.status = "suspended"
        user.is_active = False
        deactivate_operational_memberships(db, user.id)
        retain_user_roles(db, user.id, {BASE_ACTIVE_ROLE})
    elif lifecycle == "rejected":
        user.status = "rejected"
        user.is_active = False
        deactivate_operational_memberships(db, user.id)
        retain_user_roles(db, user.id, set())
    elif lifecycle == ALUMNI_ROLE:
        user.status = ALUMNI_ROLE
        user.profile_type = ALUMNI_ROLE
        user.is_active = True
        deactivate_operational_memberships(db, user.id)
        retain_user_roles(db, user.id, {ALUMNI_ROLE})
        ensure_user_role(db, user.id, ALUMNI_ROLE)
    else:
        raise ValueError(f"Unsupported lifecycle: {lifecycle}")
    user.updated_at = datetime.utcnow()


def lock_user(db: Session, user_id) -> User:
    user = lock_row(db, User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utilisateur introuvable",
        )
    return user


def lock_exclusive_role(db: Session, role_name: str) -> Role:
    return _role(db, role_name, lock=True)
