from pydantic import BaseModel, field_validator
from app.core.account_identity import normalize_username, validate_join_year
from typing import Optional, List
from uuid import UUID
from datetime import datetime


class UserBase(BaseModel):
    first_name: str
    last_name: str
    email: str
    username: Optional[str] = None
    phone: Optional[str] = None
    gender: Optional[str] = None
    profile_type: str = "enacteur"
    department: Optional[str] = None
    cursus: Optional[str] = None
    study_level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    enactus_join_year: Optional[int] = None
    bio: Optional[str] = None
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None


class UserCreate(UserBase):
    # Accepted for compatibility; managers never choose the member's final password.
    password: Optional[str] = None

    _username = field_validator('username')(normalize_username)
    _join_year = field_validator('enactus_join_year')(validate_join_year)


class UserUpdate(BaseModel):
    enactus_join_year: Optional[int] = None
    _join_year = field_validator('enactus_join_year')(validate_join_year)
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    photo_url: Optional[str] = None
    department: Optional[str] = None
    cursus: Optional[str] = None
    study_level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    bio: Optional[str] = None
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None


class UserAdminUpdate(BaseModel):
    enactus_join_year: Optional[int] = None
    _join_year = field_validator('enactus_join_year')(validate_join_year)
    status: Optional[str] = None
    email_verified: Optional[bool] = None
    is_active: Optional[bool] = None
    department: Optional[str] = None
    cursus: Optional[str] = None
    study_level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None


class UserRoleAssign(BaseModel):
    role_names: List[str]


class UserRead(UserBase):
    credential_setup_required: bool = False
    credential_activated_at: Optional[datetime] = None
    onboarding_required: bool = False
    onboarding_completed_at: Optional[datetime] = None
    id: UUID
    photo_url: Optional[str] = None
    core_pole_id: Optional[UUID] = None
    pole_position: Optional[str] = None
    status: str
    email_verified: bool
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserWithRolesRead(UserRead):
    roles: List[str] = []
    can_review_join_requests: bool = False
    can_access_recruitment: bool = False


class UserDirectoryRead(BaseModel):
    id: UUID
    first_name: str
    last_name: str
    email: str
    username: Optional[str] = None
    phone: Optional[str] = None
    photo_url: Optional[str] = None
    gender: Optional[str] = None
    profile_type: str
    department: Optional[str] = None
    cursus: Optional[str] = None
    study_level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    enactus_join_year: Optional[int] = None
    bio: Optional[str] = None
    core_pole_id: Optional[UUID] = None
    pole_position: Optional[str] = None
    status: str
    roles: List[str] = []
    created_at: datetime

    class Config:
        from_attributes = True
