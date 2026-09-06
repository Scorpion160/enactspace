import uuid
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


MEMORY_VALIDATION_CHECK = (
    "validation_status IN ('HISTORICAL_REPORTED', 'EVIDENCE_PENDING', "
    "'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED', "
    "'SUPERSEDED')"
)
YEAR_CHECK = "{field} IS NULL OR ({field} BETWEEN 1000 AND 9999)"


class InstitutionalSource(Base):
    __tablename__ = "institutional_sources"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    source_type: Mapped[str] = mapped_column(String(50), nullable=False)
    title: Mapped[str] = mapped_column(String(220), nullable=False)
    document_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("documents.id", ondelete="SET NULL"), nullable=True
    )
    file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("stored_files.id", ondelete="SET NULL"), nullable=True
    )
    external_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_label: Mapped[str | None] = mapped_column(String(220), nullable=True)
    publication_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    visibility: Mapped[str] = mapped_column(String(30), default="internal")
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_source_validation"),
        CheckConstraint(YEAR_CHECK.format(field="year"), name="ck_memory_source_year"),
        CheckConstraint(
            "visibility IN ('private', 'internal')",
            name="ck_memory_source_visibility",
        ),
        Index("ix_memory_source_year_type", "year", "source_type"),
    )


class Territory(Base):
    __tablename__ = "institutional_territories"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    place_type: Mapped[str] = mapped_column(String(60), nullable=False)
    country: Mapped[str] = mapped_column(String(120), nullable=False)
    region: Mapped[str | None] = mapped_column(String(160), nullable=True)
    department_or_locality: Mapped[str | None] = mapped_column(String(180), nullable=True)
    latitude: Mapped[float | None] = mapped_column(Numeric(9, 6), nullable=True)
    longitude: Mapped[float | None] = mapped_column(Numeric(9, 6), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_territory_validation"),
        CheckConstraint(
            "latitude IS NULL OR (latitude BETWEEN -90 AND 90)",
            name="ck_memory_territory_latitude",
        ),
        CheckConstraint(
            "longitude IS NULL OR (longitude BETWEEN -180 AND 180)",
            name="ck_memory_territory_longitude",
        ),
        UniqueConstraint(
            "name",
            "place_type",
            "country",
            "region",
            "department_or_locality",
            name="uq_memory_territory_identity",
        ),
        Index("ix_memory_territory_country_region", "country", "region"),
    )


class InstitutionalGeneration(Base):
    __tablename__ = "institutional_generations"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(180), nullable=False)
    start_year: Mapped[int] = mapped_column(Integer, nullable=False)
    end_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(40), default="historical")
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_generation_validation"),
        CheckConstraint(
            "start_year BETWEEN 1000 AND 9999",
            name="ck_memory_generation_start_year",
        ),
        CheckConstraint(
            "end_year IS NULL OR (end_year BETWEEN 1000 AND 9999 AND end_year >= start_year)",
            name="ck_memory_generation_end_year",
        ),
        UniqueConstraint("name", "start_year", name="uq_memory_generation_name_year"),
        Index("ix_memory_generation_years", "start_year", "end_year"),
    )


class CanonicalProject(Base):
    __tablename__ = "institutional_canonical_projects"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    canonical_name: Mapped[str] = mapped_column(String(180), nullable=False)
    slug: Mapped[str] = mapped_column(String(180), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    first_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    last_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="historical")
    current_project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("projects.id", ondelete="SET NULL"), nullable=True
    )
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_project_validation"),
        CheckConstraint(
            YEAR_CHECK.format(field="first_year"), name="ck_memory_project_first_year"
        ),
        CheckConstraint(
            "last_year IS NULL OR (last_year BETWEEN 1000 AND 9999 "
            "AND (first_year IS NULL OR last_year >= first_year))",
            name="ck_memory_project_last_year",
        ),
        Index("ix_memory_project_years", "first_year", "last_year"),
    )


