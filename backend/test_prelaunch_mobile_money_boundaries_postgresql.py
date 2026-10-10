"""Competing Mobile Money operations in an explicitly disposable PostgreSQL schema."""
import os,unittest,threading
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest.mock import patch,AsyncMock
from sqlalchemy import text
import test_veille as fixture
import test_veille_postgresql as postgres
import test_prelaunch_mobile_money_boundaries as mobile_fixture
from app.api.routes import finance,payments
from app.models.mobile_money import MobileMoneyTransaction
from app.models.finance import ClubTransaction
from app.services.payments import PaymentProviderResult

@unittest.skipUnless(os.getenv("VEILLE_TEST_POSTGRESQL_URL"),"Dedicated PostgreSQL test database required")
class MobileMoneyPostgreSQLTests(mobile_fixture.MobileMoneyBoundaryTests):
    setUpClass=classmethod(postgres.VeillePostgreSQLTests.setUpClass.__func__)
    tearDownClass=classmethod(postgres.VeillePostgreSQLTests.tearDownClass.__func__)
    def setUp(self):
        quote=self.pg_engine.dialect.identifier_preparer.quote
        tables=[quote(self.schema)+"."+quote(table.name) for table in fixture.Base.metadata.tables.values()]
        with self.pg_engine.begin() as conn:conn.execute(text("TRUNCATE TABLE "+",".join(tables)+" RESTART IDENTITY CASCADE"))
        with patch.object(fixture,"create_engine",return_value=self.pg_engine),patch.object(
            fixture,"event",SimpleNamespace(listens_for=lambda *_:lambda function:function)
        ),patch.object(fixture.Base.metadata,"create_all"):super().setUp()
    def tearDown(self):
        with patch.object(self.pg_engine,"dispose"):super().tearDown()
    def race(self,path,body):
        barrier=threading.Barrier(2)
        def submit(_):
            barrier.wait(timeout=10);return self.client.post(path,json=body)
        with ThreadPoolExecutor(max_workers=2) as executor:return list(executor.map(submit,range(2)))
    def test_concurrent_initiation_calls_provider_once(self):
        calls=[]
        async def create(request):
            calls.append(request)
            return PaymentProviderResult(provider="paydunya",status="pending",
                provider_token="invoice_"+request.transaction_id,checkout_url="https://provider.example.test/pay")
        with patch.object(finance.settings,"MOBILE_MONEY_ENABLED",True),patch.object(
            finance.settings,"MOBILE_MONEY_PROVIDER","paydunya"),patch.object(
            finance,"get_payment_provider",return_value=SimpleNamespace(create_payment=create)):
            responses=self.race("/api/finance/mobile-money/initiate",{"finance_item_ids":[str(self.fee.id)],"amount":500})
        self.assertEqual([r.status_code for r in responses],[200,200],[r.text for r in responses])
        self.assertEqual(responses[0].json()["transaction_id"],responses[1].json()["transaction_id"])
        self.assertEqual(len(calls),1);self.assertEqual(self.db.query(MobileMoneyTransaction).count(),1)
    def test_concurrent_callbacks_record_income_once(self):
        row=self.transaction()
        with patch.object(payments,"get_payment_provider",return_value=SimpleNamespace(
            verify_callback=AsyncMock(return_value=self.result(row)))):
            responses=self.race("/api/payments/paydunya/ipn",{"synthetic":True})
        self.assertEqual([r.status_code for r in responses],[200,200],[r.text for r in responses])
        self.db.expire_all();self.assertEqual(float(self.account.total_paid),1000)
        self.assertEqual(self.db.query(ClubTransaction).count(),1)
        self.assertEqual(sorted(bool(r.json().get("duplicate")) for r in responses),[False,True])

if __name__=="__main__":unittest.main()
