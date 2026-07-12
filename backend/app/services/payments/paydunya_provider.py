from app.core.config import settings
from app.services.payments.base import (
    PaymentProviderError,
    PaymentProviderRequest,
    PaymentProviderResult,
)


class PayDunyaProvider:
    name = "paydunya"

    def _ensure_configured(self) -> None:
        required = [
            settings.PAYDUNYA_MASTER_KEY,
            settings.PAYDUNYA_PUBLIC_KEY,
            settings.PAYDUNYA_PRIVATE_KEY,
            settings.PAYDUNYA_TOKEN,
        ]
        if not all(required):
            raise PaymentProviderError(
                "PayDunya credentials are not configured",
                code="provider_not_configured",
                public_message="Le paiement Mobile Money est indisponible pour le moment.",
            )

    async def create_payment(
        self,
        request: PaymentProviderRequest,
    ) -> PaymentProviderResult:
        self._ensure_configured()
        raise PaymentProviderError(
            "PayDunya checkout creation is implemented in the sandbox provider tranche",
            code="provider_not_implemented",
        )

    async def get_payment_status(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
    ) -> PaymentProviderResult:
        self._ensure_configured()
        raise PaymentProviderError(
            "PayDunya status lookup is implemented in the reconciliation tranche",
            code="provider_not_implemented",
        )

    async def verify_callback(self, payload: dict) -> PaymentProviderResult:
        self._ensure_configured()
        raise PaymentProviderError(
            "PayDunya callback verification is implemented in the webhook tranche",
            code="provider_not_implemented",
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
            provider_status="cancelled_locally",
        )

    async def refund_payment(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
        amount: int | None = None,
        reason: str | None = None,
    ) -> PaymentProviderResult:
        raise PaymentProviderError(
            "PayDunya automatic refunds are not enabled",
            code="refund_not_supported",
            public_message="Remboursement automatique indisponible. Traitement manuel requis.",
        )
