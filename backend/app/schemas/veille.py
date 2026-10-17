from datetime import date, datetime
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator
from app.core.time import utc_now

Short = Annotated[str, StringConstraints(strip_whitespace=True, min_length=3, max_length=200)]
Text = Annotated[str, StringConstraints(strip_whitespace=True, min_length=6, max_length=12000)]
Action = Literal["accompagnement", "clarification", "avertissement", "penalite_financiere", "classement_sans_suite"]


class Payload(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ScopePayload(Payload):
    season_id: UUID | None = None
    pole_id: UUID | None = None
    project_id: UUID | None = None

    @model_validator(mode="after")
    def one_scope(self):
        if self.pole_id and self.project_id:
            raise ValueError("Choisissez un pôle ou un projet pour ce suivi.")
        return self


class PlanCreate(ScopePayload):
    owner_id: UUID
    title: Short
    expected_result: Text
    availability: Text
    due_date: datetime
    course_ids: list[UUID] = Field(default_factory=list, max_length=24)


class PlanChange(PlanCreate):
    version: int = Field(ge=1)
    reason: Text
    status: Literal["active", "completed", "cancelled"] = "active"


class ActionCreate(ScopePayload):
    owner_id: UUID
    plan_id: UUID | None = None
    title: Short
    description: Text
    priority: Literal["basse", "normale", "haute", "urgente"] = "normale"
    due_date: datetime
    proof_required: bool = True


class BlockerCreate(Payload):
    task_id: UUID
    owner_id: UUID
    title: Short
    cause: Literal["dependance", "ressources", "clarification", "technique", "disponibilite", "autre"]
    description: Text
    requested_help: Text
    next_action: Text
    review_at: datetime


class BlockerChange(Payload):
    version: int = Field(ge=1)
    owner_id: UUID
    next_action: Text
    review_at: datetime
    status: Literal["open", "resolved"] = "open"
    resolution: Text | None = None


class ReviewCreate(Payload):
    verdict: Literal["accepted", "rework"]
    feedback: Text
    quality: int | None = Field(default=None, ge=1, le=5)
    expected_updated_at: datetime


class ReportCreate(ScopePayload):
    title: Short
    kind: Literal["weekly", "monthly", "handover"]
    period_start: date
    period_end: date
    observations: Text
    next_actions: Text

    @model_validator(mode="after")
    def valid_period(self):
        if self.period_end < self.period_start or (self.period_end-self.period_start).days > 366:
            raise ValueError("Choisissez une période de 366 jours au maximum, dans l’ordre chronologique.")
        return self


class LeaveCreate(Payload):
    member_id: UUID
    start_date: date
    end_date: date
    reason: Text

    @model_validator(mode="after")
    def valid_period(self):
        if self.end_date < self.start_date or (self.end_date-self.start_date).days > 366:
            raise ValueError("La période d’indisponibilité est invalide.")
        return self


class LeaveChange(Payload):
    version: int = Field(ge=1)
    status: Literal["approved", "rejected", "cancelled"]
    response: Text


class CaseCreate(Payload):
    member_id: UUID
    bureau_reviewer_id: UUID
    task_id: UUID | None = None
    attendance_id: UUID | None = None
    rule_id: UUID | None = None
    title: Short
    facts: Text
    observed_at: date = Field(default_factory=lambda: utc_now().date())


class CaseAction(Payload):
    version: int = Field(ge=1)
    action: Literal["notify", "respond", "propose", "endorse", "decide", "appeal", "propose_review", "review_decide", "accept", "close", "comment"]
    message: Text
    outcome: Action | None = None
    amount: int = Field(default=0, ge=0, le=10000000)


class RuleCreate(Payload):
    title: Short
    content: Text
    effective_from: date
    allowed_actions: list[Action] = Field(min_length=1, max_length=5)
    maximum_amount: int = Field(default=0, ge=0, le=10000000)

    @model_validator(mode="after")
    def amount_rule(self):
        if "penalite_financiere" in self.allowed_actions and self.maximum_amount <= 0:
            raise ValueError("Une pénalité financière exige un montant maximal explicite.")
        return self


class SettingsChange(Payload):
    version: int = Field(ge=1)
    reminders_enabled: bool
    quiet_start_hour: int = Field(ge=0, le=23)
    quiet_end_hour: int = Field(ge=0, le=23)
    escalation_days: int = Field(ge=1, le=30)
    response_days: int = Field(ge=1, le=30)
    appeal_days: int = Field(ge=1, le=60)
    weekly_day: int = Field(ge=0, le=6)
    report_hour: int = Field(ge=0, le=23)
    auto_reports: bool


class DeadlineChange(Payload):
    due_date: datetime
    reason: Text
    expected_updated_at: datetime
