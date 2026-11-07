from pydantic import Field, field_validator, model_validator, BaseModel, computed_field
from app.services.project_presentations import get_project_presentation
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class ProjectCreate(BaseModel):
    season_id: Optional[UUID] = None
    name: str = Field(min_length=1, max_length=150)
    description: Optional[str] = None
    problem_statement: Optional[str] = None
    solution: Optional[str] = None
    objectives: Optional[str] = None
    expected_impact: Optional[str] = None
    budget_estimated: float = Field(default=0, ge=0, le=9999999999.99, multiple_of=0.01, allow_inf_nan=False)
    status: str = "idee"
    started_at: Optional[date] = None
    ended_at: Optional[date] = None


    @field_validator("name", mode="before")
    @classmethod
    def trim_required_text(cls, value):
        return value.strip() if isinstance(value, str) else value

class ProjectUpdate(BaseModel):
    season_id: Optional[UUID] = None
    name: Optional[str] = Field(default=None, min_length=1, max_length=150)
    description: Optional[str] = None
    problem_statement: Optional[str] = None
    solution: Optional[str] = None
    objectives: Optional[str] = None
    expected_impact: Optional[str] = None
    budget_estimated: Optional[float] = Field(default=None, ge=0, le=9999999999.99, multiple_of=0.01, allow_inf_nan=False)
    status: Optional[str] = None
    started_at: Optional[date] = None
    ended_at: Optional[date] = None


    @field_validator("name", mode="before")
    @classmethod
    def trim_required_text(cls, value):
        return value.strip() if isinstance(value, str) else value

    @model_validator(mode="after")
    def reject_null_required_fields(self):
        for name in ['name', 'status', 'budget_estimated']:
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError("Ce champ ne peut pas être vide")
        return self

class ProjectMemberAssign(BaseModel):
    user_id: UUID
    position: str = "membre"


class ProjectMemberRead(BaseModel):
    id: UUID
    project_id: UUID
    user_id: UUID
    position: str
    joined_at: date
    left_at: Optional[date]
    is_active: bool
    display_name: str
    email: str
    photo_url: Optional[str] = None
    status: str


class ProjectRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    name: str
    description: Optional[str]
    problem_statement: Optional[str]
    solution: Optional[str]
    objectives: Optional[str]
    expected_impact: Optional[str]
    budget_estimated: float
    status: str
    started_at: Optional[date]
    ended_at: Optional[date]
    created_at: datetime

    @computed_field
    @property
    def presentation(self) -> dict | None:
        return get_project_presentation(self.name)

    class Config:
        from_attributes = True
