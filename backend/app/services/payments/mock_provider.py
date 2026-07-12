from datetime import datetime, timedelta

from app.services.payments.base import PaymentProviderRequest, PaymentProviderResult


class MockPaymentProvider:
    name = "mock"

    async def create_payment(
        self,
        request: PaymentProviderRequest,
    ) -> PaymentProviderResult:
        expires_at = datetime.utcnow() + timedelta(minutes=30)
        return PaymentProviderResult(
            provider=self.name,
            provider_token=f"mock_{request.transaction_id}",
            provider_transaction_id=f"mock_tx_{request.transaction_id}",
            checkout_url=f"https://mock.enactspace.local/pay/{request.transaction_id}",
            status="pending",
            expires_at=expires_at,
            provider_status="created",
        )

    async def get_payment_status(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
    ) -> PaymentProviderResult:
        return PaymentProviderResult(
            provider=self.name,
            provider_token=provider_token,
            provider_transaction_id=provider_transaction_id,
            status="pending",
            provider_status="pending",
        )

    async def verify_callback(self, payload: dict) -> PaymentProviderResult:
        status = payload.get("status") or "pending"
        return PaymentProviderResult(
            provider=self.name,
            provider_token=payload.get("provider_token"),
            provider_transaction_id=payload.get("provider_transaction_id"),
            status=status,
            provider_status=status,
        )

    async def cancel_payment(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
    ) -> PaymentProviderResult:
        return PaymentProviderResult(
            provider=self.name,
            provider_token=provider_token,
            provider_transaction_id=provider_transaction_id,
            status="cancelled",
            provider_status="cancelled",
        )

    async def refund_payment(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
        amount: int | None = None,
        reason: str | None = None,
    ) -> PaymentProviderResult:
        return PaymentProviderResult(
            provider=self.name,
            provider_token=provider_token,
            provider_transaction_id=provider_transaction_id,
            status="refunded",
            provider_status="refunded",
        )
