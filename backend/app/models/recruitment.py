import uuid
from datetime import date, datetime

from sqlalchemy import String, Text, Date, DateTime, ForeignKey, Boolean, Numeric, UniqueConstraint
from app.db.types import GUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class RecruitmentCampaign(Base):
    __tablename__ = "recruitment_campaigns"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID,
        primary_key=True,
        default=uuid.uuid4,
    )

    season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("seasons.id"),
        nullable=True,
    )

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    created_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Application(Base):
    __tablename__ = "applications"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    campaign_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"),
        nullable=False,
    )

    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    gender: Mapped[str | None] = mapped_column(String(40), nullable=True)

    email: Mapped[str] = mapped_column(String(150), nullable=False, index=True)
    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)

    department: Mapped[str | None] = mapped_column(String(150), nullable=True)
    study_level: Mapped[str | None] = mapped_column(String(100), nullable=True)
    class_name: Mapped[str | None] = mapped_column(String(120), nullable=True)

    motivation: Mapped[str | None] = mapped_column(Text, nullable=True)
    known_enactus_from: Mapped[str | None] = mapped_column(Text, nullable=True)
    enactus_knowledge: Mapped[str | None] = mapped_column(Text, nullable=True)
    other_clubs: Mapped[str | None] = mapped_column(Text, nullable=True)
    contribution: Mapped[str | None] = mapped_column(Text, nullable=True)
    project_ideas: Mapped[str | None] = mapped_column(Text, nullable=True)
    leadership_profile: Mapped[str | None] = mapped_column(Text, nullable=True)
    preferred_pole: Mapped[str | None] = mapped_column(String(150), nullable=True)
    project_interest: Mapped[str | None] = mapped_column(String(180), nullable=True)
    associative_experience: Mapped[str | None] = mapped_column(Text, nullable=True)
    availability: Mapped[str | None] = mapped_column(Text, nullable=True)
    public_comment: Mapped[str | None] = mapped_column(Text, nullable=True)
    interview_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    interview_location: Mapped[str | None] = mapped_column(String(180), nullable=True)
    interview_link: Mapped[str | None] = mapped_column(Text, nullable=True)
    interview_jury: Mapped[str | None] = mapped_column(Text, nullable=True)
    interview_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    cv_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    motivation_letter_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    attachment_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    status: Mapped[str] = mapped_column(String(50), default="received")
    tracking_code: Mapped[str | None] = mapped_column(
        String(32),
        nullable=True,
        unique=True,
        index=True,
    )
    final_score: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)

    converted_user_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ApplicationReview(Base):
    __tablename__ = "application_reviews"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    application_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("applications.id", ondelete="CASCADE"),
        nullable=False,
    )

    reviewer_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    score: Mapped[float | None] = mapped_column(Numeric(5, 2), nullable=True)

    comment: Mapped[str | None] = mapped_column(Text, nullable=True)

    recommendation: Mapped[str] = mapped_column(String(50), default="reserve")

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("application_id", "reviewer_id", name="uq_application_reviewer"),
    )
