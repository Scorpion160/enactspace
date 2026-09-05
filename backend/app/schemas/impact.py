from datetime import date, datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class ImpactProjectBase(BaseModel):
    project_id: UUID
    season_id: Optional[UUID] = None
    title: str
    summary: Optional[str] = None
    problem_statement: Optional[str] = None
    solution_summary: Optional[str] = None
    target_population: Optional[str] = None
    direct_beneficiaries: Optional[int] = None
    indirect_beneficiaries: Optional[int] = None
    reach: Optional[int] = None
    jobs_created: Optional[int] = None
    revenue_generated: Optional[float] = None
    profit_or_surplus: Optional[float] = None
    cost_savings: Optional[float] = None
    lives_impacted: Optional[int] = None
    trees_planted: Optional[int] = None
    waste_reduced: Optional[float] = None
    water_saved: Optional[float] = None
    co2_reduced: Optional[float] = None
    sdgs: list[str] = Field(default_factory=list)
    evidence_notes: Optional[str] = None
    methodology: Optional[str] = None
    projection_next_12_months: Optional[str] = None
    validation_status: str = "DRAFT"
    status: str = "draft"


class ImpactProjectCreate(ImpactProjectBase):
    pass


class ImpactProjectUpdate(BaseModel):
    season_id: Optional[UUID] = None
    title: Optional[str] = None
    summary: Optional[str] = None
    problem_statement: Optional[str] = None
    solution_summary: Optional[str] = None
    target_population: Optional[str] = None
    direct_beneficiaries: Optional[int] = None
    indirect_beneficiaries: Optional[int] = None
    reach: Optional[int] = None
    jobs_created: Optional[int] = None
    revenue_generated: Optional[float] = None
    profit_or_surplus: Optional[float] = None
    cost_savings: Optional[float] = None
    lives_impacted: Optional[int] = None
    trees_planted: Optional[int] = None
    waste_reduced: Optional[float] = None
    water_saved: Optional[float] = None
    co2_reduced: Optional[float] = None
    sdgs: Optional[list[str]] = None
    evidence_notes: Optional[str] = None
    methodology: Optional[str] = None
    projection_next_12_months: Optional[str] = None
    status: Optional[str] = None
    validation_status: Optional[str] = None


class ImpactProjectRead(ImpactProjectBase):
    id: UUID
    created_by_id: Optional[UUID]
    validated_by_id: Optional[UUID]
    validated_at: Optional[datetime]
    rejection_reason: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ImpactMetricCreate(BaseModel):
    semantic_key: str = Field(min_length=1, max_length=100)
    title: str
    category: str = "social"
    unit: str = "personnes"
    value: Optional[float] = None
    claim_type: str = "HISTORICAL_CLAIM"
    validation_status: str = "DRAFT"
    period_start: Optional[date] = None
    period_end: Optional[date] = None
    population_scope: Optional[str] = None
    source: Optional[str] = None
    source_reference: Optional[str] = None
    methodology_note: Optional[str] = None
    notes_limitations: Optional[str] = None
    evidence_file_id: Optional[UUID] = None
    supersedes_metric_id: Optional[UUID] = None
    status: str = "draft"

    @model_validator(mode="after")
    def validate_period(self):
        if self.period_start and self.period_end and self.period_end < self.period_start:
            raise ValueError("period_end must be on or after period_start")
        return self


class ImpactMetricRead(ImpactMetricCreate):
    id: UUID
    impact_project_id: UUID
    created_by_id: Optional[UUID]
    validated_by_id: Optional[UUID]
    validated_at: Optional[datetime]
    rejection_reason: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ImpactEvidenceCreate(BaseModel):
    title: str
    description: Optional[str] = None
    category: str = "proof"
    metric_id: Optional[UUID] = None
    file_id: Optional[UUID] = None
    validation_status: str = "EVIDENCE_ATTACHED"
    status: str = "submitted"


class ImpactEvidenceRead(ImpactEvidenceCreate):
    id: UUID
    impact_project_id: UUID
    submitted_by_id: Optional[UUID]
    validated_by_id: Optional[UUID]
    validated_at: Optional[datetime]
    rejection_reason: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ImpactValidationRequest(BaseModel):
    reason: Optional[str] = None
