from pydantic import BaseModel
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class AlumniProfileCreate(BaseModel):
    user_id: UUID
    graduation_year: Optional[int] = None
    current_company: Optional[str] = None
    current_position: Optional[str] = None
    domain: Optional[str] = None
    skills: Optional[str] = None
    experience_summary: Optional[str] = None
    available_for_mentoring: bool = True
    linkedin_url: Optional[str] = None
    portfolio_url: Optional[str] = None
    visibility: str = "internal"


class AlumniProfileUpdate(BaseModel):
    graduation_year: Optional[int] = None
    current_company: Optional[str] = None
    current_position: Optional[str] = None
    domain: Optional[str] = None
    skills: Optional[str] = None
    experience_summary: Optional[str] = None
    available_for_mentoring: Optional[bool] = None
    linkedin_url: Optional[str] = None
    portfolio_url: Optional[str] = None
    visibility: Optional[str] = None


class AlumniProfileRead(BaseModel):
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
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class MentorshipCreate(BaseModel):
    alumni_id: UUID
    project_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    title: Optional[str] = None
    objective: Optional[str] = None
    status: str = "active"
    started_at: Optional[date] = None
    ended_at: Optional[date] = None


class MentorshipUpdate(BaseModel):
    project_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    title: Optional[str] = None
    objective: Optional[str] = None
    status: Optional[str] = None
    started_at: Optional[date] = None
    ended_at: Optional[date] = None


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