from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


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


class MobileMoneyInitiateRequest(BaseModel):
    finance_item_id: UUID | None = None
    finance_item_ids: list[UUID] = Field(default_factory=list)
    member_id: UUID | None = None
    channel: str | None = None

    @model_validator(mode="after")
    def validate_finance_items(self):
        item_ids = list(self.finance_item_ids)
        if self.finance_item_id:
            item_ids.append(self.finance_item_id)
        if not item_ids:
            raise ValueError("Au moins une dette est obligatoire")
        if len(set(item_ids)) != len(item_ids):
            raise ValueError("Une dette ne peut pas etre selectionnee deux fois")
        return self


class MobileMoneyInitiationRead(BaseModel):
    transaction_id: UUID
    amount: int
    currency: str
    status: str
    checkout_url: str | None
    expires_at: datetime | None
    message: str


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
