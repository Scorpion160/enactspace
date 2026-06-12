from pydantic import BaseModel
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class SeasonCreate(BaseModel):
    name: str
    start_date: date
    end_date: Optional[date] = None
    is_current: bool = False


class SeasonRead(BaseModel):
    id: UUID
    name: str
    start_date: date
    end_date: Optional[date]
    is_current: bool
    archived: bool
    created_at: datetime

    class Config:
        from_attributes = True