from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


class InstitutionalTemplateRead(BaseModel):
    code: str
    label: str
    version: str
    category: str
    visibility: str
    scope: str
    reference_prefix: str
    slogan: str
    requires_sg_validation: bool
    requires_tl_approval: bool
    fields: list[dict[str, Any]]
    can_create: bool = False


class InstitutionalDocumentRequestCreate(BaseModel):
    template_code: str
    payload: dict[str, Any] = Field(default_factory=dict)
    pole_id: UUID | None = None
    project_id: UUID | None = None
    event_id: UUID | None = None
    season_id: UUID | None = None


class InstitutionalDocumentRequestUpdate(BaseModel):
    payload: dict[str, Any] | None = None
    pole_id: UUID | None = None
    project_id: UUID | None = None
    event_id: UUID | None = None
    season_id: UUID | None = None


class InstitutionalDocumentReject(BaseModel):
    reason: str = Field(min_length=3, max_length=2000)


class InstitutionalDocumentCancel(BaseModel):
    reason: str | None = Field(default=None, max_length=1000)


class InstitutionalDocumentRequestRead(BaseModel):
    id: UUID
    template_code: str
    template_label: str = ""
    template_version: str
    status: str
    payload: dict[str, Any] = Field(default_factory=dict)

    requested_by: UUID
    submitted_by: UUID | None = None
    submitted_at: datetime | None = None
    sg_validated_by: UUID | None = None
    sg_validated_at: datetime | None = None
    approved_by: UUID | None = None
    approved_at: datetime | None = None
    rejected_by: UUID | None = None
    rejected_at: datetime | None = None
    rejection_reason: str | None = None
    cancelled_by: UUID | None = None
    cancelled_at: datetime | None = None
    cancellation_reason: str | None = None

    pole_id: UUID | None = None
    project_id: UUID | None = None
    event_id: UUID | None = None
    season_id: UUID | None = None

    sequence_number: int | None = None
    official_reference: str | None = None
    generated_document_id: UUID | None = None
    generated_at: datetime | None = None

    can_edit: bool = False
    can_submit: bool = False
    can_sg_validate: bool = False
    can_approve: bool = False
    can_cancel: bool = False

    created_at: datetime
    updated_at: datetime
