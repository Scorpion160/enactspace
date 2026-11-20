from app.core.time import utc_now
import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class EmailDelivery(Base):
    __tablename__ = "email_deliveries"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    notification_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("notifications.id", ondelete="CASCADE"), nullable=True, index=True
    )
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    recipient_email: Mapped[str] = mapped_column(String(320), nullable=False)
    subject: Mapped[str] = mapped_column(String(255), nullable=False)
    text_body: Mapped[str] = mapped_column(Text, nullable=False)
    html_body: Mapped[str | None] = mapped_column(Text, nullable=True)
    dedupe_key: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    attempt_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    next_attempt_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)
    processing_started_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    provider_message_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    last_error_code: Mapped[str | None] = mapped_column(String(120), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, onupdate=utc_now, nullable=False
    )
    sent_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'processing', 'sent', 'retry', 'cancelled', 'dead')",
            name="ck_email_delivery_status",
        ),
        CheckConstraint("attempt_count >= 0", name="ck_email_delivery_attempt_count"),
        CheckConstraint(
            "((status = 'processing' AND processing_started_at IS NOT NULL) OR "
            "(status != 'processing' AND processing_started_at IS NULL))",
            name="ck_email_delivery_processing_lease",
        ),
        UniqueConstraint("dedupe_key", name="uq_email_deliveries_dedupe_key"),
        Index(
            "ix_email_delivery_claim",
            "status",
            "next_attempt_at",
            "processing_started_at",
            "created_at",
        ),
    )
