"""PayDunya sandbox contract tests: no network, merchant key, or payment."""
import hashlib
from types import SimpleNamespace
from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import AsyncMock, patch
from uuid import UUID

from fastapi import HTTPException

from app.services import mobile_money_service
from app.services.payments.base import (
    PaymentProviderError, PaymentProviderRequest, PaymentProviderResult,
)
from app.services.payments import paydunya_provider


TOKEN = "test_EnactspaceContract01"
TX_ID = "00000000-0000-4000-8000-000000000123"
AMOUNT = 500


def demo_settings():
    return SimpleNamespace(
        PAYDUNYA_MODE="test", PAYDUNYA_MASTER_KEY="nonproduction-master-key",
        PAYDUNYA_PUBLIC_KEY="nonproduction-public-key",
        PAYDUNYA_PRIVATE_KEY="nonproduction-private-key",
        PAYDUNYA_TOKEN="nonproduction-token",
        PAYDUNYA_ALLOWED_CHANNELS="wave-senegal,orange-money-senegal",
        PAYDUNYA_CALLBACK_URL="https://payments.example.org/api/payments/paydunya/ipn",
        PAYDUNYA_RETURN_URL="https://payments.example.org/finance/return",
        PAYDUNYA_CANCEL_URL="https://payments.example.org/finance/cancel",
        APP_NAME="EnactSpace test", PAYMENT_TRANSACTION_TTL_MINUTES=30,
    )


def status_response(status="pending", *, amount=AMOUNT, token=TOKEN,
                    currency="XOF", custom_id=TX_ID):
    return {
        "response_code": "00", "status": status,
        "invoice": {
            "token": token, "total_amount": amount, "currency": currency,
            "custom_data": {"enactspace_transaction_id": custom_id},
        },
    }


class PayDunyaSandboxContractTests(IsolatedAsyncioTestCase):
    def setUp(self):
        self.config = demo_settings()
        self.enterContext(patch.object(paydunya_provider, "settings", self.config))
        self.provider = paydunya_provider.PayDunyaProvider()
        self.provider._request = AsyncMock()

    async def test_create_invoice_uses_sandbox_and_selected_channel(self):
        self.provider._request.return_value = {
            "response_code": "00", "token": TOKEN,
            "response_text": (
                "https://app.paydunya.com/sandbox-checkout/invoice/" + TOKEN
            ),
        }
        request = PaymentProviderRequest(
            transaction_id=TX_ID, amount=AMOUNT, currency="XOF",
            description="Cotisation de test", customer_name="Utilisateur fictif",
            customer_email="fictif@example.invalid", channel="wave-senegal",
            custom_data={"finance_item_ids": ["fake-fee"]},
        )
        result = await self.provider.create_payment(request)
        self.assertEqual(self.provider._api_base_url,
                         "https://app.paydunya.com/sandbox-api/v1")
        self.provider._request.assert_awaited_once()
        method, path, payload = self.provider._request.await_args.args
        self.assertEqual((method, path), ("POST", "/checkout-invoice/create"))
        self.assertEqual(payload["invoice"]["total_amount"], AMOUNT)
        self.assertEqual(payload["invoice"]["channels"], ["wave-senegal"])
        self.assertEqual(payload["custom_data"]["enactspace_transaction_id"], TX_ID)
        self.assertEqual(result.status, "pending")
        self.assertEqual(result.provider_token, TOKEN)

    async def test_provider_redirects_and_inconsistent_tokens_are_rejected(self):
        for url in (
            "https://evil.example.org/checkout/invoice/" + TOKEN,
            "http://app.paydunya.com/sandbox-checkout/invoice/" + TOKEN,
            "https://app.paydunya.com/sandbox-checkout/invoice/DIFFERENT",
        ):
            with self.subTest(url=url):
                self.provider._request.return_value = {
                    "response_code": "00", "token": TOKEN,
                    "response_text": url,
                }
                with self.assertRaises(PaymentProviderError):
                    await self.provider.create_payment(
                        PaymentProviderRequest(
                            transaction_id=TX_ID, amount=AMOUNT, currency="XOF",
                            description="Test", customer_name="Fictif",
                        )
                    )

    async def test_success_requires_provider_confirm_and_matching_amount(self):
        self.provider._request.return_value = status_response("completed")
        result = await self.provider.get_payment_status(provider_token=TOKEN)
        self.assertEqual(result.status, "successful")
        self.assertEqual(result.metadata["amount"], AMOUNT)
        self.assertEqual(result.metadata["currency"], "XOF")
        self.assertEqual(
            result.metadata["custom_data"]["enactspace_transaction_id"], TX_ID
        )
        self.provider._request.assert_awaited_with(
            "GET", "/checkout-invoice/confirm/" + TOKEN
        )

        for response in (
            status_response("completed", amount="not-an-amount"),
            status_response("completed", token="different"),
            status_response("completed", currency="EUR"),
        ):
            with self.subTest(response=response):
                self.provider._request.return_value = response
                with self.assertRaises(PaymentProviderError):
                    await self.provider.get_payment_status(provider_token=TOKEN)

    async def test_ipn_status_cannot_create_a_success_without_provider_confirm(self):
        digest = hashlib.sha512(
            self.config.PAYDUNYA_MASTER_KEY.encode("utf-8")
        ).hexdigest()
        self.provider._request.return_value = status_response("pending")
        forged_ipn = {
            "data": {
                "hash": digest, "status": "completed",
                "invoice": {"token": TOKEN, "total_amount": 10},
            }
        }
        result = await self.provider.verify_callback(forged_ipn)
        self.assertEqual(result.status, "pending")
        self.provider._request.assert_awaited_with(
            "GET", "/checkout-invoice/confirm/" + TOKEN
        )

        self.provider._request.reset_mock()
        forged_ipn["data"]["hash"] = "f" * 128
        with self.assertRaises(PaymentProviderError) as error:
            await self.provider.verify_callback(forged_ipn)
        self.assertEqual(error.exception.code, "invalid_callback_hash")
        self.provider._request.assert_not_awaited()


class PayDunyaReconciliationGuardTests(TestCase):
    def test_accounting_rejects_wrong_amount_token_and_currency(self):
        tx = SimpleNamespace(
            id=UUID(TX_ID), provider="paydunya",
            provider_invoice_token=TOKEN, amount=AMOUNT, currency="XOF",
        )
        valid = PaymentProviderResult(
            provider="paydunya", status="successful",
            provider_token=TOKEN, metadata={
                "amount": AMOUNT, "currency": "XOF",
                "custom_data": {"enactspace_transaction_id": TX_ID},
            }
        )
        mobile_money_service.validate_provider_result(tx, valid)
        for mismatched in (
            {"provider_token": "another"},
            {"metadata": {"amount": AMOUNT - 1, "currency": "XOF"}},
            {"metadata": {"amount": AMOUNT, "currency": "EUR"}},
            {"metadata": {"amount": AMOUNT, "currency": "XOF",
                          "custom_data": {"enactspace_transaction_id":
                                          "00000000-0000-4000-8000-000000000999"}}},
        ):
            with self.subTest(mismatched=mismatched):
                data = {**valid.__dict__, **mismatched}
                with self.assertRaises(HTTPException):
                    mobile_money_service.validate_provider_result(
                        tx, PaymentProviderResult(**data)
                    )


if __name__ == "__main__":
    import unittest
    unittest.main()
