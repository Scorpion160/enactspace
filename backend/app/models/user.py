from app.core.time import utc_now
import uuid
from datetime import datetime

from sqlalchemy import String, Text, Boolean, DateTime, ForeignKey, Index, Integer, CheckConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.db.types import GUID
from app.core.account_identity import generated_username


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)

    email: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        unique=True,
        index=True,
    )

    username: Mapped[str] = mapped_column(String(50), nullable=False, default=generated_username)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)
    gender: Mapped[str | None] = mapped_column(String(20), nullable=True)
    profile_type: Mapped[str] = mapped_column(String(30), default="enacteur")

    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)

    photo_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    department: Mapped[str | None] = mapped_column(String(150), nullable=True)
    cursus: Mapped[str | None] = mapped_column(String(80), nullable=True)
    study_level: Mapped[str | None] = mapped_column(String(100), nullable=True)
    specialty: Mapped[str | None] = mapped_column(String(150), nullable=True)
    promotion: Mapped[str | None] = mapped_column(String(100), nullable=True)
    enactus_join_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    academic_confirmed_season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("seasons.id", ondelete="SET NULL"), nullable=True
    )
    academic_confirmed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    bio: Mapped[str | None] = mapped_column(Text, nullable=True)

    linkedin_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    github_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    portfolio_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    status: Mapped[str] = mapped_column(String(50), default="pending")

    email_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    credential_setup_required: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    credential_activated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    onboarding_required: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false", nullable=False)
    onboarding_completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)

    user_roles = relationship(
        "UserRole",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index("ux_users_lower_email", func.lower(email), unique=True),
        Index("ux_users_lower_username", func.lower(username), unique=True),
    )


class PasswordResetOtp(Base):
    __tablename__ = "password_reset_otps"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )
    otp_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    failed_attempts: Mapped[int] = mapped_column(Integer, default=0, server_default="0", nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)

    user = relationship("User")

    __table_args__ = (CheckConstraint("failed_attempts >= 0 AND failed_attempts <= 5", name="ck_password_reset_failed_attempts"),)
