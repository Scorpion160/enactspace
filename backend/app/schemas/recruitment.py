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
    gender: Optional[str] = None
    email: EmailStr
    phone: Optional[str] = None
    department: Optional[str] = None
    study_level: Optional[str] = None
    class_name: Optional[str] = None
    motivation: Optional[str] = None
    known_enactus_from: Optional[str] = None
    enactus_knowledge: Optional[str] = None
    other_clubs: Optional[str] = None
    contribution: Optional[str] = None
    project_ideas: Optional[str] = None
    leadership_profile: Optional[str] = None
    preferred_pole: Optional[str] = None
    project_interest: Optional[str] = None
    associative_experience: Optional[str] = None
    availability: Optional[str] = None
    public_comment: Optional[str] = None
    cv_url: Optional[str] = None
    motivation_letter_url: Optional[str] = None
    attachment_url: Optional[str] = None


class ApplicationUpdate(BaseModel):
    gender: Optional[str] = None
    phone: Optional[str] = None
    department: Optional[str] = None
    study_level: Optional[str] = None
    class_name: Optional[str] = None
    motivation: Optional[str] = None
    known_enactus_from: Optional[str] = None
    enactus_knowledge: Optional[str] = None
    other_clubs: Optional[str] = None
    contribution: Optional[str] = None
    project_ideas: Optional[str] = None
    leadership_profile: Optional[str] = None
    preferred_pole: Optional[str] = None
    project_interest: Optional[str] = None
    associative_experience: Optional[str] = None
    availability: Optional[str] = None
    public_comment: Optional[str] = None
    cv_url: Optional[str] = None
    motivation_letter_url: Optional[str] = None
    attachment_url: Optional[str] = None
    status: Optional[str] = None


class ApplicationInterviewSchedule(BaseModel):
    interview_at: datetime
    interview_location: Optional[str] = None
    interview_link: Optional[str] = None
    interview_jury: Optional[str] = None
    interview_note: Optional[str] = None


class ApplicationRead(BaseModel):
    id: UUID
    campaign_id: UUID
    first_name: str
    last_name: str
    gender: Optional[str]
    email: EmailStr
    phone: Optional[str]
    department: Optional[str]
    study_level: Optional[str]
    class_name: Optional[str]
    motivation: Optional[str]
    known_enactus_from: Optional[str]
    enactus_knowledge: Optional[str]
    other_clubs: Optional[str]
    contribution: Optional[str]
    project_ideas: Optional[str]
    leadership_profile: Optional[str]
    preferred_pole: Optional[str]
    project_interest: Optional[str]
    associative_experience: Optional[str]
    availability: Optional[str]
    public_comment: Optional[str]
    interview_at: Optional[datetime]
    interview_location: Optional[str]
    interview_link: Optional[str]
    interview_jury: Optional[str]
    interview_note: Optional[str]
    cv_url: Optional[str]
    motivation_letter_url: Optional[str]
    attachment_url: Optional[str]
    status: str
    tracking_code: Optional[str]
    final_score: Optional[float]
    converted_user_id: Optional[UUID]
    is_anonymized: bool = False
    anonymous_code: Optional[str] = None
    can_convert: bool = False
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ApplicationStatusChange(BaseModel):
    status: str


class ApplicationTrackingRequest(BaseModel):
    application_id: str
    email: EmailStr


class ApplicationTrackingRead(BaseModel):
    application_id: UUID
    tracking_code: str
    campaign_title: str
    first_name: str
    last_name: str
    email: EmailStr
    department: Optional[str] = None
    study_level: Optional[str] = None
    preferred_pole: Optional[str] = None
    project_interest: Optional[str] = None
    status: str
    submitted_at: datetime
    updated_at: datetime
    next_step: str
    candidate_message: Optional[str] = None
    interview_details: Optional[str] = None
    final_result: Optional[str] = None
    account_created: bool


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
    profile_type: Optional[str] = None
    core_pole_id: Optional[UUID] = None
    support_pole_ids: list[UUID] = []
    project_id: Optional[UUID] = None
