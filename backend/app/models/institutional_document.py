import uuid
from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    JSON,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class InstitutionalDocumentRequest(Base):
    __tablename__ = "institutional_document_requests"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(), primary_key=True, default=uuid.uuid4
    )

    template_code: Mapped[str] = mapped_column(String(80), nullable=False, index=True)
    template_version: Mapped[str] = mapped_column(String(20), nullable=False, default="2.0")
    status: Mapped[str] = mapped_column(String(40), nullable=False, default="draft", index=True)
    payload_json: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)

    requested_by: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    submitted_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    sg_validated_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    sg_validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    approved_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    approved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    rejected_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    rejected_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    cancelled_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    cancellation_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    pole_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("poles.id", ondelete="SET NULL"), nullable=True, index=True
    )
    project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("projects.id", ondelete="SET NULL"), nullable=True, index=True
    )
    event_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("events.id", ondelete="SET NULL"), nullable=True
    )
    season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("seasons.id", ondelete="SET NULL"), nullable=True, index=True
    )

    sequence_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    official_reference: Mapped[str | None] = mapped_column(
        String(160), nullable=True, unique=True
    )

    generated_document_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("documents.id", ondelete="SET NULL"),
        nullable=True,
        unique=True,
    )
    generated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )


class InstitutionalDocumentSequence(Base):
    __tablename__ = "institutional_document_sequences"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(), primary_key=True, default=uuid.uuid4
    )
    season_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("seasons.id", ondelete="CASCADE"), nullable=False
    )
    template_code: Mapped[str] = mapped_column(String(80), nullable=False)
    last_number: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        UniqueConstraint(
            "season_id",
            "template_code",
            name="uq_institutional_document_sequence_season_template",
        ),
    )
