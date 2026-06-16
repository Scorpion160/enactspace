from pydantic import BaseModel
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class PoleCreate(BaseModel):
    season_id: Optional[UUID] = None
    name: str
    short_name: Optional[str] = None
    type: str
    description: Optional[str] = None
    objectives: Optional[str] = None


class PoleRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    name: str
    short_name: Optional[str]
    type: str
    description: Optional[str]
    objectives: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class PoleMemberAssign(BaseModel):
    user_id: UUID
    position: str = "membre"


class PoleMemberRead(BaseModel):
    id: UUID
    pole_id: UUID
    user_id: UUID
    position: str
    joined_at: date
    left_at: Optional[date]
    is_active: bool

    class Config:
        from_attributes = True
