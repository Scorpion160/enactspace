"""Provider response integrity and Mobile Money routes on synthetic data."""
import asyncio,hashlib,unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock,patch
from uuid import uuid4
import test_prelaunch_finance_boundaries as finance_fixture
import test_veille as fixture
from app.api.routes import finance,payments
from app.services import mobile_money_service as mm
from app.models.mobile_money import MobileMoneyTransaction
from app.models.finance import Payment,ClubTransaction
from app.services.payments import PaymentProviderResult,PaymentProviderError
from app.services.payments.paydunya_provider import PayDunyaProvider
from app.core.config import settings

class MobileMoneyBoundaryTests(unittest.TestCase):
    make_task=fixture.VeilleFlowTests.make_task
    as_user=fixture.VeilleFlowTests.as_user
    request=finance_fixture.FinanceBoundaryTests.request
    def setUp(self):
        finance_fixture.FinanceBoundaryTests.setUp(self)
        self.client.app.include_router(payments.router,prefix="/api")
        self.as_user("a")
    def tearDown(self):finance_fixture.FinanceBoundaryTests.tearDown(self)
    def transaction(self):
        row=MobileMoneyTransaction(member_id=self.users["a"].id,finance_item_id=self.fee.id,
            provider="paydunya",idempotency_key=uuid4().hex,provider_invoice_token="invoice_"+uuid4().hex,
            amount=1000,currency="XOF",status="pending",metadata_json={"finance_item_ids":[str(self.fee.id)]})
        self.db.add(row);self.db.commit();return row
    def result(self,row,**changes):
        args=dict(provider="paydunya",provider_token=row.provider_invoice_token,status="successful",
            provider_transaction_id="receipt_"+str(row.id),metadata={"amount":1000,"currency":"XOF"})
        args.update(changes);return PaymentProviderResult(**args)
    def test_refresh_rejects_inconsistent_and_missing_confirmation_fields(self):
        row=self.transaction()
        results=[self.result(row,metadata=metadata) for metadata in (
            {},{"amount":999,"currency":"XOF"},{"amount":"NaN","currency":"XOF"},
            {"amount":"Infinity","currency":"XOF"},{"amount":-1,"currency":"XOF"},
            {"amount":1000},{"amount":1000,"currency":"EUR"})]
        results += [self.result(row,provider="other"),self.result(row,provider_token="wrong")]
        for result in results:
            provider=SimpleNamespace(get_payment_status=AsyncMock(return_value=result))
            with patch.object(mm,"get_payment_provider",return_value=provider):
                self.request("POST",f"/mobile-money/{row.id}/refresh",code=400)
        self.db.expire_all();self.assertIsNone(row.payment_id)
        self.assertEqual(float(self.account.total_paid),0)
    def test_refresh_confirmation_records_once_and_preserves_owner(self):
        row=self.transaction();provider=SimpleNamespace(get_payment_status=AsyncMock(return_value=self.result(row)))
        with patch.object(mm,"get_payment_provider",return_value=provider):
            for _ in range(2):self.request("POST",f"/mobile-money/{row.id}/refresh")
        self.db.expire_all();self.assertEqual(float(self.account.total_paid),1000)
        self.assertEqual(self.db.query(ClubTransaction).count(),1)
        self.assertEqual(provider.get_payment_status.await_count,1)
    def test_callback_replay_does_not_create_second_payment(self):
        row=self.transaction();provider=SimpleNamespace(verify_callback=AsyncMock(return_value=self.result(row)))
        with patch.object(payments,"get_payment_provider",return_value=provider):
            responses=[self.client.post("/api/payments/paydunya/ipn",json={"synthetic":True}) for _ in range(2)]
        self.assertEqual([r.status_code for r in responses],[200,200],[r.text for r in responses])
        self.db.expire_all();self.assertEqual(float(self.account.total_paid),1000)
        self.assertEqual(self.db.query(ClubTransaction).count(),1);self.assertTrue(responses[1].json()["duplicate"])
    def test_callback_missing_amount_cannot_authorize_payment(self):
        row=self.transaction();provider=SimpleNamespace(verify_callback=AsyncMock(return_value=self.result(row,metadata={"currency":"XOF"})))
        with patch.object(payments,"get_payment_provider",return_value=provider):
            response=self.client.post("/api/payments/paydunya/ipn",json={})
        self.assertEqual(response.status_code,400,response.text)
        self.db.expire_all();self.assertIsNone(row.payment_id)
    def test_cancelled_fee_is_not_resurrected_when_payment_arrives(self):
        row=self.transaction();self.fee.status="cancelled";self.db.commit()
        provider=SimpleNamespace(get_payment_status=AsyncMock(return_value=self.result(row)))
        with patch.object(mm,"get_payment_provider",return_value=provider):
            self.request("POST",f"/mobile-money/{row.id}/refresh")
        self.db.expire_all();self.assertEqual(self.fee.status,"cancelled")
        paid=self.db.get(Payment,row.payment_id)
        self.assertEqual(float(paid.unallocated_amount),1000)
        self.assertEqual(float(self.account.balance_due),3000)
    def test_sequential_initiation_reuses_active_invoice(self):
        calls=[]
        async def create(request):
            calls.append(request)
            return PaymentProviderResult(provider="paydunya",status="pending",
                provider_token="invoice_"+request.transaction_id,checkout_url="https://provider.example.test/pay")
        provider=SimpleNamespace(create_payment=create)
        with patch.object(finance.settings,"MOBILE_MONEY_ENABLED",True),patch.object(
                finance.settings,"MOBILE_MONEY_PROVIDER","paydunya"),patch.object(finance,"get_payment_provider",return_value=provider):
            body={"finance_item_ids":[str(self.fee.id)],"amount":500}
            first=self.request("POST","/mobile-money/initiate",body).json()
            second=self.request("POST","/mobile-money/initiate",body).json()
        self.assertEqual(first["transaction_id"],second["transaction_id"]);self.assertEqual(len(calls),1)

    def test_form_callback_and_ambiguous_fields(self):
        row=self.transaction()
        provider=SimpleNamespace(verify_callback=AsyncMock(return_value=self.result(row)))
        with patch.object(payments,"get_payment_provider",return_value=provider):
            response=self.client.post("/api/payments/paydunya/ipn",
                data={"data[hash]":"synthetic","data[invoice][token]":row.provider_invoice_token})
            self.assertEqual(response.status_code,200,response.text)
            parsed=provider.verify_callback.await_args.args[0]
            self.assertEqual(parsed["data"]["invoice"]["token"],row.provider_invoice_token)
            count=provider.verify_callback.await_count
            response=self.client.post("/api/payments/paydunya/ipn",content="data[hash]=a&data[hash]=b",
                headers={"Content-Type":"application/x-www-form-urlencoded"})
            self.assertEqual(response.status_code,400,response.text)
            response=self.client.post("/api/payments/paydunya/ipn",content="x"*65537,
                headers={"Content-Type":"application/x-www-form-urlencoded"})
            self.assertEqual(response.status_code,413,response.text)
            self.assertEqual(provider.verify_callback.await_count,count)

    def test_network_refresh_keeps_payment_pending_and_uses_public_message(self):
        row=self.transaction()
        provider=SimpleNamespace(get_payment_status=AsyncMock(side_effect=PaymentProviderError(
            "synthetic-private-detail",code="provider_network_error")))
        with patch.object(mm,"get_payment_provider",return_value=provider):
            response=self.request("POST",f"/mobile-money/{row.id}/refresh",code=503)
        self.assertNotIn("synthetic-private",response.text);self.assertEqual(response.headers["Retry-After"],"30")
        self.db.expire_all();self.assertEqual(row.status,"pending");self.assertIsNone(row.payment_id)
        self.assertEqual(float(self.account.total_paid),0)
    def test_network_callback_asks_retry_without_changing_payment(self):
        row=self.transaction()
        provider=SimpleNamespace(verify_callback=AsyncMock(side_effect=PaymentProviderError(
            "synthetic-private-detail",code="provider_timeout")))
        with patch.object(payments,"get_payment_provider",return_value=provider):
            response=self.client.post("/api/payments/paydunya/ipn",json={})
        self.assertEqual(response.status_code,503,response.text)
        self.assertNotIn("synthetic-private",response.text);self.assertEqual(response.headers["Retry-After"],"30")
        self.db.expire_all();self.assertEqual(row.status,"pending");self.assertIsNone(row.payment_id)

    def ordered_transactions(self,count):
        from datetime import timedelta
        from app.core.time import utc_now
        rows=[self.transaction() for _ in range(count)]
        now=utc_now()
        for index,row in enumerate(rows):row.created_at=now-timedelta(minutes=count-index)
        self.db.commit()
        return rows
    def reconcile(self,provider,code=200):
        self.as_user("admin")
        with patch.object(finance.settings,"PAYMENT_RECONCILIATION_ENABLED",True),patch.object(
            mm,"get_payment_provider",return_value=provider):
            return self.request("POST","/mobile-money/reconcile",code=code)
    def test_reconciliation_continues_after_network_error_and_replay_is_safe(self):
        bad,good,pending=self.ordered_transactions(3)
        async def lookup(**kwargs):
            token=kwargs["provider_token"]
            if token==bad.provider_invoice_token:raise PaymentProviderError("synthetic-private-network")
            row=good if token==good.provider_invoice_token else pending
            return self.result(row,status="successful" if row is good else "pending")
        provider=SimpleNamespace(get_payment_status=AsyncMock(side_effect=lookup))
        summary=self.reconcile(provider).json()
        self.assertEqual({key:summary[key] for key in ("checked","successful","pending","deferred","unavailable")},
            {"checked":3,"successful":1,"pending":1,"deferred":1,"unavailable":1})
        self.assertNotIn("synthetic-private",str(summary))
        self.db.expire_all();self.assertEqual(bad.status,"pending");self.assertIsNone(bad.payment_id)
        self.assertEqual(float(self.account.total_paid),1000);self.assertEqual(self.db.query(ClubTransaction).count(),1)
        second=self.reconcile(provider).json();self.assertEqual(second["checked"],0)
        self.db.expire_all();self.assertEqual(self.db.query(ClubTransaction).count(),1)
    def test_reconciliation_reports_inconsistent_confirmation_without_payment(self):
        bad,good=self.ordered_transactions(2)
        async def lookup(**kwargs):
            row=bad if kwargs["provider_token"]==bad.provider_invoice_token else good
            return self.result(row,metadata={"amount":999 if row is bad else 1000,"currency":"XOF"})
        summary=self.reconcile(SimpleNamespace(get_payment_status=AsyncMock(side_effect=lookup))).json()
        self.assertEqual((summary["successful"],summary["deferred"],summary["needs_review"]),(1,1,1))
        self.db.expire_all();self.assertEqual(bad.status,"pending");self.assertIsNone(bad.payment_id)
        self.assertEqual(float(self.account.total_paid),1000)
    def test_reconciliation_rolls_back_partial_accounting_before_next_invoice(self):
        from fastapi import HTTPException
        bad,good=self.ordered_transactions(2)
        original=mm.confirm_transaction
        def confirm(db,**kwargs):
            result=original(db,**kwargs)
            if kwargs["transaction"].id==bad.id:raise HTTPException(400,"synthetic-partial-confirmation")
            return result
        async def lookup(**kwargs):
            return self.result(bad if kwargs["provider_token"]==bad.provider_invoice_token else good)
        with patch.object(mm,"confirm_transaction",side_effect=confirm):
            summary=self.reconcile(SimpleNamespace(get_payment_status=AsyncMock(side_effect=lookup))).json()
        self.assertEqual((summary["successful"],summary["needs_review"]),(1,1))
        self.db.expire_all();self.assertEqual(bad.status,"pending");self.assertIsNone(bad.payment_id)
        self.assertEqual(float(self.account.total_paid),1000);self.assertEqual(self.db.query(ClubTransaction).count(),1)
        self.assertEqual(self.db.query(Payment).filter(Payment.status=="validated").count(),1)
    def test_reconciliation_preserves_prior_success_on_unexpected_later_failure(self):
        from fastapi import HTTPException
        good,bad=self.ordered_transactions(2);original=mm.refresh_transaction
        async def refresh(db,**kwargs):
            if kwargs["transaction"].id==bad.id:raise HTTPException(403,"Synthetic forbidden")
            return await original(db,**kwargs)
        provider=SimpleNamespace(get_payment_status=AsyncMock(return_value=self.result(good)))
        with patch.object(mm,"refresh_transaction",side_effect=refresh):
            self.reconcile(provider,code=403)
        self.db.expire_all();self.assertEqual(good.status,"successful");self.assertEqual(bad.status,"pending")
        self.assertEqual(float(self.account.total_paid),1000);self.assertEqual(self.db.query(ClubTransaction).count(),1)
    def test_member_cannot_trigger_reconciliation(self):
        provider=SimpleNamespace(get_payment_status=AsyncMock())
        with patch.object(finance.settings,"PAYMENT_RECONCILIATION_ENABLED",True),patch.object(
            mm,"get_payment_provider",return_value=provider) as factory:
            self.request("POST","/mobile-money/reconcile",code=403)
        factory.assert_not_called()

    def test_expired_local_deadline_still_accepts_authoritative_payment(self):
        from datetime import timedelta
        from app.core.time import utc_now
        row=self.transaction();row.expires_at=utc_now()-timedelta(hours=1);self.db.commit()
        provider=SimpleNamespace(get_payment_status=AsyncMock(return_value=self.result(row)))
        with patch.object(mm,"get_payment_provider",return_value=provider):
            response=self.request("POST",f"/mobile-money/{row.id}/refresh")
        self.assertEqual(response.json()["status"],"successful")
        self.db.expire_all();self.assertEqual(float(self.account.total_paid),1000)
        self.assertIsNotNone(row.last_verification_attempt_at)
    def test_expired_local_deadline_does_not_invent_provider_failure(self):
        from datetime import timedelta
        from app.core.time import utc_now
        row=self.transaction();row.expires_at=utc_now()-timedelta(hours=1);self.db.commit()
        provider=SimpleNamespace(get_payment_status=AsyncMock(return_value=self.result(row,status="pending")))
        with patch.object(mm,"get_payment_provider",return_value=provider):
            self.assertEqual(self.request("POST",f"/mobile-money/{row.id}/refresh").json()["status"],"pending")
        self.db.expire_all();self.assertIsNone(row.payment_id);self.assertEqual(float(self.account.total_paid),0)
        provider.get_payment_status.assert_awaited_once()
    def test_reconciliation_recovers_recent_closed_invoices_without_callback(self):
        from datetime import timedelta
        from app.core.time import utc_now
        rows=self.ordered_transactions(4)
        for row,state in zip(rows,("expired","cancelled","failed","expired")):row.status=state
        rows[-1].created_at=utc_now()-timedelta(days=8);self.db.commit()
        by_token={row.provider_invoice_token:row for row in rows}
        async def lookup(**kwargs):return self.result(by_token[kwargs["provider_token"]])
        provider=SimpleNamespace(get_payment_status=AsyncMock(side_effect=lookup))
        summary=self.reconcile(provider).json();self.assertEqual((summary["checked"],summary["successful"]),(3,3))
        self.db.expire_all();self.assertEqual(float(self.account.total_paid),3000)
        self.assertEqual(rows[-1].status,"expired");self.assertIsNone(rows[-1].payment_id)
        self.assertEqual(self.db.query(ClubTransaction).count(),3)
    def test_retry_queue_rotates_and_keeps_attempt_separate_from_verified_time(self):
        from datetime import timedelta
        from app.core.time import utc_now
        bad,good=self.ordered_transactions(2)
        async def lookup(**kwargs):
            if kwargs["provider_token"]==bad.provider_invoice_token:raise PaymentProviderError("Synthetic unavailable")
            return self.result(good)
        provider=SimpleNamespace(get_payment_status=AsyncMock(side_effect=lookup))
        self.as_user("admin")
        with patch.object(finance.settings,"PAYMENT_RECONCILIATION_ENABLED",True),patch.object(
            mm,"get_payment_provider",return_value=provider):
            first=self.request("POST","/mobile-money/reconcile?limit=1").json()
            second=self.request("POST","/mobile-money/reconcile?limit=1").json()
            third=self.request("POST","/mobile-money/reconcile?limit=1").json()
            self.assertEqual((first["deferred"],second["successful"],third["checked"]),(1,1,0))
            self.db.expire_all();self.assertIsNone(bad.last_verified_at)
            self.assertIsNotNone(bad.last_verification_attempt_at);self.assertEqual(bad.status,"pending")
            bad.last_verification_attempt_at=utc_now()-timedelta(seconds=61);self.db.commit()
            fourth=self.request("POST","/mobile-money/reconcile?limit=1").json()
            self.assertEqual(fourth["deferred"],1)
        self.db.expire_all();self.assertEqual(float(self.account.total_paid),1000)
    def test_local_expiry_does_not_create_second_unconfirmed_invoice(self):
        from datetime import timedelta
        from app.core.time import utc_now
        row=self.transaction();row.expires_at=utc_now()-timedelta(hours=1);self.db.commit()
        provider=SimpleNamespace(create_payment=AsyncMock())
        with patch.object(finance.settings,"MOBILE_MONEY_ENABLED",True),patch.object(
            finance.settings,"MOBILE_MONEY_PROVIDER","paydunya"),patch.object(
            finance,"get_payment_provider",return_value=provider):
            result=self.request("POST","/mobile-money/initiate",
                {"finance_item_ids":[str(self.fee.id)],"amount":1000}).json()
        self.assertEqual(result["transaction_id"],str(row.id));provider.create_payment.assert_not_awaited()
    def test_verification_attempt_migration_round_trip_preserves_other_data(self):
        import importlib.util
        from pathlib import Path
        from sqlalchemy import inspect,text
        from alembic.migration import MigrationContext
        from alembic.operations import Operations
        row=self.transaction();row_id=row.id;token=row.provider_invoice_token
        self.db.rollback()
        spec=importlib.util.spec_from_file_location("attempt_migration",
            Path("alembic/versions/20261007_0028_mobile_money_verification_attempt.py"))
        migration=importlib.util.module_from_spec(spec);spec.loader.exec_module(migration)
        with self.engine.begin() as connection:
            with Operations.context(MigrationContext.configure(connection)):
                migration.downgrade()
                self.assertNotIn("last_verification_attempt_at",
                    {item["name"] for item in inspect(connection).get_columns("mobile_money_transactions")})
                migration.upgrade()
                self.assertIn("last_verification_attempt_at",
                    {item["name"] for item in inspect(connection).get_columns("mobile_money_transactions")})
                preserved=connection.execute(text("SELECT provider_invoice_token,status,last_verification_attempt_at "
                    "FROM mobile_money_transactions")).one()
                self.assertEqual(tuple(preserved),(token,"pending",None))
        self.db.expire_all();self.assertEqual(self.db.get(MobileMoneyTransaction,row_id).status,"pending")

    def test_confirmation_with_conflicting_internal_reference_cannot_record_money(self):
        row=self.transaction()
        result=self.result(row,metadata={"amount":1000,"currency":"XOF",
            "custom_data":{"enactspace_transaction_id":str(uuid4())}})
        provider=SimpleNamespace(get_payment_status=AsyncMock(return_value=result))
        with patch.object(mm,"get_payment_provider",return_value=provider):
            self.request("POST",f"/mobile-money/{row.id}/refresh",code=400)
        self.db.expire_all();self.assertIsNone(row.payment_id);self.assertEqual(float(self.account.total_paid),0)
    def test_initiation_amount_limits_reject_explicit_and_computed_overflow(self):
        self.request("POST","/mobile-money/initiate",
            {"finance_item_ids":[str(self.fee.id)],"amount":2147483648},code=422)
        self.fee.amount=2147483648;self.db.commit()
        provider=SimpleNamespace(create_payment=AsyncMock())
        with patch.object(finance.settings,"MOBILE_MONEY_ENABLED",True),patch.object(
            finance,"get_payment_provider",return_value=provider):
            self.request("POST","/mobile-money/initiate",
                {"finance_item_ids":[str(self.fee.id)]},code=400)
        provider.create_payment.assert_not_awaited();self.assertEqual(self.db.query(MobileMoneyTransaction).count(),0)

