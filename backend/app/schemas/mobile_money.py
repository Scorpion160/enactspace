from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


MOBILE_MONEY_STATUSES = {
    "created",
    "pending",
    "processing",
    "successful",
    "failed",
    "cancelled",
    "expired",
    "refunded",
}


class MobileMoneyTransactionRead(BaseModel):
    id: UUID
    member_id: UUID
    finance_item_id: UUID | None
    payment_id: UUID | None
    provider: str
    provider_transaction_id: str | None
    provider_invoice_token: str | None
    amount: int
    currency: str
    phone_number_masked: str | None
    channel: str | None
    status: str
    provider_status: str | None
    checkout_url: str | None
    failure_code: str | None
    failure_message: str | None
    created_at: datetime
    updated_at: datetime
    expires_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    refunded_at: datetime | None
    last_verified_at: datetime | None
    metadata_json: dict = Field(default_factory=dict)

    class Config:
        from_attributes = True


class MobileMoneyTransactionEventRead(BaseModel):
    id: UUID
    transaction_id: UUID
    event_type: str
    old_status: str | None
    new_status: str | None
    provider_event_id: str | None
    received_at: datetime
    processed_at: datetime | None
    is_duplicate: bool
    error_message: str | None
    metadata_json: dict = Field(default_factory=dict)

    class Config:
        from_attributes = True