class LeadershipTerm(Base):
    __tablename__ = "institutional_leadership_terms"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    display_name: Mapped[str | None] = mapped_column(String(180), nullable=True)
    role_label: Mapped[str] = mapped_column(String(180), nullable=False)
    pole_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("poles.id", ondelete="SET NULL"), nullable=True
    )
    generation_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_generations.id", ondelete="SET NULL"), nullable=True
    )
    start_year: Mapped[int] = mapped_column(Integer, nullable=False)
    end_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    is_current: Mapped[bool] = mapped_column(Boolean, default=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_term_validation"),
        CheckConstraint(
            "user_id IS NOT NULL OR length(trim(display_name)) > 0",
            name="ck_memory_term_person",
        ),
        CheckConstraint(
            "start_year BETWEEN 1000 AND 9999",
            name="ck_memory_term_start_year",
        ),
        CheckConstraint(
            "end_year IS NULL OR (end_year BETWEEN 1000 AND 9999 AND end_year >= start_year)",
            name="ck_memory_term_end_year",
        ),
        CheckConstraint(
            "is_current = false OR end_year IS NULL",
            name="ck_memory_term_current_end",
        ),
        Index("ix_memory_term_years", "start_year", "end_year"),
        Index("ix_memory_term_user", "user_id"),
    )


class ProjectAlias(Base):
    __tablename__ = "institutional_project_aliases"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    canonical_project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("institutional_canonical_projects.id", ondelete="CASCADE"),
        nullable=False,
    )
    alias: Mapped[str] = mapped_column(String(180), nullable=False)
    start_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    end_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_alias_validation"),
        CheckConstraint(
            YEAR_CHECK.format(field="start_year"), name="ck_memory_alias_start_year"
        ),
        CheckConstraint(
            "end_year IS NULL OR (end_year BETWEEN 1000 AND 9999 "
            "AND (start_year IS NULL OR end_year >= start_year))",
            name="ck_memory_alias_end_year",
        ),
        Index("uq_memory_project_alias_ci", func.lower(alias), unique=True),
        Index("ix_memory_alias_project", "canonical_project_id"),
    )


class ProjectYear(Base):
    __tablename__ = "institutional_project_years"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    canonical_project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("institutional_canonical_projects.id", ondelete="CASCADE"),
        nullable=False,
    )
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    display_name: Mapped[str | None] = mapped_column(String(180), nullable=True)
    status: Mapped[str] = mapped_column(String(50), default="reported")
    problem_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    solution_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    territory_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_territories.id", ondelete="SET NULL"), nullable=True
    )
    operational_project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("projects.id", ondelete="SET NULL"), nullable=True
    )
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_project_year_validation"),
        CheckConstraint(
            "year BETWEEN 1000 AND 9999", name="ck_memory_project_year_year"
        ),
        UniqueConstraint(
            "canonical_project_id", "year", name="uq_memory_project_year"
        ),
        Index("ix_memory_project_year_year", "year"),
        Index("ix_memory_project_year_territory", "territory_id", "year"),
    )


class ProjectRelationship(Base):
    __tablename__ = "institutional_project_relationships"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    source_project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("institutional_canonical_projects.id", ondelete="RESTRICT"), nullable=False
    )
    target_project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("institutional_canonical_projects.id", ondelete="RESTRICT"), nullable=False
    )
    relationship_type: Mapped[str] = mapped_column(String(50), nullable=False)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_relationship_validation"),
        CheckConstraint(
            "source_project_id <> target_project_id",
            name="ck_memory_relationship_not_self",
        ),
        CheckConstraint(
            "relationship_type IN ('renamed_from', 'continued_as', 'merged_into', "
            "'split_from', 'inspired_by', 'technology_transferred_to', 'other')",
            name="ck_memory_relationship_type",
        ),
        CheckConstraint(
            YEAR_CHECK.format(field="year"), name="ck_memory_relationship_year"
        ),
        Index("ix_memory_relationship_source", "source_project_id", "year"),
        Index("ix_memory_relationship_target", "target_project_id", "year"),
    )


