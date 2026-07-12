from app.services.payments.base import (
    PaymentProviderError,
    PaymentProviderRequest,
    PaymentProviderResult,
)


class ManualProofProvider:
    name = "manual_proof"

    async def create_payment(
        self,
        request: PaymentProviderRequest,
    ) -> PaymentProviderResult:
        return PaymentProviderResult(
            provider=self.name,
            status="pending",
            metadata={"requires_manual_proof": True},
        )

    async def get_payment_status(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
    ) -> PaymentProviderResult:
        return PaymentProviderResult(
            provider=self.name,
            status="pending",
            metadata={"requires_manual_proof": True},
        )

    async def verify_callback(self, payload: dict) -> PaymentProviderResult:
        raise PaymentProviderError(
            "Manual proof provider does not accept callbacks",
            code="callback_not_supported",
        )

    async def cancel_payment(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
    ) -> PaymentProviderResult:
        return PaymentProviderResult(provider=self.name, status="cancelled")

    async def refund_payment(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
        amount: int | None = None,
        reason: str | None = None,
    ) -> PaymentProviderResult:
        raise PaymentProviderError(
            "Manual proof provider cannot issue automatic refunds",
            code="refund_not_supported",
            public_message="Remboursement automatique indisponible. Traitement manuel requis.",
        )
