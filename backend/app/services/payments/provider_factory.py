from app.core.config import settings
from app.services.payments.manual_provider import ManualProofProvider
from app.services.payments.mock_provider import MockPaymentProvider
from app.services.payments.paydunya_provider import PayDunyaProvider


def get_payment_provider(provider_name: str | None = None):
    provider = provider_name or settings.MOBILE_MONEY_PROVIDER
    if provider == "manual_proof":
        return ManualProofProvider()
    if provider == "mock":
        return MockPaymentProvider()
    if provider == "paydunya":
        return PayDunyaProvider()
    if provider in {"wave_direct", "orange_money_direct"}:
        raise ValueError(f"{provider} is reserved for a future direct integration")
    raise ValueError(f"Unsupported payment provider: {provider}")
