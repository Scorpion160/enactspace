from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class EngagementPointCreate(BaseModel):
    user_id: UUID
    season_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    source_type: str
    source_id: Optional[UUID] = None
    points: int
    reason: Optional[str] = None


class EngagementPointRead(BaseModel):
    id: UUID
    user_id: UUID
    season_id: Optional[UUID]
    pole_id: Optional[UUID]
    project_id: Optional[UUID]
    source_type: str
    source_id: Optional[UUID]
    points: int
    reason: Optional[str]
    awarded_by: Optional[UUID]
    created_at: datetime

    class Config:
        from_attributes = True


class BadgeCreate(BaseModel):
    name: str
    label: str
    description: Optional[str] = None
    icon_url: Optional[str] = None


class BadgeUpdate(BaseModel):
    label: Optional[str] = None
    description: Optional[str] = None
    icon_url: Optional[str] = None


class BadgeRead(BaseModel):
    id: UUID
    name: str
    label: str
    description: Optional[str]
    icon_url: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class UserBadgeCreate(BaseModel):
    user_id: UUID
    badge_id: UUID
    season_id: Optional[UUID] = None


class UserBadgeRead(BaseModel):
    id: UUID
    user_id: UUID
    badge_id: UUID
    season_id: Optional[UUID]
    awarded_by: Optional[UUID]
    awarded_at: datetime

    class Config:
        from_attributes = True


class UserRankingRead(BaseModel):
    user_id: UUID
    total_points: int


class PoleRankingRead(BaseModel):
    pole_id: UUID
    total_points: int


class MonthlyWinnerRead(BaseModel):
    month: int
    year: int
    user_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    total_points: int = 0