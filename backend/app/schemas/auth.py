from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


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
