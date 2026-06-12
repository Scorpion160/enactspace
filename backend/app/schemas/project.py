from pydantic import BaseModel
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class ProjectCreate(BaseModel):
    season_id: Optional[UUID] = None
    name: str
    description: Optional[str] = None
    problem_statement: Optional[str] = None
    solution: Optional[str] = None
    objectives: Optional[str] = None
    expected_impact: Optional[str] = None
    budget_estimated: float = 0
    status: str = "idee"
    started_at: Optional[date] = None
    ended_at: Optional[date] = None


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

    class Config:
        from_attributes = True