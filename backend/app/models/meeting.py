from app.core.time import utc_now
import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class Meeting(Base):
    __tablename__ = "meetings"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(), primary_key=True, default=uuid.uuid4
    )
    room_key: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(30), default="scheduled", nullable=False)
    scope_type: Mapped[str] = mapped_column(String(30), default="club", nullable=False)
    scope_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), nullable=True)
    provider: Mapped[str] = mapped_column(String(40), default="jitsi", nullable=False)
    server_url: Mapped[str] = mapped_column(String(300), nullable=False)

    scheduled_start: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    scheduled_end: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    created_by: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    start_with_audio_muted: Mapped[bool] = mapped_column(Boolean, default=True)
    start_with_video_muted: Mapped[bool] = mapped_column(Boolean, default=True)
    lobby_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    recording_enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)

    __table_args__ = (
        CheckConstraint(
            "status IN ('scheduled','live','ended','cancelled')",
            name="ck_meetings_status",
        ),
        CheckConstraint(
            "scope_type IN ('club','pole','project','custom')",
            name="ck_meetings_scope_type",
        ),
        CheckConstraint(
            "scheduled_end IS NULL OR scheduled_start IS NULL "
            "OR scheduled_end > scheduled_start",
            name="ck_meetings_schedule_order",
        ),
    )


class MeetingMember(Base):
    __tablename__ = "meeting_members"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(), primary_key=True, default=uuid.uuid4
    )
    meeting_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("meetings.id", ondelete="CASCADE"), nullable=False
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    role: Mapped[str] = mapped_column(String(30), default="participant", nullable=False)
    invited_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    joined_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    left_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    __table_args__ = (
        UniqueConstraint("meeting_id", "user_id", name="uq_meeting_member"),
        CheckConstraint(
            "role IN ('host','cohost','participant')",
            name="ck_meeting_members_role",
        ),
    )
