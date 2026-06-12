import uuid
from datetime import date, datetime

from sqlalchemy import String, Text, DateTime, Date, ForeignKey, Numeric
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
    label: Mapped[str] = mapped_column(String(200), nullable=False)

    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    amount_paid: Mapped[float] = mapped_column(Numeric(12, 2), default=0)

    status: Mapped[str] = mapped_column(String(50), default="unpaid")

    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    related_attendance_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("attendance_records.id"),
        nullable=True,
    )

    created_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


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

    method: Mapped[str] = mapped_column(String(80), nullable=False)
    status: Mapped[str] = mapped_column(String(50), default="pending")

    reference: Mapped[str | None] = mapped_column(String(150), nullable=True)
    proof_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    validated_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )

    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    receipt_url: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


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

    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)

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
