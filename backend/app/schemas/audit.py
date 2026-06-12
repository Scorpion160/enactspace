from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, Any


class AuditLogCreate(BaseModel):
    action: str
    entity_type: Optional[str] = None
    entity_id: Optional[UUID] = None
    old_value: Optional[dict[str, Any]] = None
    new_value: Optional[dict[str, Any]] = None
    ip_address: Optional[str] = None


class AuditLogRead(BaseModel):
    id: UUID
    user_id: Optional[UUID]
    action: str
    entity_type: Optional[str]
    entity_id: Optional[UUID]
    old_value: Optional[dict[str, Any]]
    new_value: Optional[dict[str, Any]]
    ip_address: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True