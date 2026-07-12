import uuid
from datetime import datetime

from sqlalchemy import String, Text, DateTime, ForeignKey, Boolean, Integer, Numeric
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class AttendanceSetting(Base):
    __tablename__ = "attendance_settings"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    key: Mapped[str] = mapped_column(String(120), unique=True, nullable=False)
    value: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AttendanceSession(Base):
    __tablename__ = "attendance_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    session_type: Mapped[str] = mapped_column(String(80), default="general_meeting")
    scope_type: Mapped[str] = mapped_column(String(40), default="club")
    group_name: Mapped[str | None] = mapped_column(String(150), nullable=True)
    status: Mapped[str] = mapped_column(String(40), default="draft")

    event_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("events.id"),
        nullable=True,
    )

    pole_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("poles.id"),
        nullable=True,
    )

    project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("projects.id"),
        nullable=True,
    )

    created_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    qr_token: Mapped[str | None] = mapped_column(String(255), nullable=True)

    scheduled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    checkin_start: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    checkin_end: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    late_after_minutes: Mapped[int] = mapped_column(Integer, default=15)

    is_closed: Mapped[bool] = mapped_column(Boolean, default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AttendanceExpectedMember(Base):
    __tablename__ = "attendance_expected_members"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    session_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("attendance_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    is_required: Mapped[bool] = mapped_column(Boolean, default=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    session_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("attendance_sessions.id", ondelete="CASCADE"),
        nullable=False,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    status: Mapped[str] = mapped_column(String(50), nullable=False)

    checkin_time: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    delay_minutes: Mapped[int | None] = mapped_column(Integer, nullable=True)

    recorded_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )
    source: Mapped[str] = mapped_column(String(40), default="manual")
    recorded_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    justification: Mapped[str | None] = mapped_column(Text, nullable=True)
    justification_status: Mapped[str] = mapped_column(
        String(40),
        default="not_submitted",
    )
    justification_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    justification_file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    justification_file_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    is_justified: Mapped[bool] = mapped_column(Boolean, default=False)

    penalty_amount: Mapped[float] = mapped_column(Numeric(10, 2), default=0)

    penalty_fee_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("fees.id"),
        nullable=True,
    )

    note: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    @property
    def member_id(self):
        return self.user_id

    @property
    def arrival_time(self):
        return self.checkin_time
