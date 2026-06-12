from uuid import UUID
from typing import Any, Optional

from fastapi import Request
from sqlalchemy.orm import Session

from app.models.audit import AuditLog


def get_client_ip(request: Request | None) -> str | None:
    if request is None:
        return None

    forwarded_for = request.headers.get("x-forwarded-for")

    if forwarded_for:
        return forwarded_for.split(",")[0].strip()

    if request.client:
        return request.client.host

    return None


def create_audit_log(
    db: Session,
    action: str,
    user_id: Optional[UUID] = None,
    entity_type: Optional[str] = None,
    entity_id: Optional[UUID] = None,
    old_value: Optional[dict[str, Any]] = None,
    new_value: Optional[dict[str, Any]] = None,
    ip_address: Optional[str] = None,
) -> AuditLog:
    log = AuditLog(
        user_id=user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        old_value=old_value,
        new_value=new_value,
        ip_address=ip_address,
    )

    db.add(log)
    return log


def model_to_dict(obj, fields: list[str]) -> dict[str, Any]:
    data = {}

    for field in fields:
        value = getattr(obj, field, None)

        if hasattr(value, "isoformat"):
            data[field] = value.isoformat()
        else:
            data[field] = str(value) if value is not None else None

    return data