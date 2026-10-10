from app.core.time import utc_now
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class UserAcademicHistory(Base):
    __tablename__ = "user_academic_history"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(), primary_key=True, default=uuid.uuid4
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    season_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("seasons.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    department: Mapped[str] = mapped_column(String(150), nullable=False)
    cursus: Mapped[str] = mapped_column(String(80), nullable=False)
    study_level: Mapped[str] = mapped_column(String(80), nullable=False)
    specialty: Mapped[str | None] = mapped_column(String(150), nullable=True)
    promotion: Mapped[str | None] = mapped_column(String(100), nullable=True)
    progression_action: Mapped[str] = mapped_column(
        String(30), default="initial", nullable=False
    )
    confirmed_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, onupdate=utc_now, nullable=False
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id", "season_id", name="uq_user_academic_history_user_season"
        ),
    )
