"""Internal recruitment interview drafts; never public, never email candidates."""
import uuid
from datetime import datetime
from sqlalchemy import Column, DateTime, ForeignKey, Integer, Index, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.db.database import Base
from app.db.types import GUID
from app.core.time import utc_now


class RecruitmentInterviewDraft(Base):
    __tablename__ = "recruitment_interview_drafts"
    application_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True
    )
    campaign_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), nullable=False
    )
    starts_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    jury_member_ids: Mapped[list] = mapped_column(JSON, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    updated_by: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("users.id", ondelete="SET NULL"))
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utc_now)
    __table_args__ = (Index("ix_recruitment_draft_campaign_start", "campaign_id", "starts_at"),)


class RecruitmentInterviewPrepNote(Base):
    __tablename__ = "recruitment_interview_prep_notes"
    application_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    body: Mapped[str] = mapped_column(Text, nullable=False, default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, default=utc_now)
