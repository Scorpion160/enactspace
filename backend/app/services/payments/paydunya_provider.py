import asyncio
import hashlib
import hmac
import json
from datetime import datetime, timedelta
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from app.core.config import settings
from app.services.payments.base import (
    PaymentProviderError,
    PaymentProviderRequest,
    PaymentProviderResult,
)


class PayDunyaProvider:
    name = "paydunya"

    @property
    def _api_base_url(self) -> str:
        if settings.PAYDUNYA_MODE == "live":
            return "https://app.paydunya.com/api/v1"
        return "https://app.paydunya.com/sandbox-api/v1"

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

    def _headers(self) -> dict[str, str]:
        return {
            "Content-Type": "application/json",
            "PAYDUNYA-MASTER-KEY": settings.PAYDUNYA_MASTER_KEY or "",
            "PAYDUNYA-PUBLIC-KEY": settings.PAYDUNYA_PUBLIC_KEY or "",
            "PAYDUNYA-PRIVATE-KEY": settings.PAYDUNYA_PRIVATE_KEY or "",
            "PAYDUNYA-TOKEN": settings.PAYDUNYA_TOKEN or "",
        }

    def _request_sync(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        request = Request(
            f"{self._api_base_url}{path}",
            data=body,
            headers=self._headers(),
            method=method,
        )
        try:
            with urlopen(
                request,
                timeout=settings.PAYDUNYA_TIMEOUT_SECONDS,
            ) as response:
                response_body = response.read().decode("utf-8")
        except HTTPError as exc:
            error_body = exc.read().decode("utf-8", errors="ignore")
            raise PaymentProviderError(
                f"PayDunya HTTP error {exc.code}: {error_body[:200]}",
                code="provider_http_error",
            ) from exc
        except URLError as exc:
            raise PaymentProviderError(
                f"PayDunya network error: {exc.reason}",
                code="provider_network_error",
            ) from exc

        try:
            data = json.loads(response_body)
        except json.JSONDecodeError as exc:
            raise PaymentProviderError(
                "PayDunya returned an invalid JSON response",
                code="provider_invalid_response",
            ) from exc
        if not isinstance(data, dict):
            raise PaymentProviderError(
                "PayDunya returned an unexpected response",
                code="provider_invalid_response",
            )
        return data

    async def _request(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        return await asyncio.to_thread(self._request_sync, method, path, payload)

    def _checkout_urls(self, request: PaymentProviderRequest) -> dict[str, str]:
        actions = {
            "callback_url": request.callback_url or settings.PAYDUNYA_CALLBACK_URL,
            "return_url": request.return_url or settings.PAYDUNYA_RETURN_URL,
            "cancel_url": request.cancel_url or settings.PAYDUNYA_CANCEL_URL,
        }
        return {key: value for key, value in actions.items() if value}

    def _create_invoice_payload(
        self,
        request: PaymentProviderRequest,
    ) -> dict[str, Any]:
        custom_data = {
            "enactspace_transaction_id": request.transaction_id,
            **request.custom_data,
        }
        if request.channel:
            custom_data["channel"] = request.channel

        return {
            "invoice": {
                "items": {
                    "enactspace_fee": {
                        "name": "Paiement EnactSpace",
                        "quantity": 1,
                        "unit_price": request.amount,
                        "total_price": request.amount,
                        "description": request.description,
                    }
                },
                "total_amount": request.amount,
                "description": request.description,
            },
            "store": {"name": settings.APP_NAME},
            "actions": self._checkout_urls(request),
            "custom_data": custom_data,
        }

    def _status_from_paydunya(self, provider_status: str | None) -> str:
        normalized = (provider_status or "").lower()
        if normalized in {"completed", "complete", "paid", "success", "successful"}:
            return "successful"
        if normalized in {"cancelled", "canceled"}:
            return "cancelled"
        if normalized in {"failed", "failure", "declined"}:
            return "failed"
        if normalized == "expired":
            return "expired"
        if normalized == "refunded":
            return "refunded"
        return "pending"

    def _callback_data(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = payload.get("data", payload)
        if not isinstance(data, dict):
            raise PaymentProviderError(
                "PayDunya callback payload is invalid",
                code="invalid_callback",
            )
        return data

    def _callback_hash(self, data: dict[str, Any]) -> str | None:
        hash_value = data.get("hash")
        if hash_value:
            return str(hash_value)
        nested = data.get("data")
        if isinstance(nested, dict) and nested.get("hash"):
            return str(nested.get("hash"))
        return None

    def _callback_invoice(self, data: dict[str, Any]) -> dict[str, Any]:
        invoice = data.get("invoice")
        if isinstance(invoice, dict):
            return invoice
        return {}

    async def create_payment(
        self,
        request: PaymentProviderRequest,
    ) -> PaymentProviderResult:
        self._ensure_configured()
        if request.currency != "XOF":
            raise PaymentProviderError(
                "PayDunya V1.1 only supports XOF",
                code="currency_not_supported",
            )
        if request.amount <= 0:
            raise PaymentProviderError(
                "PayDunya amount must be positive",
                code="invalid_amount",
            )

        response = await self._request(
            "POST",
            "/checkout-invoice/create",
            self._create_invoice_payload(request),
        )
        if response.get("response_code") != "00":
            raise PaymentProviderError(
                f"PayDunya invoice creation failed: {response.get('description')}",
                code="invoice_creation_failed",
                public_message="Le paiement n'a pas pu etre initialise.",
            )

        token = response.get("token")
        checkout_url = response.get("invoice_url") or response.get("response_text")
        if not token or not checkout_url:
            raise PaymentProviderError(
                "PayDunya invoice response is missing token or checkout URL",
                code="provider_invalid_response",
            )

        return PaymentProviderResult(
            provider=self.name,
            status="pending",
            provider_token=str(token),
            checkout_url=str(checkout_url),
            expires_at=datetime.utcnow()
            + timedelta(minutes=settings.PAYMENT_TRANSACTION_TTL_MINUTES),
            provider_status=response.get("description") or "created",
            metadata={
                "response_code": response.get("response_code"),
                "mode": settings.PAYDUNYA_MODE,
            },
        )

    async def get_payment_status(
        self,
        *,
        provider_token: str | None = None,
        provider_transaction_id: str | None = None,
    ) -> PaymentProviderResult:
        self._ensure_configured()
        if not provider_token:
            raise PaymentProviderError(
                "PayDunya invoice token is required for status lookup",
                code="missing_provider_token",
            )
        response = await self._request(
            "GET",
            f"/checkout-invoice/confirm/{provider_token}",
        )
        invoice = response.get("invoice")
        if not isinstance(invoice, dict):
            invoice = {}
        provider_status = (
            response.get("status")
            or invoice.get("status")
            or response.get("description")
        )
        return PaymentProviderResult(
            provider=self.name,
            provider_token=provider_token,
            provider_transaction_id=provider_transaction_id
            or invoice.get("transaction_id")
            or invoice.get("receipt_url"),
            status=self._status_from_paydunya(str(provider_status)),
            provider_status=str(provider_status) if provider_status else None,
            metadata={
                "response_code": response.get("response_code"),
                "mode": settings.PAYDUNYA_MODE,
            },
        )

    async def verify_callback(self, payload: dict) -> PaymentProviderResult:
        self._ensure_configured()
        data = self._callback_data(payload)
        received_hash = self._callback_hash(data)
        expected_hash = hashlib.sha512(
            (settings.PAYDUNYA_MASTER_KEY or "").encode("utf-8")
        ).hexdigest()
        if not received_hash or not hmac.compare_digest(received_hash, expected_hash):
            raise PaymentProviderError(
                "Invalid PayDunya callback hash",
                code="invalid_callback_hash",
                public_message="Callback paiement invalide.",
            )

        invoice = self._callback_invoice(data)
        custom_data = data.get("custom_data") or invoice.get("custom_data") or {}
        if not isinstance(custom_data, dict):
            custom_data = {}
        token = (
            invoice.get("token")
            or data.get("token")
            or data.get("invoice_token")
            or custom_data.get("provider_token")
        )
        provider_status = (
            data.get("status")
            or invoice.get("status")
            or data.get("response_text")
            or data.get("response_code")
        )
        amount = (
            invoice.get("total_amount")
            or data.get("total_amount")
            or data.get("amount")
        )
        currency = (
            invoice.get("currency")
            or data.get("currency")
            or custom_data.get("currency")
            or "XOF"
        )
        provider_transaction_id = (
            invoice.get("receipt_url")
            or invoice.get("transaction_id")
            or data.get("transaction_id")
        )
        return PaymentProviderResult(
            provider=self.name,
            provider_token=str(token) if token else None,
            provider_transaction_id=(
                str(provider_transaction_id) if provider_transaction_id else None
            ),
            status=self._status_from_paydunya(str(provider_status)),
            provider_status=str(provider_status) if provider_status else None,
            metadata={
                "amount": amount,
                "currency": currency,
                "custom_data": custom_data,
                "event_id": data.get("event_id") or data.get("reference"),
                "response_code": data.get("response_code"),
                "mode": settings.PAYDUNYA_MODE,
            },
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
