from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Protocol


PaymentProviderStatus = str


class PaymentProviderError(RuntimeError):
    def __init__(
        self,
        message: str,
        *,
        code: str = "provider_error",
        public_message: str | None = None,
    ):
        super().__init__(message)
        self.code = code
        self.public_message = public_message or "Paiement indisponible pour le moment."


@dataclass(frozen=True)
class PaymentProviderRequest:
    transaction_id: str
    amount: int
    currency: str
    description: str
    customer_name: str
    customer_email: str | None = None
    customer_phone: str | None = None
    callback_url: str | None = None
    return_url: str | None = None
    cancel_url: str | None = None
    channel: str | None = None
    custom_data: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PaymentProviderResult:
    provider: str
    status: PaymentProviderStatus
    provider_token: str | None = None
    provider_transaction_id: str | None = None
    checkout_url: str | None = None
    expires_at: datetime | None = None
    provider_status: str | None = None
    failure_code: str | None = None
    failure_message: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


class PaymentProvider(Protocol):
    name: str

    async def create_payment(
        self,
        request: PaymentProviderRequest,
    ) -> PaymentProviderResult:
        ...

    async def get_payment_status(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
    ) -> PaymentProviderResult:
        ...

    async def verify_callback(self, payload: dict[str, Any]) -> PaymentProviderResult:
        ...

    async def cancel_payment(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
    ) -> PaymentProviderResult:
        ...

    async def refund_payment(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
        amount: int | None = None,
        reason: str | None = None,
    ) -> PaymentProviderResult:
        ...
