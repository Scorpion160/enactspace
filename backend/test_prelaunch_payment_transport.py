"""Bounded provider transport and checkout URLs without network access."""
import asyncio,io,unittest
from unittest.mock import MagicMock,patch
from urllib.error import HTTPError,URLError
from app.services.payments import PaymentProviderError,PaymentProviderRequest
from app.services.payments import paydunya_provider as module
from app.services.payments.paydunya_provider import PayDunyaProvider

class PayDunyaTransportTests(unittest.TestCase):
    def request(self,body):
        opener=MagicMock()
        opener.open.return_value.__enter__.return_value=io.BytesIO(body)
        with patch.object(module,"build_opener",return_value=opener):
            result=PayDunyaProvider()._request_sync("GET","/checkout-invoice/confirm/test")
        self.assertIsInstance(opener.open.call_args.kwargs["timeout"],float)
        return result
    def test_valid_small_response_is_decoded(self):
        self.assertEqual(self.request(b'{"response_code":"00"}'),{"response_code":"00"})
    def test_oversize_response_is_rejected(self):
        with self.assertRaises(PaymentProviderError) as error:
            self.request(b"x"*(module.MAX_PROVIDER_RESPONSE_BYTES+1))
        self.assertEqual(error.exception.code,"provider_response_too_large")
    def test_invalid_json_encoding_and_non_object_responses_are_rejected(self):
        for body in (b"not json",b"\xff",b"[]"):
            with self.subTest(body=body),self.assertRaises(PaymentProviderError) as error:self.request(body)
            self.assertEqual(error.exception.code,"provider_invalid_response")
    def test_http_error_body_and_network_reason_are_not_propagated(self):
        http=HTTPError("https://provider.example.test",500,"synthetic-private-detail",{},io.BytesIO(b"synthetic-private-body"))
        http.read=MagicMock(side_effect=AssertionError("Error body must not be read"))
        for exc,code in ((http,"provider_http_error"),(URLError("synthetic-private-reason"),"provider_network_error"),
                         (TimeoutError("synthetic-private-timeout"),"provider_network_error")):
            opener=MagicMock();opener.open.side_effect=exc
            with patch.object(module,"build_opener",return_value=opener),self.assertRaises(PaymentProviderError) as error:
                PayDunyaProvider()._request_sync("GET","/checkout-invoice/confirm/test")
            self.assertEqual(error.exception.code,code);self.assertNotIn("synthetic-private",str(error.exception))
        http.read.assert_not_called()
    def test_redirect_handler_refuses_both_external_and_internal_redirects(self):
        from urllib.request import Request
        for url in ("https://outside.example.test/","https://app.paydunya.com/api/v1/other"):
            with self.assertRaises(PaymentProviderError) as error:
                module._NoProviderRedirect().redirect_request(Request("https://app.paydunya.com/api/v1/test"),
                    None,302,"Found",{},url)
            self.assertEqual(error.exception.code,"provider_redirect_refused")
    def test_only_https_checkout_for_the_returned_invoice_is_accepted(self):
        valid=("https://app.paydunya.com/checkout/invoice/test_token",
               "https://app.paydunya.com/sandbox-checkout/invoice/test_token")
        for value in valid:self.assertEqual(module.validated_checkout_url(value,"test_token"),value)
        for value in ("http://app.paydunya.com/checkout/invoice/test_token",
                      "https://outside.example.test/checkout/invoice/test_token",
                      "https://app.paydunya.com@outside.example.test/checkout/invoice/test_token",
                      "https://u:p@app.paydunya.com/checkout/invoice/test_token",
                      "https://app.paydunya.com:444/checkout/invoice/test_token",
                      "https://app.paydunya.com/checkout/invoice/another",
                      "https://app.paydunya.com/checkout/invoice/test_token#fragment",
                      "https://app.paydunya.com/checkout/invoice/test_token\n"):
            with self.subTest(value=value),self.assertRaises(PaymentProviderError):
                module.validated_checkout_url(value,"test_token")
    def test_socket_timeout_is_clamped(self):
        for configured,expected in ((0,1.0),(5,5.0),(999,30.0)):
            with patch.object(module.settings,"PAYDUNYA_TIMEOUT_SECONDS",configured):
                self.assertEqual(module.provider_timeout_seconds(),expected)
    def test_creation_rejects_untrusted_checkout_before_returning_it(self):
        from unittest.mock import AsyncMock
        provider=PayDunyaProvider()
        request=PaymentProviderRequest(transaction_id="test",amount=1000,currency="XOF",
            description="Test",customer_name="Synthetic")
        with patch.object(provider,"_ensure_configured"),patch.object(provider,"_request",AsyncMock(
            return_value={"response_code":"00","token":"test_token","response_text":"https://outside.example.test/pay"})):
            with self.assertRaises(PaymentProviderError):asyncio.run(provider.create_payment(request))

    def invoice_request(self,**changes):
        args=dict(transaction_id="internal-test",amount=1000,currency="XOF",description="Cotisation",
            customer_name=" Personne Test ")
        args.update(changes);return PaymentProviderRequest(**args)
    def test_invoice_prefills_customer_without_empty_optional_fields(self):
        provider=PayDunyaProvider()
        payload=provider._create_invoice_payload(self.invoice_request(customer_email=" synthetic@example.test ",
            customer_phone=" 771111111 "))
        self.assertEqual(payload["invoice"]["customer"],
            {"name":"Personne Test","email":"synthetic@example.test","phone":"771111111"})
        minimal=provider._create_invoice_payload(self.invoice_request(customer_email=" ",customer_phone=None))
        self.assertEqual(minimal["invoice"]["customer"],{"name":"Personne Test"})
        self.assertNotIn("channels",minimal["invoice"])
    def test_invoice_limits_checkout_to_the_selected_operator(self):
        for channel in ("wave-senegal","orange-money-senegal"):
            payload=PayDunyaProvider()._create_invoice_payload(self.invoice_request(channel=channel))
            self.assertEqual(payload["invoice"]["channels"],[channel])
    def test_invoice_rejects_operator_not_allowed_by_configuration(self):
        with patch.object(module.settings,"PAYDUNYA_ALLOWED_CHANNELS","wave-senegal"):
            with self.assertRaises(PaymentProviderError) as error:
                PayDunyaProvider()._create_invoice_payload(self.invoice_request(channel="orange-money-senegal"))
        self.assertEqual(error.exception.code,"unsupported_channel")
    def test_internal_transaction_reference_cannot_be_overridden_by_custom_data(self):
        payload=PayDunyaProvider()._create_invoice_payload(self.invoice_request(
            custom_data={"enactspace_transaction_id":"other","finance_item_ids":["synthetic"]}))
        self.assertEqual(payload["custom_data"]["enactspace_transaction_id"],"internal-test")
        self.assertEqual(payload["custom_data"]["finance_item_ids"],["synthetic"])

    def confirmation(self,**changes):
        response={"response_code":"00","status":"completed",
            "invoice":{"token":"test_token","total_amount":1000,"currency":"XOF"}}
        response.update(changes)
        provider=PayDunyaProvider()
        from unittest.mock import AsyncMock
        with patch.object(provider,"_ensure_configured"),patch.object(provider,"_request",
            AsyncMock(return_value=response)):
            return asyncio.run(provider.get_payment_status(provider_token="test_token"))
    def test_confirmation_requires_matching_invoice_token_and_known_status(self):
        for invoice in (None,[],{},{"token":"different","total_amount":1000}):
            with self.subTest(invoice=invoice),self.assertRaises(PaymentProviderError):
                self.confirmation(invoice=invoice)
        for status in ("unknown","x"*101,[],{},False,"completed\n"):
            with self.subTest(status=status),self.assertRaises(PaymentProviderError):self.confirmation(status=status)
    def test_confirmation_rejects_invalid_amounts_currencies_and_references(self):
        for amount in (None,True,[],{},"NaN","Infinity",-1,1.5,2147483648):
            with self.subTest(amount=amount),self.assertRaises(PaymentProviderError):
                self.confirmation(invoice={"token":"test_token","total_amount":amount})
        for currency in ("EUR",[],{},False,"","X"*11):
            with self.subTest(currency=currency),self.assertRaises(PaymentProviderError):
                self.confirmation(invoice={"token":"test_token","total_amount":1000,"currency":currency})
        for reference in ([],{},"x"*181,"ref\n"):
            with self.subTest(reference=reference),self.assertRaises(PaymentProviderError):
                self.confirmation(invoice={"token":"test_token","total_amount":1000,"transaction_id":reference})
    def test_receipt_url_is_not_used_as_transaction_identifier_and_metadata_is_minimal(self):
        internal="00000000-0000-0000-0000-000000000001"
        result=self.confirmation(invoice={"token":"test_token","total_amount":"1000",
            "receipt_url":"https://app.paydunya.com/"+"x"*500},
            custom_data={"enactspace_transaction_id":internal,"synthetic_private":"do-not-persist"})
        self.assertIsNone(result.provider_transaction_id)
        self.assertEqual(result.metadata["custom_data"],{"enactspace_transaction_id":internal})
        self.assertEqual(result.metadata["amount"],1000)
    def test_invalid_internal_metadata_is_rejected(self):
        for custom in ([],True,{"enactspace_transaction_id":[]},{"enactspace_transaction_id":"bad"}):
            with self.subTest(custom=custom),self.assertRaises(PaymentProviderError):
                self.confirmation(custom_data=custom)
    def test_invalid_lookup_token_is_rejected_before_network(self):
        from unittest.mock import AsyncMock
        provider=PayDunyaProvider()
        with patch.object(provider,"_ensure_configured"),patch.object(provider,"_request",AsyncMock()) as lookup:
            for token in ([],{},True,"token/?query","x"*181,"token\n"):
                with self.subTest(token=token),self.assertRaises(PaymentProviderError):
                    asyncio.run(provider.get_payment_status(provider_token=token))
            lookup.assert_not_awaited()
    def test_ambiguous_non_finite_and_deep_json_are_rejected(self):
        for body in (b'{"status":"pending","status":"completed"}',b'{"amount":NaN}',
                     b'{"amount":Infinity}',b'['*2000+b'0'+b']'*2000):
            with self.subTest(size=len(body)),self.assertRaises(PaymentProviderError):self.request(body)
    def test_creation_rejects_oversized_provider_description(self):
        from unittest.mock import AsyncMock
        provider=PayDunyaProvider()
        with patch.object(provider,"_ensure_configured"),patch.object(provider,"_request",AsyncMock(return_value={
            "response_code":"00","token":"test_token","response_text":"https://app.paydunya.com/checkout/invoice/test_token",
            "description":"x"*101})):
            with self.assertRaises(PaymentProviderError):asyncio.run(provider.create_payment(self.invoice_request()))
    def test_malformed_callback_tokens_and_invoice_are_refused_before_lookup(self):
        from unittest.mock import AsyncMock
        import hashlib
        provider=PayDunyaProvider()
        with patch.object(provider,"_ensure_configured"),patch.object(module.settings,"PAYDUNYA_MASTER_KEY","synthetic"),patch.object(
            provider,"get_payment_status",AsyncMock()) as lookup:
            for invoice in ([],{"token":[]},{"token":True},{"token":"x"*181}):
                with self.subTest(invoice=invoice),self.assertRaises(PaymentProviderError):
                    asyncio.run(provider.verify_callback({"hash":hashlib.sha512(b"synthetic").hexdigest(),"invoice":invoice}))
            lookup.assert_not_awaited()

if __name__=="__main__":unittest.main()
