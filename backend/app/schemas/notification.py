from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, List, Any


class NotificationCreate(BaseModel):
    user_id: UUID
    title: str
    message: Optional[str] = None
    body: Optional[str] = None
    type: Optional[str] = None
    category: Optional[str] = None
    entity_type: Optional[str] = None
    entity_id: Optional[UUID] = None
    related_type: Optional[str] = None
    related_id: Optional[UUID] = None
    priority: Optional[str] = None
    created_by_id: Optional[UUID] = None
    metadata: Optional[dict[str, Any]] = None


class BulkNotificationCreate(BaseModel):
    user_ids: List[UUID]
    title: str
    message: Optional[str] = None
    body: Optional[str] = None
    type: Optional[str] = None
    category: Optional[str] = None
    entity_type: Optional[str] = None
    entity_id: Optional[UUID] = None
    related_type: Optional[str] = None
    related_id: Optional[UUID] = None
    priority: Optional[str] = None
    created_by_id: Optional[UUID] = None
    metadata: Optional[dict[str, Any]] = None


class NotificationRead(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    message: str
    type: Optional[str]
    is_read: bool
    related_type: Optional[str]
    related_id: Optional[UUID]
    created_at: datetime
    read_at: Optional[datetime]

    class Config:
        from_attributes = True


class NotificationCountRead(BaseModel):
    unread_count: int
