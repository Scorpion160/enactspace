import uuid
from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class MobileMoneyTransaction(Base):
    __tablename__ = "mobile_money_transactions"
    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_mobile_money_amount_positive"),
        CheckConstraint("currency = 'XOF'", name="ck_mobile_money_currency_xof"),
        UniqueConstraint("idempotency_key", name="uq_mobile_money_idempotency_key"),
        UniqueConstraint(
            "provider_transaction_id",
            name="uq_mobile_money_provider_transaction_id",
        ),
        UniqueConstraint(
            "provider_invoice_token",
            name="uq_mobile_money_provider_invoice_token",
        ),
        Index("ix_mobile_money_member_status", "member_id", "status"),
        Index("ix_mobile_money_provider_status", "provider", "status"),
        Index("ix_mobile_money_created_at", "created_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    member_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    finance_item_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("fees.id"),
        nullable=True,
    )
    payment_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("payments.id"),
        nullable=True,
        unique=True,
    )

    provider: Mapped[str] = mapped_column(String(80), nullable=False)
    provider_transaction_id: Mapped[str | None] = mapped_column(
        String(180),
        nullable=True,
    )
    provider_invoice_token: Mapped[str | None] = mapped_column(
        String(180),
        nullable=True,
    )
    idempotency_key: Mapped[str] = mapped_column(String(180), nullable=False)

    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    currency: Mapped[str] = mapped_column(String(10), nullable=False, default="XOF")
    phone_number_masked: Mapped[str | None] = mapped_column(String(40), nullable=True)
    channel: Mapped[str | None] = mapped_column(String(80), nullable=True)

    status: Mapped[str] = mapped_column(String(50), nullable=False, default="created")
    provider_status: Mapped[str | None] = mapped_column(String(100), nullable=True)
    checkout_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    failure_code: Mapped[str | None] = mapped_column(String(100), nullable=True)
    failure_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    refunded_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_verified_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)


class MobileMoneyTransactionEvent(Base):
    __tablename__ = "mobile_money_transaction_events"
    __table_args__ = (
        Index("ix_mobile_money_event_transaction", "transaction_id"),
        Index("ix_mobile_money_event_received_at", "received_at"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    transaction_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("mobile_money_transactions.id", ondelete="CASCADE"),
        nullable=False,
    )
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    old_status: Mapped[str | None] = mapped_column(String(50), nullable=True)
    new_status: Mapped[str | None] = mapped_column(String(50), nullable=True)
    provider_event_id: Mapped[str | None] = mapped_column(String(180), nullable=True)
    received_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_duplicate: Mapped[bool] = mapped_column(default=False)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
