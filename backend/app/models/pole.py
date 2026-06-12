import uuid
from datetime import date, datetime

from sqlalchemy import String, Text, DateTime, Date, Boolean, ForeignKey, UniqueConstraint
from app.db.types import GUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class Pole(Base):
    __tablename__ = "poles"

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

    name: Mapped[str] = mapped_column(String(100), nullable=False)
    short_name: Mapped[str | None] = mapped_column(String(50), nullable=True)
    type: Mapped[str] = mapped_column(String(50), nullable=False)

    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    objectives: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class PoleMember(Base):
    __tablename__ = "pole_members"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    pole_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("poles.id", ondelete="CASCADE"),
        nullable=False,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    position: Mapped[str] = mapped_column(String(50), default="membre")
    joined_at: Mapped[date] = mapped_column(Date, default=date.today)
    left_at: Mapped[date | None] = mapped_column(Date, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    __table_args__ = (
        UniqueConstraint("pole_id", "user_id", name="uq_pole_user"),
    )
