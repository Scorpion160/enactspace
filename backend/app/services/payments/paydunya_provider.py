from app.core.time import utc_now
import asyncio
import hashlib
import hmac
import json
import re
import time
import math
from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation
from uuid import UUID
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, build_opener, HTTPRedirectHandler
from urllib.parse import quote, urlsplit, unquote

from app.core.config import settings
from app.services.payments.base import (
    MAX_MOBILE_MONEY_AMOUNT,
    PaymentProviderError,
    PaymentProviderRequest,
    PaymentProviderResult,
)


MAX_PROVIDER_RESPONSE_BYTES = 1024 * 1024


def provider_text(value, maximum: int, *, required: bool = False):
    if value is None and not required:
        return None
    if not isinstance(value, str) or not value or len(value) > maximum or any(
        ord(char) < 32 or ord(char) == 127 for char in value
    ):
        raise PaymentProviderError("Invalid provider field", code="provider_invalid_response")
    return value


def validated_provider_token(value):
    token = provider_text(value, 180, required=True)
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,180}", token):
        raise PaymentProviderError("Invalid invoice token", code="provider_invalid_response")
    return token


def provider_amount(value, *, required: bool):
    if value is None and not required:
        return None
    if isinstance(value, bool) or not isinstance(value, (str, int, float)):
        raise PaymentProviderError("Invalid provider amount", code="provider_invalid_response")
    try:
        amount = Decimal(str(value))
        if not amount.is_finite() or amount != amount.to_integral_value() or not 0 < amount <= MAX_MOBILE_MONEY_AMOUNT:
            raise ValueError("Invalid amount")
        return int(amount)
    except (InvalidOperation, ValueError):
        raise PaymentProviderError("Invalid provider amount", code="provider_invalid_response") from None


def strict_json_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON key")
        result[key] = value
    return result


def reject_json_constant(value):
    raise ValueError("Non-finite JSON value")


class _NoProviderRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        raise PaymentProviderError("Provider redirect refused", code="provider_redirect_refused")


def provider_timeout_seconds() -> float:
    value = float(settings.PAYDUNYA_TIMEOUT_SECONDS)
    return min(30.0, max(1.0, value)) if math.isfinite(value) else 15.0


