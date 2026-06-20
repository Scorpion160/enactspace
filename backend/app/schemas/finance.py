from pydantic import BaseModel
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class FeeCreate(BaseModel):
    user_id: UUID
    season_id: Optional[UUID] = None
    type: str
    label: str
    amount: float
    due_date: Optional[date] = None


class FeeRead(BaseModel):
    id: UUID
    user_id: UUID
    season_id: Optional[UUID]
    type: str
    label: str
    amount: float
    amount_paid: float
    status: str
    due_date: Optional[date]
    related_attendance_id: Optional[UUID]
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
    amount: float
    method: str
    reference: Optional[str] = None
    proof_url: Optional[str] = None


class PaymentRead(BaseModel):
    id: UUID
    user_id: UUID
    amount: float
    method: str
    status: str
    reference: Optional[str]
    proof_url: Optional[str]
    validated_by: Optional[UUID]
    validated_at: Optional[datetime]
    receipt_url: Optional[str]
    can_validate: bool = False
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
    amount: float
    project_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    proof_url: Optional[str] = None


class ClubTransactionRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    type: str
    category: Optional[str]
    label: str
    amount: float
    project_id: Optional[UUID]
    pole_id: Optional[UUID]
    payment_id: Optional[UUID]
    proof_url: Optional[str]
    created_by: Optional[UUID]
    validated_by: Optional[UUID]
    created_at: datetime

    class Config:
        from_attributes = True
