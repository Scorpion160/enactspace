from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator
from uuid import UUID
from datetime import date, datetime
from typing import Optional, Literal
from app.services.recruitment_questionnaire import effective_questions, questionnaire_version, LEGACY_FIELDS


def _clean_optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned or None


class RecruitmentPosition(BaseModel):
    title: str
    headcount: int = Field(default=1, ge=1)
    description: Optional[str] = None
    target_profile: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def normalize_aliases(cls, value):
        if isinstance(value, dict) and "title" not in value:
            value = dict(value)
            for alias in ("name", "position", "label"):
                if alias in value:
                    value["title"] = value[alias]
                    break
        return value

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Le poste ne peut pas être vide")
        return cleaned

    @field_validator("description", "target_profile")
    @classmethod
    def clean_optional_fields(cls, value: str | None) -> str | None:
        return _clean_optional_text(value)


class RecruitmentCommunicationAction(BaseModel):
    action: str
    channel: Optional[str] = None
    owner: Optional[str] = None
    timing: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def normalize_aliases(cls, value):
        if isinstance(value, dict) and "action" not in value:
            value = dict(value)
            for alias in ("title", "name", "label", "text"):
                if alias in value:
                    value["action"] = value[alias]
                    break
        return value

    @field_validator("action")
    @classmethod
    def validate_action(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("L'action de communication ne peut pas être vide")
        return cleaned

    @field_validator("channel", "owner", "timing")
    @classmethod
    def clean_optional_fields(cls, value: str | None) -> str | None:
        return _clean_optional_text(value)


class RecruitmentInterviewQuestion(BaseModel):
    question: str
    category: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def normalize_aliases(cls, value):
        if isinstance(value, dict) and "question" not in value:
            value = dict(value)
            for alias in ("text", "title", "label"):
                if alias in value:
                    value["question"] = value[alias]
                    break
        return value

    @field_validator("question")
    @classmethod
    def validate_question(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("La question d'entretien ne peut pas être vide")
        return cleaned

    @field_validator("category")
    @classmethod
    def clean_category(cls, value: str | None) -> str | None:
        return _clean_optional_text(value)


class RecruitmentApplicationQuestion(BaseModel):
    id: str = Field(min_length=1, max_length=64, pattern=r"^[a-zA-Z0-9_-]+$")
    label: str = Field(min_length=1, max_length=300)
    hint: str = Field(default="", max_length=500)
    section: Literal["motivation", "availability"] = "motivation"
    required: bool = False
    legacy_field: Optional[str] = None

    @field_validator("label", "hint")
    @classmethod
    def clean_text(cls, value):
        cleaned = value.strip()
        if not cleaned and value != "":
            raise ValueError("Le libellé ne peut pas être vide")
        return cleaned

    @field_validator("legacy_field")
    @classmethod
    def validate_mapping(cls, value):
        if value is not None and value not in LEGACY_FIELDS:
            raise ValueError("Champ de compatibilité invalide")
        return value


def validate_question_list(values):
    if values is not None and len({q.id for q in values}) != len(values):
        raise ValueError("Chaque question doit avoir un identifiant unique")
    if values is not None:
        mapped = [q.legacy_field for q in values if q.legacy_field]
        if len(set(mapped)) != len(mapped):
            raise ValueError("Un champ de compatibilité ne peut être utilisé qu’une fois")
    return values


class RecruitmentCampaignPublicRead(BaseModel):
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
    application_questions: list[RecruitmentApplicationQuestion] = Field(default_factory=list, max_length=40)
    questionnaire_version: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def public_questionnaire(cls, value):
        if not isinstance(value, dict):
            value = {name: getattr(value, name, None) for name in cls.model_fields}
        else:
            value = dict(value)
        questions = value.get('application_questions')
        value['application_questions'] = effective_questions(questions)
        value['questionnaire_version'] = questionnaire_version(questions)
        return value

    class Config:
        from_attributes = True


class RecruitmentCampaignCreate(BaseModel):
    season_id: Optional[UUID] = None
    title: str
    description: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    target_headcount: Optional[int] = Field(default=None, ge=1)
    positions: list[RecruitmentPosition] = Field(default_factory=list)
    target_profiles: list[str] = Field(default_factory=list)
    communication_actions: list[RecruitmentCommunicationAction] = Field(default_factory=list)
    interview_questions: list[RecruitmentInterviewQuestion] = Field(default_factory=list)
    application_questions: Optional[list[RecruitmentApplicationQuestion]] = Field(default=None, max_length=40)
    _question_ids = field_validator('application_questions')(validate_question_list)
    is_active: bool = True

    @field_validator("target_profiles")
    @classmethod
    def clean_target_profiles(cls, values: list[str]) -> list[str]:
        return [cleaned for value in values if (cleaned := value.strip())]


class RecruitmentCampaignUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    target_headcount: Optional[int] = Field(default=None, ge=1)
    positions: Optional[list[RecruitmentPosition]] = None
    target_profiles: Optional[list[str]] = None
    communication_actions: Optional[list[RecruitmentCommunicationAction]] = None
    interview_questions: Optional[list[RecruitmentInterviewQuestion]] = None
    application_questions: Optional[list[RecruitmentApplicationQuestion]] = Field(default=None, max_length=40)
    _question_ids = field_validator('application_questions')(validate_question_list)
    is_active: Optional[bool] = None

    @field_validator("target_profiles")
    @classmethod
    def clean_target_profiles(cls, values: list[str] | None) -> list[str] | None:
        if values is None:
            return None
        return [cleaned for value in values if (cleaned := value.strip())]


class RecruitmentCampaignRead(RecruitmentCampaignPublicRead):
    target_headcount: Optional[int] = None
    positions: Optional[list[RecruitmentPosition]] = None
    target_profiles: Optional[list[str]] = None
    communication_actions: Optional[list[RecruitmentCommunicationAction]] = None
    interview_questions: Optional[list[RecruitmentInterviewQuestion]] = None


class ApplicationCreate(BaseModel):
    questionnaire_answers: Optional[dict[str, str]] = None
    questionnaire_version: Optional[str] = None
    campaign_id: UUID
    first_name: str
    last_name: str
    gender: str
    email: EmailStr
    phone: str
    department: str
    study_level: str
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


class ApplicationHistoryRead(BaseModel):
    id: str
    kind: Literal["submission", "status", "interview", "integration"]
    title: str
    occurred_at: datetime
    actor_name: str
    from_status: Optional[str] = None
    to_status: Optional[str] = None
    scheduled_for: Optional[datetime] = None


class ApplicationRead(BaseModel):
    my_review: Optional[dict] = None
    screening_rubric: Optional[dict] = None
    screening_score: Optional[float] = None
    screening_review_count: int = 0
    screening_spread: Optional[float] = None
    history: list[ApplicationHistoryRead] = Field(default_factory=list)
    questionnaire_answers: Optional[list[dict[str, str]]] = None
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
    criteria_assessment: Optional[dict] = None
    application_id: UUID
    score: Optional[float] = Field(default=None, ge=0, le=20, allow_inf_nan=False)
    comment: Optional[str] = None
    recommendation: str = "reserve"


class ApplicationReviewUpdate(BaseModel):
    criteria_assessment: Optional[dict] = None
    score: Optional[float] = Field(default=None, ge=0, le=20, allow_inf_nan=False)
    comment: Optional[str] = None
    recommendation: Optional[str] = None


class ApplicationReviewRead(BaseModel):
    criteria_assessment: Optional[dict] = None
    reviewer_name: Optional[str] = None
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
    password: Optional[str] = None
    profile_type: Optional[str] = None
    core_pole_id: Optional[UUID] = None
    support_pole_ids: list[UUID] = []
    project_id: Optional[UUID] = None
