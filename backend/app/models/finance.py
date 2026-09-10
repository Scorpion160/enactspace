import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Index, String, Text, DateTime, Date, ForeignKey, Numeric, UniqueConstraint, text
from app.db.types import GUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base


class FinancialAccount(Base):
    __tablename__ = "financial_accounts"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )

    balance_due: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    total_paid: Mapped[float] = mapped_column(Numeric(12, 2), default=0)

    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("balance_due >= 0", name="ck_financial_accounts_balance_nonnegative"),
        CheckConstraint("total_paid >= 0", name="ck_financial_accounts_paid_nonnegative"),
    )


class Fee(Base):
    __tablename__ = "fees"

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

    type: Mapped[str] = mapped_column(String(80), nullable=False)
    category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    label: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    amount_paid: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    currency: Mapped[str] = mapped_column(String(10), default="FCFA")

    status: Mapped[str] = mapped_column(String(50), default="unpaid")

    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    paid_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    related_attendance_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("attendance_records.id"),
        nullable=True,
    )
    source_type: Mapped[str | None] = mapped_column(String(80), nullable=True)
    source_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), nullable=True)
    proof_file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )

    created_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_fees_amount_positive"),
        CheckConstraint("amount_paid >= 0 AND amount_paid <= amount", name="ck_fees_paid_range"),
        Index(
            "ux_fees_related_attendance",
            "related_attendance_id",
            unique=True,
            sqlite_where=text("related_attendance_id IS NOT NULL"),
            postgresql_where=text("related_attendance_id IS NOT NULL"),
        ),
        Index(
            "ux_fees_source_identity",
            "source_type",
            "source_id",
            "user_id",
            unique=True,
            sqlite_where=text("source_type IS NOT NULL AND source_id IS NOT NULL"),
            postgresql_where=text("source_type IS NOT NULL AND source_id IS NOT NULL"),
        ),
    )


class Payment(Base):
    __tablename__ = "payments"

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

    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="FCFA")

    method: Mapped[str] = mapped_column(String(80), nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="pending")

    reference: Mapped[str | None] = mapped_column(String(150), nullable=True)
    proof_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    proof_file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )

    validated_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    rejected_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    receipt_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    receipt_file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_payments_amount_positive"),
    )


class PaymentAllocation(Base):
    __tablename__ = "payment_allocations"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    payment_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("payments.id", ondelete="CASCADE"),
        nullable=False,
    )

    fee_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("fees.id", ondelete="CASCADE"),
        nullable=False,
    )

    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("payment_id", "fee_id", name="uq_payment_allocation_fee"),
        CheckConstraint("amount > 0", name="ck_payment_allocations_amount_positive"),
    )


class ClubTransaction(Base):
    __tablename__ = "club_transactions"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("seasons.id"),
        nullable=True,
    )

    type: Mapped[str] = mapped_column(String(50), nullable=False)
    category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    label: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    currency: Mapped[str] = mapped_column(String(10), default="FCFA")

    project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("projects.id"),
        nullable=True,
    )

    pole_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("poles.id"),
        nullable=True,
    )

    payment_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("payments.id"),
        nullable=True,
    )

    proof_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    proof_file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )

    created_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    validated_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    __table_args__ = (
        CheckConstraint("amount > 0", name="ck_club_transactions_amount_positive"),
        Index(
            "ux_club_transactions_payment",
            "payment_id",
            unique=True,
            sqlite_where=text("payment_id IS NOT NULL"),
            postgresql_where=text("payment_id IS NOT NULL"),
        ),
    )