class PayDunyaConfirmationTests(unittest.TestCase):
    def test_callback_uses_server_confirmation_instead_of_claimed_status(self):
        provider=PayDunyaProvider()
        confirmed=PaymentProviderResult(provider="paydunya",provider_token="invoice-test",status="pending",
            metadata={"amount":1000,"currency":"XOF"})
        with patch.object(provider,"_ensure_configured"),patch.object(settings,"PAYDUNYA_MASTER_KEY","synthetic-test-master"),patch.object(
            provider,"get_payment_status",AsyncMock(return_value=confirmed)) as lookup:
            result=asyncio.run(provider.verify_callback({"hash":hashlib.sha512(b"synthetic-test-master").hexdigest(),
                "invoice":{"token":"invoice-test","total_amount":999},"status":"completed"}))
        self.assertEqual(result.status,"pending");self.assertEqual(result.metadata["amount"],1000)
        lookup.assert_awaited_once_with(provider_token="invoice-test")
    def test_invalid_hash_never_contacts_provider(self):
        provider=PayDunyaProvider()
        with patch.object(provider,"_ensure_configured"),patch.object(provider,"get_payment_status",AsyncMock()) as lookup:
            for bad in ("bad","é"):
                with self.assertRaises(PaymentProviderError):asyncio.run(provider.verify_callback({"hash":bad}))
            lookup.assert_not_awaited()
    def test_failed_status_response_is_rejected(self):
        provider=PayDunyaProvider()
        with patch.object(provider,"_ensure_configured"),patch.object(provider,"_request",AsyncMock(return_value={"response_code":"99","status":"completed"})):
            with self.assertRaises(PaymentProviderError):asyncio.run(provider.get_payment_status(provider_token="test"))
    def test_status_lookup_returns_authoritative_invoice_details(self):
        provider=PayDunyaProvider()
        response={"response_code":"00","status":"completed","invoice":{"token":"token_test","total_amount":1000,"currency":"XOF"}}
        with patch.object(provider,"_ensure_configured"),patch.object(provider,"_request",AsyncMock(return_value=response)) as call:
            result=asyncio.run(provider.get_payment_status(provider_token="token_test"))
        self.assertEqual(result.metadata["amount"],1000);self.assertEqual(result.metadata["currency"],"XOF")
        self.assertEqual(call.await_args.args[1],"/checkout-invoice/confirm/token_test")

if __name__=="__main__":unittest.main()
