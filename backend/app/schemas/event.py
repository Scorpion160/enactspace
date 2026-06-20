from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class EventCreate(BaseModel):
    season_id: Optional[UUID] = None
    title: str
    description: Optional[str] = None
    event_type: str
    location: Optional[str] = None
    start_time: datetime
    end_time: Optional[datetime] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    budget: float = 0
    max_participants: Optional[int] = None
    requires_registration: bool = False
    attendance_enabled: bool = True


class EventUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    event_type: Optional[str] = None
    location: Optional[str] = None
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    budget: Optional[float] = None
    max_participants: Optional[int] = None
    requires_registration: Optional[bool] = None
    attendance_enabled: Optional[bool] = None
    report_url: Optional[str] = None


class EventRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    title: str
    description: Optional[str]
    event_type: str
    location: Optional[str]
    start_time: datetime
    end_time: Optional[datetime]
    pole_id: Optional[UUID]
    project_id: Optional[UUID]
    budget: float
    max_participants: Optional[int]
    requires_registration: bool
    attendance_enabled: bool
    report_url: Optional[str]
    created_by: Optional[UUID]
    registered_count: int = 0
    current_user_registered: bool = False
    can_manage: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class EventParticipantRead(BaseModel):
    id: UUID
    user_id: UUID
    display_name: str
    email: str
    photo_url: Optional[str] = None
    registered_at: datetime
