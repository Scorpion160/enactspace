import uuid
from datetime import date, datetime

from sqlalchemy import String, Text, Date, DateTime, ForeignKey, Boolean
from app.db.types import GUID

from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class AlumniProfile(Base):
    __tablename__ = "alumni_profiles"

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
    )

    graduation_year: Mapped[int | None] = mapped_column(nullable=True)

    current_company: Mapped[str | None] = mapped_column(String(150), nullable=True)
    current_position: Mapped[str | None] = mapped_column(String(150), nullable=True)
    domain: Mapped[str | None] = mapped_column(String(150), nullable=True)

    skills: Mapped[str | None] = mapped_column(Text, nullable=True)
    experience_summary: Mapped[str | None] = mapped_column(Text, nullable=True)

    available_for_mentoring: Mapped[bool] = mapped_column(Boolean, default=True)

    linkedin_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    portfolio_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    visibility: Mapped[str] = mapped_column(String(50), default="internal")

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    user = relationship("User")

    @property
    def display_name(self) -> str:
        return f"{self.user.first_name} {self.user.last_name}".strip()

    @property
    def photo_url(self) -> str | None:
        return self.user.photo_url


class Mentorship(Base):
    __tablename__ = "mentorships"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    alumni_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=True,
    )

    pole_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("poles.id", ondelete="CASCADE"),
        nullable=True,
    )

    assigned_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    title: Mapped[str | None] = mapped_column(String(200), nullable=True)
    objective: Mapped[str | None] = mapped_column(Text, nullable=True)

    status: Mapped[str] = mapped_column(String(50), default="active")

    started_at: Mapped[date] = mapped_column(Date, default=date.today)
    ended_at: Mapped[date | None] = mapped_column(Date, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
