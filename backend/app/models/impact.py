import uuid
from datetime import date, datetime

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    ForeignKey,
    Index,
    JSON,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.database import Base
from app.db.types import GUID


class ImpactProject(Base):
    __tablename__ = "impact_projects"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
    )
    season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("seasons.id"),
        nullable=True,
    )

    title: Mapped[str] = mapped_column(String(180), nullable=False)
    summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    problem_statement: Mapped[str | None] = mapped_column(Text, nullable=True)
    solution_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    target_population: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Compatibility-only legacy fields. Canonical claims live in ImpactMetric.
    direct_beneficiaries: Mapped[int | None] = mapped_column(nullable=True)
    indirect_beneficiaries: Mapped[int | None] = mapped_column(nullable=True)
    reach: Mapped[int | None] = mapped_column(nullable=True)
    jobs_created: Mapped[int | None] = mapped_column(nullable=True)
    lives_impacted: Mapped[int | None] = mapped_column(nullable=True)

    revenue_generated: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    profit_or_surplus: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    cost_savings: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)

    trees_planted: Mapped[int | None] = mapped_column(nullable=True)
    waste_reduced: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    water_saved: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    co2_reduced: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)

    sdgs: Mapped[list] = mapped_column(JSON, default=list)
    evidence_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    methodology: Mapped[str | None] = mapped_column(Text, nullable=True)
    projection_next_12_months: Mapped[str | None] = mapped_column(Text, nullable=True)
    validation_status: Mapped[str] = mapped_column(String(32), default="DRAFT")
    # Deprecated response/input alias retained for older clients.
    status: Mapped[str] = mapped_column(String(50), default="draft")
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    __table_args__ = (
        UniqueConstraint("project_id", name="uq_impact_project_project"),
        CheckConstraint(
            "validation_status IN ('DRAFT', 'EVIDENCE_PENDING', "
            "'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED', "
            "'SUPERSEDED')",
            name="ck_impact_project_validation_status",
        ),
    )


class ImpactMetric(Base):
    __tablename__ = "impact_metrics"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    impact_project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("impact_projects.id", ondelete="CASCADE"),
        nullable=False,
    )
    semantic_key: Mapped[str] = mapped_column(String(100), nullable=False)

    title: Mapped[str] = mapped_column(String(180), nullable=False)
    category: Mapped[str] = mapped_column(String(80), default="social")
    unit: Mapped[str] = mapped_column(String(80), default="personnes")
    value: Mapped[float | None] = mapped_column(Numeric(14, 2), nullable=True)
    claim_type: Mapped[str] = mapped_column(String(32), default="HISTORICAL_CLAIM")
    validation_status: Mapped[str] = mapped_column(String(32), default="DRAFT")
    period_start: Mapped[date | None] = mapped_column(Date, nullable=True)
    period_end: Mapped[date | None] = mapped_column(Date, nullable=True)
    population_scope: Mapped[str | None] = mapped_column(Text, nullable=True)
    source: Mapped[str | None] = mapped_column(Text, nullable=True)
    source_reference: Mapped[str | None] = mapped_column(Text, nullable=True)
    methodology_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    notes_limitations: Mapped[str | None] = mapped_column(Text, nullable=True)
    evidence_file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(String(50), default="draft")
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

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
    supersedes_metric_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("impact_metrics.id", ondelete="RESTRICT"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    __table_args__ = (
        CheckConstraint(
            "claim_type IN ('MEASURED', 'ESTIMATE', 'PROJECTION', "
            "'HISTORICAL_CLAIM')",
            name="ck_impact_metric_claim_type",
        ),
        CheckConstraint(
            "validation_status IN ('DRAFT', 'EVIDENCE_PENDING', "
            "'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED', "
            "'SUPERSEDED')",
            name="ck_impact_metric_validation_status",
        ),
        CheckConstraint(
            "period_end IS NULL OR period_start IS NULL OR period_end >= period_start",
            name="ck_impact_metric_period",
        ),
        CheckConstraint(
            "length(trim(semantic_key)) > 0",
            name="ck_impact_metric_semantic_key",
        ),
        Index(
            "uq_impact_metric_active_supersedes",
            "supersedes_metric_id",
            unique=True,
            postgresql_where=text(
                "supersedes_metric_id IS NOT NULL AND validation_status IN "
                "('DRAFT', 'EVIDENCE_PENDING', 'EVIDENCE_ATTACHED', "
                "'UNDER_REVIEW', 'VERIFIED')"
            ),
            sqlite_where=text(
                "supersedes_metric_id IS NOT NULL AND validation_status IN "
                "('DRAFT', 'EVIDENCE_PENDING', 'EVIDENCE_ATTACHED', "
                "'UNDER_REVIEW', 'VERIFIED')"
            ),
        ),
    )


class ImpactEvidence(Base):
    __tablename__ = "impact_evidence"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )
    impact_project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("impact_projects.id", ondelete="CASCADE"),
        nullable=False,
    )
    metric_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("impact_metrics.id", ondelete="SET NULL"),
        nullable=True,
    )
    file_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("stored_files.id"),
        nullable=True,
    )

    title: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str] = mapped_column(String(80), default="proof")
    validation_status: Mapped[str] = mapped_column(
        String(32), default="EVIDENCE_ATTACHED"
    )
    status: Mapped[str] = mapped_column(String(50), default="submitted")
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    submitted_by_id: Mapped[uuid.UUID | None] = mapped_column(
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

    __table_args__ = (
        CheckConstraint(
            "validation_status IN ('DRAFT', 'EVIDENCE_PENDING', "
            "'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED', "
            "'SUPERSEDED')",
            name="ck_impact_evidence_validation_status",
        ),
    )
