import uuid
from datetime import datetime

from sqlalchemy import String, Text, DateTime, ForeignKey, Boolean
from app.db.types import GUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class Notification(Base):
    __tablename__ = "notifications"

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

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)

    type: Mapped[str | None] = mapped_column(String(80), nullable=True)

    is_read: Mapped[bool] = mapped_column(Boolean, default=False)

    related_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    related_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    read_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