def validated_checkout_url(value, token: str) -> str:
    if not isinstance(value, str) or len(value) > 2048 or any(
        char.isspace() or ord(char) < 32 or ord(char) == 127 for char in value
    ):
        raise PaymentProviderError("Invalid checkout URL", code="provider_invalid_response")
    try:
        url = urlsplit(value)
        expected = {"/checkout/invoice/" + token, "/sandbox-checkout/invoice/" + token}
        valid = (
            url.scheme == "https" and url.hostname == "app.paydunya.com"
            and url.port in {None, 443} and url.username is None and url.password is None
            and not url.fragment and unquote(url.path) in expected
        )
    except ValueError:
        valid = False
    if not valid:
        raise PaymentProviderError("Invalid checkout URL", code="provider_invalid_response")
    return value


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
        timeout = provider_timeout_seconds()
        deadline = time.monotonic() + timeout
        try:
            with build_opener(_NoProviderRedirect()).open(request, timeout=timeout) as response:
                chunks = bytearray()
                reader = getattr(response, "read1", response.read)
                while True:
                    if time.monotonic() >= deadline:
                        raise PaymentProviderError("Provider deadline reached", code="provider_timeout")
                    chunk = reader(min(65536, MAX_PROVIDER_RESPONSE_BYTES + 1 - len(chunks)))
                    if not chunk:
                        break
                    chunks.extend(chunk)
                    if len(chunks) > MAX_PROVIDER_RESPONSE_BYTES:
                        raise PaymentProviderError("Provider response too large", code="provider_response_too_large")
                data = json.loads(chunks.decode("utf-8"), object_pairs_hook=strict_json_object, parse_constant=reject_json_constant)
        except HTTPError as exc:
            # Never read or propagate the provider's error body.
            raise PaymentProviderError("Provider HTTP error", code="provider_http_error") from exc
        except (TimeoutError, URLError, OSError) as exc:
            raise PaymentProviderError("Provider network unavailable", code="provider_network_error") from exc
        except (UnicodeError, ValueError, RecursionError) as exc:
            raise PaymentProviderError("Invalid provider response", code="provider_invalid_response") from exc
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
        try:
            return await asyncio.wait_for(
                asyncio.to_thread(self._request_sync, method, path, payload),
                timeout=provider_timeout_seconds() + 1,
            )
        except TimeoutError as exc:
            raise PaymentProviderError("Provider deadline reached", code="provider_timeout") from exc

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
            **request.custom_data,
            "enactspace_transaction_id": request.transaction_id,
        }
        if request.channel:
            custom_data["channel"] = request.channel

        customer = {
            key: value.strip()
            for key, value in {
                "name": request.customer_name,
                "email": request.customer_email,
                "phone": request.customer_phone,
            }.items()
            if isinstance(value, str) and value.strip()
        }
        channels = {}
        if request.channel:
            allowed = {value.strip() for value in settings.PAYDUNYA_ALLOWED_CHANNELS.split(",") if value.strip()}
            if request.channel not in allowed:
                raise PaymentProviderError("Unsupported payment channel", code="unsupported_channel")
            channels = {"channels": [request.channel]}

        return {
            "invoice": {
                **({"customer": customer} if customer else {}),
                **channels,
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
        value = provider_text(provider_status, 100, required=True).strip().lower()
        statuses = {
            "completed": "successful", "complete": "successful", "paid": "successful",
            "success": "successful", "successful": "successful",
            "cancelled": "cancelled", "canceled": "cancelled",
            "failed": "failed", "failure": "failed", "declined": "failed",
            "expired": "expired", "refunded": "refunded",
            "pending": "pending", "created": "pending", "processing": "pending",
        }
        if value not in statuses:
            raise PaymentProviderError("Unknown provider status", code="provider_invalid_response")
        return statuses[value]

    def _callback_data(self, payload: dict[str, Any]) -> dict[str, Any]:
        data = payload.get("data", payload)
        if not isinstance(data, dict):
            raise PaymentProviderError(
                "PayDunya callback payload is invalid",
                code="invalid_callback",
            )
        return data

    def _callback_hash(self, data: dict[str, Any]) -> str | None:
        value = data.get("hash")
        if value is None and isinstance(data.get("data"), dict):
            value = data["data"].get("hash")
        return value if isinstance(value, str) and re.fullmatch(r"[0-9a-f]{128}", value) else None

    def _callback_invoice(self, data: dict[str, Any]) -> dict[str, Any]:
        invoice = data.get("invoice", {})
        if not isinstance(invoice, dict):
            raise PaymentProviderError("Invalid callback invoice", code="invalid_callback")
        return invoice

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
        if isinstance(request.amount, bool) or not isinstance(request.amount, int) or not 0 < request.amount <= MAX_MOBILE_MONEY_AMOUNT:
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
                "PayDunya invoice creation failed",
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

        token = validated_provider_token(token)
        checkout_url = validated_checkout_url(checkout_url, token)

        return PaymentProviderResult(
            provider=self.name,
            status="pending",
            provider_token=str(token),
            checkout_url=str(checkout_url),
            expires_at=utc_now()
            + timedelta(minutes=settings.PAYMENT_TRANSACTION_TTL_MINUTES),
            provider_status=provider_text(response.get("description"), 100) or "created",
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
        provider_token_value = validated_provider_token(provider_token)
        response = await self._request(
            "GET",
            f"/checkout-invoice/confirm/{quote(provider_token_value, safe='')}",
        )
        if response.get("response_code") != "00":
            raise PaymentProviderError("PayDunya status lookup failed", code="provider_invalid_response")
        invoice = response.get("invoice")
        if not isinstance(invoice, dict) or invoice.get("token") != provider_token_value:
            raise PaymentProviderError("Inconsistent invoice response", code="provider_invalid_response")
        returned_status = response.get("status", invoice.get("status"))
        status = self._status_from_paydunya(returned_status)
        amount = provider_amount(invoice.get("total_amount"), required=status == "successful")
        raw_currency = invoice.get("currency", response.get("currency"))
        currency = provider_text("XOF" if raw_currency is None else raw_currency, 10, required=True)
        if currency.strip().upper() not in {"XOF", "FCFA", "CFA"}:
            raise PaymentProviderError("Unsupported provider currency", code="provider_invalid_response")
        reference = provider_text(
            invoice.get("transaction_id", response.get("transaction_id", provider_transaction_id)), 180)
        # Only retain the internal reference; no arbitrary provider/customer payload is persisted.
        raw_custom = response.get("custom_data", invoice.get("custom_data", {}))
        if raw_custom is None:
            raw_custom = {}
        if not isinstance(raw_custom, dict):
            raise PaymentProviderError("Invalid provider metadata", code="provider_invalid_response")
        custom_data = {}
        if "enactspace_transaction_id" in raw_custom:
            internal_id = provider_text(raw_custom["enactspace_transaction_id"], 36, required=True)
            try:
                custom_data["enactspace_transaction_id"] = str(UUID(internal_id))
            except ValueError:
                raise PaymentProviderError("Invalid internal reference", code="provider_invalid_response") from None
        return PaymentProviderResult(
            provider=self.name,
            provider_token=provider_token_value,
            provider_transaction_id=reference,
            status=status,
            provider_status=returned_status,
            metadata={
                "response_code": "00",
                "mode": settings.PAYDUNYA_MODE,
                "amount": amount,
                "currency": "XOF",
                "custom_data": custom_data,
            },
        )

    async def verify_callback(self, payload: dict) -> PaymentProviderResult:
        self._ensure_configured()
        data = self._callback_data(payload)
        received_hash = self._callback_hash(data)
        expected_hash = hashlib.sha512(
            (settings.PAYDUNYA_MASTER_KEY or "").encode("utf-8")
        ).hexdigest()
        if not received_hash or not hmac.compare_digest(received_hash.encode("utf-8"), expected_hash.encode("ascii")):
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
        try:
            token = validated_provider_token(token)
        except PaymentProviderError:
            raise PaymentProviderError("Invalid callback invoice token", code="invalid_callback") from None
        # A callback only triggers a lookup; its status and amounts cannot authorize money.
        confirmed = await self.get_payment_status(provider_token=str(token))
        return confirmed

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
