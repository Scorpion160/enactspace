from pydantic import BaseModel, ConfigDict, Field, field_validator
from app.core.account_identity import validate_join_year
from urllib.parse import urlsplit
from uuid import UUID
from datetime import date, datetime
from typing import Optional, Literal


def profile_url(value):
    if value is None or not value:
        return None
    parsed = urlsplit(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("Utilisez un lien web HTTP ou HTTPS valide.")
    return value

class AlumniProfileCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    _urls = field_validator("linkedin_url", "portfolio_url")(profile_url)
    enactus_join_year: Optional[int] = None
    _join_year = field_validator("enactus_join_year", "graduation_year")(validate_join_year)
    user_id: UUID
    graduation_year: Optional[int] = None
    current_company: Optional[str] = Field(default=None, max_length=150)
    current_position: Optional[str] = Field(default=None, max_length=150)
    domain: Optional[str] = Field(default=None, max_length=150)
    skills: Optional[str] = Field(default=None, max_length=10000)
    experience_summary: Optional[str] = Field(default=None, max_length=10000)
    available_for_mentoring: bool = True
    linkedin_url: Optional[str] = Field(default=None, max_length=2048)
    portfolio_url: Optional[str] = Field(default=None, max_length=2048)
    visibility: Literal["internal", "alumni_only", "enacchef_only", "private"] = "internal"


class AlumniProfileUpdate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    _urls = field_validator("linkedin_url", "portfolio_url")(profile_url)
    enactus_join_year: Optional[int] = None
    _join_year = field_validator("enactus_join_year", "graduation_year")(validate_join_year)
    graduation_year: Optional[int] = None
    current_company: Optional[str] = Field(default=None, max_length=150)
    current_position: Optional[str] = Field(default=None, max_length=150)
    domain: Optional[str] = Field(default=None, max_length=150)
    skills: Optional[str] = Field(default=None, max_length=10000)
    experience_summary: Optional[str] = Field(default=None, max_length=10000)
    available_for_mentoring: bool = None
    linkedin_url: Optional[str] = Field(default=None, max_length=2048)
    portfolio_url: Optional[str] = Field(default=None, max_length=2048)
    visibility: Literal["internal", "alumni_only", "enacchef_only", "private"] = None


class AlumniProfileRead(BaseModel):
    enactus_join_year: Optional[int] = None

    id: UUID
    user_id: UUID
    graduation_year: Optional[int]
    current_company: Optional[str]
    current_position: Optional[str]
    domain: Optional[str]
    skills: Optional[str]
    experience_summary: Optional[str]
    available_for_mentoring: bool
    linkedin_url: Optional[str]
    portfolio_url: Optional[str]
    visibility: str
    display_name: str
    photo_url: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class MentorshipCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    alumni_id: UUID
    project_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    objective: Optional[str] = Field(default=None, max_length=20000)
    status: Literal["active", "paused", "completed", "cancelled"] = "active"
    started_at: Optional[date] = None
    ended_at: Optional[date] = None


class MentorshipUpdate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)
    project_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    title: Optional[str] = Field(default=None, min_length=1, max_length=200)
    objective: Optional[str] = Field(default=None, max_length=20000)
    status: Literal["active", "paused", "completed", "cancelled"] = None
    started_at: Optional[date] = None
    ended_at: Optional[date] = None


    @field_validator("started_at")
    @classmethod
    def start_required(cls, value):
        if value is None:
            raise ValueError("La date de début ne peut pas être vide.")
        return value

class MentorshipRead(BaseModel):
    id: UUID
    alumni_id: UUID
    project_id: Optional[UUID]
    pole_id: Optional[UUID]
    assigned_by: Optional[UUID]
    title: Optional[str]
    objective: Optional[str]
    status: str
    started_at: date
    ended_at: Optional[date]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
