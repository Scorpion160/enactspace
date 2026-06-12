import uuid
from datetime import datetime

from sqlalchemy import String, Text, DateTime, ForeignKey, Integer, UniqueConstraint
from app.db.types import GUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class EngagementPoint(Base):
    __tablename__ = "engagement_points"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("seasons.id"),
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

    source_type: Mapped[str] = mapped_column(String(80), nullable=False)
    source_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), nullable=True)

    points: Mapped[int] = mapped_column(Integer, nullable=False)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    awarded_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class Badge(Base):
    __tablename__ = "badges"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    label: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    icon_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class UserBadge(Base):
    __tablename__ = "user_badges"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    badge_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("badges.id", ondelete="CASCADE"),
        nullable=False,
    )

    season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("seasons.id"),
        nullable=True,
    )

    awarded_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    awarded_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("user_id", "badge_id", "season_id", name="uq_user_badge_season"),
    )
