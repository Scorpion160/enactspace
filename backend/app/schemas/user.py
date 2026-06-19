from pydantic import BaseModel, EmailStr
from typing import Optional, List
from uuid import UUID
from datetime import datetime


class UserBase(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    phone: Optional[str] = None
    gender: Optional[str] = None
    profile_type: str = "enacteur"
    department: Optional[str] = None
    study_level: Optional[str] = None
    promotion: Optional[str] = None
    bio: Optional[str] = None
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None


class UserCreate(UserBase):
    password: str


class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    photo_url: Optional[str] = None
    department: Optional[str] = None
    study_level: Optional[str] = None
    promotion: Optional[str] = None
    bio: Optional[str] = None
    linkedin_url: Optional[str] = None
    github_url: Optional[str] = None
    portfolio_url: Optional[str] = None


class UserAdminUpdate(BaseModel):
    status: Optional[str] = None
    email_verified: Optional[bool] = None
    is_active: Optional[bool] = None
    department: Optional[str] = None
    study_level: Optional[str] = None
    promotion: Optional[str] = None


class UserRoleAssign(BaseModel):
    role_names: List[str]


class UserRead(UserBase):
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
