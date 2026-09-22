import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Index, String, Text, UniqueConstraint, text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class UserPreference(Base):
    __tablename__ = "user_preferences"

    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    locale: Mapped[str] = mapped_column(String(10), default="fr", nullable=False)
    theme: Mapped[str] = mapped_column(String(10), default="system", nullable=False)
    notification_in_app_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notification_email_enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    notification_push_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    __table_args__ = (
        CheckConstraint("locale IN ('fr', 'en')", name="ck_user_preferences_locale"),
        CheckConstraint("theme IN ('system', 'light', 'dark')", name="ck_user_preferences_theme"),
    )


class LegalDocument(Base):
    __tablename__ = "legal_documents"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    document_type: Mapped[str] = mapped_column(String(40), nullable=False)
    version: Mapped[str] = mapped_column(String(40), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    effective_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    requires_acceptance: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    __table_args__ = (
        UniqueConstraint("document_type", "version", name="uq_legal_document_type_version"),
        CheckConstraint(
            "document_type IN ('privacy_policy', 'terms_of_use')",
            name="ck_legal_document_type",
        ),
        CheckConstraint(
            "is_active = false OR published_at IS NOT NULL",
            name="ck_legal_active_is_published",
        ),
        Index("ix_legal_document_type_published", "document_type", "published_at"),
        Index(
            "uq_legal_document_active_type",
            "document_type",
            unique=True,
            postgresql_where=text("is_active = true"),
            sqlite_where=text("is_active = 1"),
        ),
    )


class LegalAcceptance(Base):
    __tablename__ = "legal_acceptances"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    legal_document_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("legal_documents.id", ondelete="RESTRICT"), nullable=False
    )
    document_version: Mapped[str] = mapped_column(String(40), nullable=False)
    source: Mapped[str | None] = mapped_column(String(40), nullable=True)
    accepted_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    __table_args__ = (
        UniqueConstraint("user_id", "legal_document_id", name="uq_legal_acceptance_user_document"),
        CheckConstraint(
            "source IS NULL OR source IN ('web', 'android', 'ios', 'api')",
            name="ck_legal_acceptance_source",
        ),
    )


class AccountDeletionRequest(Base):
    __tablename__ = "account_deletion_requests"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(String(20), default="pending", nullable=False)
    requested_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    processed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    __table_args__ = (
        CheckConstraint(
            "status IN ('pending', 'cancelled', 'approved', 'completed', 'rejected')",
            name="ck_account_deletion_status",
        ),
        Index("ix_account_deletion_user_status", "user_id", "status"),
        Index(
            "uq_account_deletion_pending_user",
            "user_id",
            unique=True,
            postgresql_where=text("status = 'pending'"),
            sqlite_where=text("status = 'pending'"),
        ),
    )


class AuthSession(Base):
    __tablename__ = "auth_sessions"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    refresh_token_hash: Mapped[str] = mapped_column(String(64), nullable=False, unique=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime, nullable=False, index=True)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)
    user_agent: Mapped[str | None] = mapped_column(String(255), nullable=True)
    platform: Mapped[str | None] = mapped_column(String(40), nullable=True)

    __table_args__ = (
        CheckConstraint(
            "platform IS NULL OR platform IN ('web', 'android', 'ios', 'api', 'unknown')",
            name="ck_auth_session_platform",
        ),
    )
