from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, get_user_role_names
from app.core.roles import GLOBAL_MANAGEMENT_ROLES, SECRETARIAT_ROLES
from app.db.database import get_db
from app.models.audit import AuditLog
from app.models.attendance import AttendanceSession
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.schemas.audit import AuditLogRead


router = APIRouter(prefix="/audit", tags=["Audit"])

POLE_MANAGER_POSITIONS = {"chef_pole", "adjoint_chef_pole"}
PROJECT_MANAGER_POSITIONS = {"chef_projet", "adjoint_chef_projet"}


@router.get("/logs", response_model=list[AuditLogRead])
def list_audit_logs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    action: str | None = Query(default=None),
    action_prefix: str | None = Query(default=None),
    entity_type: str | None = Query(default=None),
    entity_id: str | None = Query(default=None),
    user_id: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
):
    _ensure_can_read_audit(
        db,
        current_user,
        action=action,
        action_prefix=action_prefix,
        entity_type=entity_type,
        entity_id=entity_id,
    )

    query = db.query(AuditLog)

    if action:
        query = query.filter(AuditLog.action == action)
    elif action_prefix:
        query = query.filter(AuditLog.action.like(f"{action_prefix}%"))

    if entity_type:
        query = query.filter(AuditLog.entity_type == entity_type)

    if entity_id:
        query = query.filter(AuditLog.entity_id == entity_id)

    if user_id:
        query = query.filter(AuditLog.user_id == user_id)

    return query.order_by(AuditLog.created_at.desc()).limit(limit).all()


def _ensure_can_read_audit(
    db: Session,
    current_user: User,
    *,
    action: str | None,
    action_prefix: str | None,
    entity_type: str | None,
    entity_id: str | None,
) -> None:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_MANAGEMENT_ROLES):
        return

    if (
        entity_type == "attendance_session"
        and entity_id
        and (
            (action is not None and action.startswith("attendance_qr"))
            or (
                action is None
                and action_prefix is not None
                and action_prefix.startswith("attendance_qr")
            )
        )
        and _can_manage_attendance_session_audit(db, current_user, entity_id, roles)
    ):
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Journal d'audit non accessible",
    )


def _can_manage_attendance_session_audit(
    db: Session,
    current_user: User,
    session_id: str,
    roles: set[str],
) -> bool:
    session = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.id == session_id)
        .first()
    )
    if not session:
        return False

    if roles.intersection(SECRETARIAT_ROLES):
        return True
    if session.created_by == current_user.id:
        return True
    if session.pole_id:
        pole_manager = (
            db.query(PoleMember.id)
            .filter(
                PoleMember.user_id == current_user.id,
                PoleMember.pole_id == session.pole_id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position.in_(POLE_MANAGER_POSITIONS),
            )
            .first()
        )
        if pole_manager:
            return True
    if session.project_id:
        project_manager = (
            db.query(ProjectMember.id)
            .filter(
                ProjectMember.user_id == current_user.id,
                ProjectMember.project_id == session.project_id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
                ProjectMember.position.in_(PROJECT_MANAGER_POSITIONS),
            )
            .first()
        )
        if project_manager:
            return True
    return False
