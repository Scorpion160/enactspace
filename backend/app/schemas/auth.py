from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr


class LoginRequest(BaseModel):
    email: str
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
    otp: str
    new_password: str


class PasswordResetRequestRead(BaseModel):
    message: str
    debug_otp: str | None = None


class JoinRequestCreate(BaseModel):
    profile_type: str = "enacteur"
    gender: str
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    phone: str | None = None
    photo_url: str | None = None
    department: str | None = None
    level: str | None = None
    promotion: str | None = None
    skills: str | None = None
    linkedin_url: str | None = None
    github_url: str | None = None
    portfolio_url: str | None = None
    motivation: str | None = None


class JoinRequestRead(BaseModel):
    message: str
    user_id: str
