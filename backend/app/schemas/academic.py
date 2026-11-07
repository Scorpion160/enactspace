from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, field_validator


class AcademicProfileConfirm(BaseModel):
    department: str
    cursus: str
    level: str
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    season_id: Optional[UUID] = None

    @field_validator("department", "cursus", "level")
    @classmethod
    def clean_required(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Ce champ académique est obligatoire")
        return cleaned

    @field_validator("specialty", "promotion")
    @classmethod
    def clean_optional(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None


class AcademicProfileRead(BaseModel):
    user_id: UUID
    department: Optional[str] = None
    cursus: Optional[str] = None
    level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    confirmed_season_id: Optional[UUID] = None
    confirmed_at: Optional[datetime] = None
    current_season_id: Optional[UUID] = None
    current_season_name: Optional[str] = None
    confirmed_current_season: bool = False
    suggested_next_level: Optional[str] = None
    terminal: bool = False


class AcademicHistoryRead(BaseModel):
    id: UUID
    user_id: UUID
    season_id: UUID
    season_name: str
    department: str
    cursus: str
    level: str
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    progression_action: str
    confirmed_at: datetime

    class Config:
        from_attributes = True
