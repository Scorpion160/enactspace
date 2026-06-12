from pydantic import BaseModel, EmailStr
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class RecruitmentCampaignCreate(BaseModel):
    season_id: Optional[UUID] = None
    title: str
    description: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    is_active: bool = True


class RecruitmentCampaignUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    is_active: Optional[bool] = None


class RecruitmentCampaignRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    title: str
    description: Optional[str]
    start_date: Optional[date]
    end_date: Optional[date]
    is_active: bool
    created_by: Optional[UUID]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ApplicationCreate(BaseModel):
    campaign_id: UUID
    first_name: str
    last_name: str
    email: EmailStr
    phone: Optional[str] = None
    department: Optional[str] = None
    study_level: Optional[str] = None
    motivation: Optional[str] = None
    known_enactus_from: Optional[str] = None
    enactus_knowledge: Optional[str] = None
    other_clubs: Optional[str] = None
    contribution: Optional[str] = None
    project_ideas: Optional[str] = None
    leadership_profile: Optional[str] = None
    cv_url: Optional[str] = None
    motivation_letter_url: Optional[str] = None


class ApplicationUpdate(BaseModel):
    phone: Optional[str] = None
    department: Optional[str] = None
    study_level: Optional[str] = None
    motivation: Optional[str] = None
    known_enactus_from: Optional[str] = None
    enactus_knowledge: Optional[str] = None
    other_clubs: Optional[str] = None
    contribution: Optional[str] = None
    project_ideas: Optional[str] = None
    leadership_profile: Optional[str] = None
    cv_url: Optional[str] = None
    motivation_letter_url: Optional[str] = None
    status: Optional[str] = None


class ApplicationRead(BaseModel):
    id: UUID
    campaign_id: UUID
    first_name: str
    last_name: str
    email: EmailStr
    phone: Optional[str]
    department: Optional[str]
    study_level: Optional[str]
    motivation: Optional[str]
    known_enactus_from: Optional[str]
    enactus_knowledge: Optional[str]
    other_clubs: Optional[str]
    contribution: Optional[str]
    project_ideas: Optional[str]
    leadership_profile: Optional[str]
    cv_url: Optional[str]
    motivation_letter_url: Optional[str]
    status: str
    final_score: Optional[float]
    converted_user_id: Optional[UUID]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ApplicationStatusChange(BaseModel):
    status: str


class ApplicationReviewCreate(BaseModel):
    application_id: UUID
    score: Optional[float] = None
    comment: Optional[str] = None
    recommendation: str = "reserve"


class ApplicationReviewUpdate(BaseModel):
    score: Optional[float] = None
    comment: Optional[str] = None
    recommendation: Optional[str] = None


class ApplicationReviewRead(BaseModel):
    id: UUID
    application_id: UUID
    reviewer_id: UUID
    score: Optional[float]
    comment: Optional[str]
    recommendation: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ConvertApplicationToUserRequest(BaseModel):
    password: str