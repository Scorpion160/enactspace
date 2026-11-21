"""Campaign-specific interview planning policy and jury availability."""
import uuid
from datetime import datetime
from sqlalchemy import DateTime, ForeignKey, Integer, Boolean, String, JSON, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.database import Base
from app.db.types import GUID
from app.core.time import utc_now

class RecruitmentInterviewPolicy(Base):
    __tablename__ = "recruitment_interview_policies"
    campaign_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), primary_key=True)
    duration_minutes: Mapped[int] = mapped_column(Integer, nullable=False, default=20)
    daily_windows: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    default_mode: Mapped[str] = mapped_column(String(20), nullable=False, default="in_person")
    default_location: Mapped[str | None] = mapped_column(String(180), nullable=True)
    respect_candidate_availability: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)

class RecruitmentJuryAvailability(Base):
    __tablename__ = "recruitment_jury_availability"
    campaign_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), primary_key=True)
    user_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    windows: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
