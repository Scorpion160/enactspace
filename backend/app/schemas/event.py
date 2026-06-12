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
    created_at: datetime

    class Config:
        from_attributes = True