from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class DocumentCreate(BaseModel):
    title: str
    description: Optional[str] = None
    file_url: str
    file_type: Optional[str] = None
    category: Optional[str] = None
    visibility: str = "internal"
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    event_id: Optional[UUID] = None
    season_id: Optional[UUID] = None
    is_template: bool = False


class DocumentUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    file_url: Optional[str] = None
    file_type: Optional[str] = None
    category: Optional[str] = None
    visibility: Optional[str] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    event_id: Optional[UUID] = None
    season_id: Optional[UUID] = None
    is_template: Optional[bool] = None


class DocumentRead(BaseModel):
    id: UUID
    title: str
    description: Optional[str]
    file_url: str
    file_type: Optional[str]
    category: Optional[str]
    uploaded_by: Optional[UUID]
    validated_by: Optional[UUID]
    validated_at: Optional[datetime]
    visibility: str
    pole_id: Optional[UUID]
    project_id: Optional[UUID]
    event_id: Optional[UUID]
    season_id: Optional[UUID]
    is_template: bool
    is_official: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True