from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator
from app.core.account_identity import normalize_username, validate_join_year


class LoginRequest(BaseModel):
    identifier: str | None = None
    email: str | None = None
    password: str
    platform: Literal["web", "android", "ios", "api", "unknown"] | None = None

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str | None = None
    token_type: str = "bearer"
    expires_in: int | None = None
    refresh_expires_in: int | None = None


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class AuthSessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    expires_at: datetime
    last_used_at: datetime | None
    revoked_at: datetime | None
    user_agent: str | None
    platform: str | None


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetConfirm(BaseModel):
    email: EmailStr
    otp: str = Field(pattern=r"^[0-9]{6}$", max_length=6)
    new_password: str


class PasswordResetRequestRead(BaseModel):
    message: str
    debug_otp: str | None = None


class JoinRequestCreate(BaseModel):
    profile_type: str = "enacteur"
    gender: str
    first_name: str
    last_name: str
    username: str
    email: EmailStr
    password: str
    phone: str
    photo_url: str | None = None
    department: str
    level: str | None = None
    promotion: str | None = None
    enactus_join_year: int | None = None
    skills: str | None = None
    linkedin_url: str | None = None
    github_url: str | None = None
    portfolio_url: str | None = None
    motivation: str | None = None

    _username = field_validator('username')(normalize_username)
    _join_year = field_validator('enactus_join_year')(validate_join_year)

class JoinRequestRead(BaseModel):
    message: str
    user_id: str
