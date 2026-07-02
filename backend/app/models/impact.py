import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, JSON, Numeric, String, Text, UniqueConstraint
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

    direct_beneficiaries: Mapped[int] = mapped_column(default=0)
    indirect_beneficiaries: Mapped[int] = mapped_column(default=0)
    reach: Mapped[int] = mapped_column(default=0)
    jobs_created: Mapped[int] = mapped_column(default=0)
    lives_impacted: Mapped[int] = mapped_column(default=0)

    revenue_generated: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    profit_or_surplus: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    cost_savings: Mapped[float] = mapped_column(Numeric(14, 2), default=0)

    trees_planted: Mapped[int] = mapped_column(default=0)
    waste_reduced: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    water_saved: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    co2_reduced: Mapped[float] = mapped_column(Numeric(14, 2), default=0)

    sdgs: Mapped[list] = mapped_column(JSON, default=list)
    evidence_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    methodology: Mapped[str | None] = mapped_column(Text, nullable=True)
    projection_next_12_months: Mapped[str | None] = mapped_column(Text, nullable=True)
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

    title: Mapped[str] = mapped_column(String(180), nullable=False)
    category: Mapped[str] = mapped_column(String(80), default="social")
    unit: Mapped[str] = mapped_column(String(80), default="personnes")
    value: Mapped[float] = mapped_column(Numeric(14, 2), default=0)
    source: Mapped[str | None] = mapped_column(Text, nullable=True)
    methodology_note: Mapped[str | None] = mapped_column(Text, nullable=True)
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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
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
