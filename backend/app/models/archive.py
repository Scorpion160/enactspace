import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class ArchiveItem(Base):
    __tablename__ = "archive_items"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    title: Mapped[str] = mapped_column(String(220), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(String(100), default="Autre")
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("seasons.id"),
        nullable=True,
    )
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
    document_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("documents.id"),
        nullable=True,
    )
    file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    visibility: Mapped[str] = mapped_column(String(50), default="interne")
    status: Mapped[str] = mapped_column(String(50), default="draft")
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    is_public: Mapped[bool] = mapped_column(Boolean, default=False)
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    rejected_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )
    rejected_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_label: Mapped[str | None] = mapped_column(String(180), nullable=True)
    source_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    tags: Mapped[list] = mapped_column(JSON, default=list)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class ArchivedProject(Base):
    __tablename__ = "archived_projects"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    archive_item_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("archive_items.id", ondelete="SET NULL"),
        nullable=True,
    )
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    season_label: Mapped[str | None] = mapped_column(String(100), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    problem: Mapped[str | None] = mapped_column(Text, nullable=True)
    solution: Mapped[str | None] = mapped_column(Text, nullable=True)
    impact_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="historique")
    linked_project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("projects.id"),
        nullable=True,
    )
    key_members: Mapped[list] = mapped_column(JSON, default=list)
    awards: Mapped[list] = mapped_column(JSON, default=list)
    document_ids: Mapped[list] = mapped_column(JSON, default=list)
    media_file_ids: Mapped[list] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class Award(Base):
    __tablename__ = "archive_awards"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    archive_item_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("archive_items.id", ondelete="SET NULL"),
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(220), nullable=False)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    competition: Mapped[str | None] = mapped_column(String(180), nullable=True)
    rank: Mapped[str | None] = mapped_column(String(120), nullable=True)
    result: Mapped[str | None] = mapped_column(String(180), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    archived_project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("archived_projects.id"),
        nullable=True,
    )
    file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    media_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class CompetitionRecord(Base):
    __tablename__ = "archive_competition_records"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    archive_item_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("archive_items.id", ondelete="SET NULL"),
        nullable=True,
    )
    name: Mapped[str] = mapped_column(String(220), nullable=False)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    stage: Mapped[str | None] = mapped_column(String(140), nullable=True)
    result: Mapped[str | None] = mapped_column(String(180), nullable=True)
    location: Mapped[str | None] = mapped_column(String(180), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    project_ids: Mapped[list] = mapped_column(JSON, default=list)
    award_ids: Mapped[list] = mapped_column(JSON, default=list)
    file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class MediaArchive(Base):
    __tablename__ = "archive_media"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    archive_item_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("archive_items.id", ondelete="SET NULL"),
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(220), nullable=False)
    media_type: Mapped[str] = mapped_column(String(80), default="image")
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    external_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_label: Mapped[str | None] = mapped_column(String(180), nullable=True)
    archived_project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("archived_projects.id"),
        nullable=True,
    )
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class HistoricalDocument(Base):
    __tablename__ = "archive_historical_documents"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    archive_item_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("archive_items.id", ondelete="SET NULL"),
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(220), nullable=False)
    document_type: Mapped[str] = mapped_column(String(100), default="Document officiel")
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    document_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("documents.id"),
        nullable=True,
    )
    file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    source_label: Mapped[str | None] = mapped_column(String(180), nullable=True)
    visibility: Mapped[str] = mapped_column(String(50), default="interne")
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class HallOfFameEntry(Base):
    __tablename__ = "hall_of_fame_entries"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    archive_item_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("archive_items.id", ondelete="SET NULL"),
        nullable=True,
    )
    title: Mapped[str] = mapped_column(String(220), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(220), nullable=True)
    entry_type: Mapped[str] = mapped_column(String(100), default="Moment fort")
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    score_value: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    score_label: Mapped[str | None] = mapped_column(String(120), nullable=True)
    file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    external_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )


class HistoricalImpactStatistic(Base):
    __tablename__ = "archive_historical_impact_statistics"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    metric_key: Mapped[str] = mapped_column(String(120), nullable=False, unique=True)
    label: Mapped[str] = mapped_column(String(220), nullable=False)
    value: Mapped[float] = mapped_column(Numeric(18, 2), default=0)
    unit: Mapped[str | None] = mapped_column(String(80), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_label: Mapped[str | None] = mapped_column(String(180), nullable=True)
    source_file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(String(50), default="validated")
    is_featured: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )
