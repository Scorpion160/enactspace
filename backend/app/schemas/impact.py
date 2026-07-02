from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class ImpactProjectBase(BaseModel):
    project_id: UUID
    season_id: Optional[UUID] = None
    title: str
    summary: Optional[str] = None
    problem_statement: Optional[str] = None
    solution_summary: Optional[str] = None
    target_population: Optional[str] = None
    direct_beneficiaries: int = 0
    indirect_beneficiaries: int = 0
    reach: int = 0
    jobs_created: int = 0
    revenue_generated: float = 0
    profit_or_surplus: float = 0
    cost_savings: float = 0
    lives_impacted: int = 0
    trees_planted: int = 0
    waste_reduced: float = 0
    water_saved: float = 0
    co2_reduced: float = 0
    sdgs: list[str] = Field(default_factory=list)
    evidence_notes: Optional[str] = None
    methodology: Optional[str] = None
    projection_next_12_months: Optional[str] = None
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
    title: str
    category: str = "social"
    unit: str = "personnes"
    value: float = 0
    source: Optional[str] = None
    methodology_note: Optional[str] = None
    evidence_file_id: Optional[UUID] = None
    status: str = "draft"


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
