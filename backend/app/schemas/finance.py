from pydantic import BaseModel, Field
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class FeeCreate(BaseModel):
    user_id: UUID
    season_id: Optional[UUID] = None
    type: str
    category: Optional[str] = None
    label: str
    description: Optional[str] = None
    amount: float = Field(ge=0.01, le=9999999999.99, multiple_of=0.01, allow_inf_nan=False)
    currency: str = "FCFA"
    due_date: Optional[date] = None
    source_type: Optional[str] = None
    source_id: Optional[UUID] = None
    proof_file_id: Optional[UUID] = None


class FeeBulkCreate(BaseModel):
    scope_type: str = "club"
    user_ids: list[UUID] = Field(default_factory=list)
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    season_id: Optional[UUID] = None
    type: str = "membership_fee"
    category: Optional[str] = None
    label: str
    description: Optional[str] = None
    amount: float = Field(ge=0.01, le=9999999999.99, multiple_of=0.01, allow_inf_nan=False)
    currency: str = "FCFA"
    due_date: Optional[date] = None


class FeeCancelRequest(BaseModel):
    reason: str


class PaymentRejectRequest(BaseModel):
    reason: str


class FeeRead(BaseModel):
    id: UUID
    user_id: UUID
    season_id: Optional[UUID]
    type: str
    category: Optional[str]
    label: str
    description: Optional[str]
    amount: float
    amount_paid: float
    currency: str
    status: str
    due_date: Optional[date]
    paid_at: Optional[datetime]
    cancelled_at: Optional[datetime]
    related_attendance_id: Optional[UUID]
    source_type: Optional[str]
    source_id: Optional[UUID]
    proof_file_id: Optional[UUID]
    created_at: datetime

    class Config:
        from_attributes = True


class FinancialAccountRead(BaseModel):
    id: UUID
    user_id: UUID
    balance_due: float
    total_paid: float
    updated_at: datetime

    class Config:
        from_attributes = True


class PaymentCreate(BaseModel):
    user_id: UUID
    amount: float = Field(ge=0.01, le=9999999999.99, multiple_of=0.01, allow_inf_nan=False)
    currency: str = "FCFA"
    method: str
    reference: Optional[str] = None
    proof_url: Optional[str] = None
    proof_file_id: Optional[UUID] = None
    fee_ids: list[UUID] = Field(default_factory=list)
    receipt_text: Optional[str] = Field(default=None, max_length=8000)


class PaymentRead(BaseModel):
    id: UUID
    user_id: UUID
    amount: float
    currency: str
    method: str
    status: str
    reference: Optional[str]
    proof_url: Optional[str]
    proof_file_id: Optional[UUID]
    proof_file_name: Optional[str] = None
    proof_mime_type: Optional[str] = None
    allocation_plan: Optional[list] = None
    receipt_details: Optional[dict] = None
    unallocated_amount: float = 0
    validated_by: Optional[UUID]
    validated_at: Optional[datetime]
    rejected_at: Optional[datetime]
    rejection_reason: Optional[str]
    receipt_url: Optional[str]
    receipt_file_id: Optional[UUID]
    can_validate: bool = False
    can_reject: bool = False
    can_cancel: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class PaymentAllocationRead(BaseModel):
    id: UUID
    payment_id: UUID
    fee_id: UUID
    amount: float
    created_at: datetime

    class Config:
        from_attributes = True


class ClubTransactionCreate(BaseModel):
    season_id: Optional[UUID] = None
    type: str
    category: Optional[str] = None
    label: str
    description: Optional[str] = None
    amount: float = Field(ge=0.01, le=9999999999.99, multiple_of=0.01, allow_inf_nan=False)
    currency: str = "FCFA"
    project_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    proof_url: Optional[str] = None
    proof_file_id: Optional[UUID] = None


class ClubTransactionRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    type: str
    category: Optional[str]
    label: str
    description: Optional[str]
    amount: float
    currency: str
    project_id: Optional[UUID]
    pole_id: Optional[UUID]
    payment_id: Optional[UUID]
    proof_url: Optional[str]
    proof_file_id: Optional[UUID]
    created_by: Optional[UUID]
    validated_by: Optional[UUID]
    created_at: datetime

    class Config:
        from_attributes = True
