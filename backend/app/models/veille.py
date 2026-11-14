"""Veille records complement operational data; decisions never come from a score."""
import uuid
from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, UniqueConstraint, Index, text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.time import utc_now
from app.db.database import Base
from app.db.types import GUID


class Record:
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("users.id"), nullable=True)


class Scope:
    season_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("seasons.id"), nullable=True)
    pole_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("poles.id"), nullable=True)
    project_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("projects.id"), nullable=True)


class VeilleSettings(Base):
    __tablename__ = "veille_settings"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    version: Mapped[int] = mapped_column(Integer, default=1)
    reminders_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    effective_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    quiet_start_hour: Mapped[int] = mapped_column(Integer, default=21)
    quiet_end_hour: Mapped[int] = mapped_column(Integer, default=7)
    escalation_days: Mapped[int] = mapped_column(Integer, default=2)
    response_days: Mapped[int] = mapped_column(Integer, default=7)
    appeal_days: Mapped[int] = mapped_column(Integer, default=14)
    weekly_day: Mapped[int] = mapped_column(Integer, default=0)
    report_hour: Mapped[int] = mapped_column(Integer, default=8)
    auto_reports: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)


class VeilleRule(Record, Base):
    __tablename__ = "veille_rules"
    title: Mapped[str] = mapped_column(String(200))
    content: Mapped[str] = mapped_column(Text)
    effective_from: Mapped[date] = mapped_column(Date)
    allowed_actions: Mapped[list] = mapped_column(JSON, default=list)
    maximum_amount: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    retired: Mapped[bool] = mapped_column(Boolean, default=False)


class VeillePlan(Record, Scope, Base):
    __tablename__ = "veille_plans"
    owner_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id"))
    title: Mapped[str] = mapped_column(String(200))
    expected_result: Mapped[str] = mapped_column(Text)
    availability: Mapped[str] = mapped_column(Text)
    due_date: Mapped[datetime] = mapped_column(DateTime)
    status: Mapped[str] = mapped_column(String(30), default="active")
    course_ids: Mapped[list] = mapped_column(JSON, default=list)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    version: Mapped[int] = mapped_column(Integer, default=1)


class VeilleBlocker(Record, Base):
    __tablename__ = "veille_blockers"
    __table_args__ = (Index("uq_veille_open_blocker_task", "task_id", unique=True, sqlite_where=text("status = 'open'"), postgresql_where=text("status = 'open'")),)
    task_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)
    owner_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id"))
    title: Mapped[str] = mapped_column(String(200))
    cause: Mapped[str] = mapped_column(String(40))
    description: Mapped[str] = mapped_column(Text)
    requested_help: Mapped[str] = mapped_column(Text)
    next_action: Mapped[str] = mapped_column(Text)
    review_at: Mapped[datetime] = mapped_column(DateTime)
    status: Mapped[str] = mapped_column(String(30), default="open")
    resolution: Mapped[str | None] = mapped_column(Text, nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1)


class VeilleReview(Record, Base):
    __tablename__ = "veille_reviews"
    task_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)
    task_title: Mapped[str] = mapped_column(String(200))
    verdict: Mapped[str] = mapped_column(String(30))
    feedback: Mapped[str] = mapped_column(Text)
    quality: Mapped[int | None] = mapped_column(Integer, nullable=True)
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class VeilleReport(Record, Scope, Base):
    __tablename__ = "veille_reports"
    title: Mapped[str] = mapped_column(String(200))
    kind: Mapped[str] = mapped_column(String(30))
    period_start: Mapped[date] = mapped_column(Date)
    period_end: Mapped[date] = mapped_column(Date)
    observations: Mapped[str] = mapped_column(Text)
    next_actions: Mapped[str] = mapped_column(Text)
    snapshot: Mapped[dict] = mapped_column(JSON)
    automatic_key: Mapped[str | None] = mapped_column(String(100), unique=True, nullable=True)


class VeilleLeave(Record, Base):
    __tablename__ = "veille_leaves"
    member_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id"))
    start_date: Mapped[date] = mapped_column(Date)
    end_date: Mapped[date] = mapped_column(Date)
    reason: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(30), default="requested")
    response: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewed_by_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("users.id"), nullable=True)
    version: Mapped[int] = mapped_column(Integer, default=1)


class VeilleCase(Record, Base):
    __tablename__ = "veille_cases"
    member_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id"))
    bureau_reviewer_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("users.id"), nullable=True)
    task_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True)
    attendance_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("attendance_records.id"), nullable=True)
    rule_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("veille_rules.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(200))
    facts: Mapped[str] = mapped_column(Text)
    observed_at: Mapped[date] = mapped_column(Date, default=lambda: utc_now().date())
    status: Mapped[str] = mapped_column(String(30), default="draft")
    version: Mapped[int] = mapped_column(Integer, default=1)
    response_deadline: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    proposed_action: Mapped[str | None] = mapped_column(String(40), nullable=True)
    proposal: Mapped[str | None] = mapped_column(Text, nullable=True)
    decision_action: Mapped[str | None] = mapped_column(String(40), nullable=True)
    decision: Mapped[str | None] = mapped_column(Text, nullable=True)
    decided_by_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("users.id"), nullable=True)
    decided_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    endorsement: Mapped[str | None] = mapped_column(Text, nullable=True)
    endorsed_by_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("users.id"), nullable=True)
    appeal_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    appeal_count: Mapped[int] = mapped_column(Integer, default=0)
    accepted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    amount: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    fee_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), ForeignKey("fees.id"), nullable=True)


class VeilleEvent(Record, Base):
    __tablename__ = "veille_events"
    entity_type: Mapped[str] = mapped_column(String(40), index=True)
    entity_id: Mapped[uuid.UUID] = mapped_column(GUID(), index=True)
    action: Mapped[str] = mapped_column(String(60))
    message: Mapped[str] = mapped_column(Text)
    details: Mapped[dict] = mapped_column(JSON, default=dict)


class VeilleReminder(Record, Base):
    __tablename__ = "veille_reminders"
    task_id: Mapped[uuid.UUID] = mapped_column(GUID())
    recipient_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id"))
    due_date: Mapped[datetime] = mapped_column(DateTime)
    kind: Mapped[str] = mapped_column(String(30))
    __table_args__ = (UniqueConstraint("task_id", "recipient_id", "due_date", "kind", name="uq_veille_reminder"),)
