import uuid
from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class AppInstallation(Base):
    __tablename__ = "app_installations"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    installation_key: Mapped[uuid.UUID] = mapped_column(
        GUID(), nullable=False
    )
    platform: Mapped[str] = mapped_column(String(20), nullable=False)
    app_version: Mapped[str | None] = mapped_column(String(40), nullable=True)
    build_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    os_version: Mapped[str | None] = mapped_column(String(80), nullable=True)
    device_model: Mapped[str | None] = mapped_column(String(120), nullable=True)
    locale: Mapped[str | None] = mapped_column(String(20), nullable=True)
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    __table_args__ = (
        CheckConstraint(
            "platform IN ('ios', 'android', 'web')",
            name="ck_app_installation_platform",
        ),
        CheckConstraint(
            "build_number IS NULL OR build_number > 0",
            name="ck_app_installation_build_positive",
        ),
        UniqueConstraint(
            "installation_key", name="uq_app_installations_installation_key"
        ),
        Index("ix_app_installation_user_last_seen", "user_id", "last_seen_at"),
    )


class SupportTicket(Base):
    __tablename__ = "support_tickets"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    subject: Mapped[str] = mapped_column(String(200), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False)
    status: Mapped[str] = mapped_column(String(20), default="open", nullable=False)
    priority: Mapped[str] = mapped_column(String(20), default="normal", nullable=False)
    assigned_to_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    __table_args__ = (
        CheckConstraint(
            "category IN ('general', 'account', 'access', 'technical', 'billing', 'other')",
            name="ck_support_ticket_category",
        ),
        CheckConstraint(
            "status IN ('open', 'in_progress', 'resolved', 'closed')",
            name="ck_support_ticket_status",
        ),
        CheckConstraint(
            "priority IN ('low', 'normal', 'high', 'urgent')",
            name="ck_support_ticket_priority",
        ),
        Index("ix_support_ticket_status_created", "status", "created_at"),
    )


class SupportTicketMessage(Base):
    __tablename__ = "support_ticket_messages"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    ticket_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("support_tickets.id", ondelete="CASCADE"), nullable=False, index=True
    )
    author_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True
    )
    message: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )


class ProductFeedback(Base):
    __tablename__ = "product_feedback"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    category: Mapped[str] = mapped_column(String(20), nullable=False)
    message: Mapped[str] = mapped_column(Text, nullable=False)
    rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    platform: Mapped[str | None] = mapped_column(String(20), nullable=True)
    app_version: Mapped[str | None] = mapped_column(String(40), nullable=True)
    build_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="new", nullable=False)
    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    __table_args__ = (
        CheckConstraint(
            "category IN ('bug', 'idea', 'usability', 'other')",
            name="ck_product_feedback_category",
        ),
        CheckConstraint(
            "rating IS NULL OR (rating >= 1 AND rating <= 5)",
            name="ck_product_feedback_rating",
        ),
        CheckConstraint(
            "platform IS NULL OR platform IN ('ios', 'android', 'web')",
            name="ck_product_feedback_platform",
        ),
        CheckConstraint(
            "build_number IS NULL OR build_number > 0",
            name="ck_product_feedback_build_positive",
        ),
        CheckConstraint(
            "status IN ('new', 'reviewed', 'planned', 'closed')",
            name="ck_product_feedback_status",
        ),
        Index("ix_product_feedback_status_created", "status", "created_at"),
    )


class AppRelease(Base):
    __tablename__ = "app_releases"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    platform: Mapped[str] = mapped_column(String(20), nullable=False)
    version: Mapped[str] = mapped_column(String(40), nullable=False)
    build_number: Mapped[int] = mapped_column(Integer, nullable=False)
    release_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="draft", nullable=False)
    store_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    __table_args__ = (
        CheckConstraint(
            "platform IN ('ios', 'android', 'web')",
            name="ck_app_release_platform",
        ),
        CheckConstraint("build_number > 0", name="ck_app_release_build_positive"),
        CheckConstraint(
            "status IN ('draft', 'published', 'withdrawn')",
            name="ck_app_release_status",
        ),
        CheckConstraint(
            "status != 'published' OR published_at IS NOT NULL",
            name="ck_app_release_published_at",
        ),
        UniqueConstraint("platform", "build_number", name="uq_app_release_platform_build"),
        UniqueConstraint("id", "platform", name="uq_app_release_id_platform"),
        Index("ix_app_release_platform_build", "platform", "build_number"),
    )


class AppVersionPolicy(Base):
    __tablename__ = "app_version_policies"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    platform: Mapped[str] = mapped_column(String(20), nullable=False)
    current_release_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), nullable=True
    )
    minimum_supported_release_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), nullable=True
    )
    force_update_to_current: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    maintenance_enabled: Mapped[bool] = mapped_column(
        Boolean, default=False, nullable=False
    )
    maintenance_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    maintenance_starts_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    maintenance_ends_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    __table_args__ = (
        CheckConstraint(
            "platform IN ('ios', 'android', 'web')",
            name="ck_app_version_policy_platform",
        ),
        CheckConstraint(
            "((maintenance_starts_at IS NULL AND maintenance_ends_at IS NULL) OR "
            "(maintenance_starts_at IS NOT NULL AND maintenance_ends_at IS NOT NULL "
            "AND maintenance_starts_at < maintenance_ends_at))",
            name="ck_app_version_policy_maintenance_window",
        ),
        ForeignKeyConstraint(
            ["current_release_id", "platform"],
            ["app_releases.id", "app_releases.platform"],
            name="fk_app_version_policy_current_release_platform",
            ondelete="RESTRICT",
        ),
        ForeignKeyConstraint(
            ["minimum_supported_release_id", "platform"],
            ["app_releases.id", "app_releases.platform"],
            name="fk_app_version_policy_minimum_release_platform",
            ondelete="RESTRICT",
        ),
        UniqueConstraint("platform", name="uq_app_version_policies_platform"),
    )