class InstitutionalEvent(Base):
    __tablename__ = "institutional_events"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(220), nullable=False)
    event_type: Mapped[str] = mapped_column(String(60), nullable=False)
    event_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    territory_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_territories.id", ondelete="SET NULL"), nullable=True
    )
    canonical_project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_canonical_projects.id", ondelete="SET NULL"), nullable=True
    )
    generation_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_generations.id", ondelete="SET NULL"), nullable=True
    )
    visibility: Mapped[str] = mapped_column(String(30), default="internal")
    status: Mapped[str] = mapped_column(String(40), default="reported")
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_event_validation"),
        CheckConstraint("year BETWEEN 1000 AND 9999", name="ck_memory_event_year"),
        CheckConstraint(
            "end_date IS NULL OR event_date IS NULL OR end_date >= event_date",
            name="ck_memory_event_dates",
        ),
        CheckConstraint(
            "visibility IN ('private', 'internal')",
            name="ck_memory_event_visibility",
        ),
        Index("ix_memory_event_timeline", "year", "event_date"),
        Index("ix_memory_event_project", "canonical_project_id", "year"),
        Index("ix_memory_event_territory", "territory_id", "year"),
    )


class InstitutionalFramework(Base):
    __tablename__ = "institutional_frameworks"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(220), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    framework_type: Mapped[str] = mapped_column(String(80), nullable=False)
    version_label: Mapped[str] = mapped_column(String(100), nullable=False)
    effective_from_year: Mapped[int] = mapped_column(Integer, nullable=False)
    effective_to_year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    steps: Mapped[list | dict] = mapped_column(JSON, default=list)
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_framework_validation"),
        CheckConstraint(
            "effective_from_year BETWEEN 1000 AND 9999",
            name="ck_memory_framework_start_year",
        ),
        CheckConstraint(
            "effective_to_year IS NULL OR (effective_to_year BETWEEN 1000 AND 9999 "
            "AND effective_to_year >= effective_from_year)",
            name="ck_memory_framework_end_year",
        ),
        UniqueConstraint(
            "name", "version_label", name="uq_memory_framework_name_version"
        ),
        Index(
            "ix_memory_framework_years", "effective_from_year", "effective_to_year"
        ),
    )


class CompetitionParticipation(Base):
    __tablename__ = "institutional_competition_participations"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    competition_record_id: Mapped[uuid.UUID] = mapped_column(
        GUID(), ForeignKey("archive_competition_records.id", ondelete="CASCADE"), nullable=False
    )
    participant_scope: Mapped[str] = mapped_column(String(20), nullable=False)
    canonical_project_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_canonical_projects.id", ondelete="CASCADE"), nullable=True
    )
    stage: Mapped[str | None] = mapped_column(String(140), nullable=True)
    result: Mapped[str | None] = mapped_column(String(180), nullable=True)
    source_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("institutional_sources.id", ondelete="RESTRICT"), nullable=True
    )
    validation_status: Mapped[str] = mapped_column(
        String(32), default="HISTORICAL_REPORTED"
    )
    created_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_by_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    validated_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    __table_args__ = (
        CheckConstraint(MEMORY_VALIDATION_CHECK, name="ck_memory_participation_validation"),
        CheckConstraint(
            "participant_scope IN ('organization', 'project')",
            name="ck_memory_participation_scope",
        ),
        CheckConstraint(
            "(participant_scope = 'organization' AND canonical_project_id IS NULL) OR "
            "(participant_scope = 'project' AND canonical_project_id IS NOT NULL)",
            name="ck_memory_participation_project",
        ),
        Index(
            "uq_memory_competition_organization",
            "competition_record_id",
            unique=True,
            postgresql_where=text("participant_scope = 'organization'"),
            sqlite_where=text("participant_scope = 'organization'"),
        ),
        Index(
            "uq_memory_competition_project",
            "competition_record_id",
            "canonical_project_id",
            unique=True,
            postgresql_where=text("participant_scope = 'project'"),
            sqlite_where=text("participant_scope = 'project'"),
        ),
    )
