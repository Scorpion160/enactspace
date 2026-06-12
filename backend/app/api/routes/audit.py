from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.audit import AuditLog
from app.models.user import User
from app.schemas.audit import AuditLogRead
from app.api.deps import require_admin_or_team_leader


router = APIRouter(prefix="/audit", tags=["Audit"])


@router.get("/logs", response_model=list[AuditLogRead])
def list_audit_logs(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
    action: str | None = Query(default=None),
    entity_type: str | None = Query(default=None),
    entity_id: str | None = Query(default=None),
    user_id: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
):
    query = db.query(AuditLog)

    if action:
        query = query.filter(AuditLog.action == action)

    if entity_type:
        query = query.filter(AuditLog.entity_type == entity_type)

    if entity_id:
        query = query.filter(AuditLog.entity_id == entity_id)

    if user_id:
        query = query.filter(AuditLog.user_id == user_id)

    return query.order_by(AuditLog.created_at.desc()).limit(limit).all()