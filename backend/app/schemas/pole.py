from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
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