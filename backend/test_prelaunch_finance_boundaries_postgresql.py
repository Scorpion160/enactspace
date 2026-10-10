"""Finance flows and competing accounting writes in a disposable PostgreSQL schema."""
import os
import unittest
import threading
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest.mock import patch
from sqlalchemy import text
import test_veille as fixture
import test_veille_postgresql as postgres
from test_prelaunch_finance_boundaries import FinanceBoundaryTests as _FinanceBoundaryTests
from app.models.finance import ClubTransaction, Payment, FinancialAccount

@unittest.skipUnless(os.getenv("VEILLE_TEST_POSTGRESQL_URL"),"Dedicated PostgreSQL test database required")
class FinancePostgreSQLTests(_FinanceBoundaryTests):
    setUpClass=classmethod(postgres.VeillePostgreSQLTests.setUpClass.__func__)
    tearDownClass=classmethod(postgres.VeillePostgreSQLTests.tearDownClass.__func__)
    def setUp(self):
        quote=self.pg_engine.dialect.identifier_preparer.quote
        tables=[quote(self.schema)+"."+quote(table.name) for table in fixture.Base.metadata.tables.values()]
        with self.pg_engine.begin() as connection:
            connection.execute(text("TRUNCATE TABLE "+",".join(tables)+" RESTART IDENTITY CASCADE"))
        with patch.object(fixture,"create_engine",return_value=self.pg_engine),patch.object(
            fixture,"event",SimpleNamespace(listens_for=lambda *_:lambda function:function)
        ),patch.object(fixture.Base.metadata,"create_all"):
            super().setUp()
    def tearDown(self):
        with patch.object(self.pg_engine,"dispose"):super().tearDown()
    def race(self,path,body=None):
        barrier=threading.Barrier(2)
        def submit(_):
            barrier.wait(timeout=10)
            return self.client.post("/api/finance"+path,json=body)
        with ThreadPoolExecutor(max_workers=2) as executor:return list(executor.map(submit,range(2)))
    def test_concurrent_fee_cancellation_reduces_balance_once(self):
        self.as_user("lead")
        responses=self.race(f"/fees/{self.fee.id}/cancel",{"reason":"Correction du montant"})
        self.assertEqual([r.status_code for r in responses],[200,200],[r.text for r in responses])
        self.db.expire_all();self.assertEqual(float(self.account.balance_due),2000)
        self.assertEqual(self.fee.description.count("Annulation:"),1)
    def test_concurrent_payment_validation_records_income_once(self):
        self.as_user("lead")
        responses=self.race(f"/payments/{self.payment.id}/validate")
        self.assertEqual([r.status_code for r in responses],[200,200],[r.text for r in responses])
        self.db.expire_all();self.assertEqual(float(self.account.total_paid),1000)
        self.assertEqual(self.db.query(ClubTransaction).filter_by(payment_id=self.payment.id).count(),1)

    def race_requests(self, requests):
        barrier=threading.Barrier(len(requests))
        def submit(item):
            method,path,body=item;barrier.wait(timeout=10)
            return self.client.request(method,"/api/finance"+path,json=body)
        with ThreadPoolExecutor(max_workers=len(requests)) as executor:return list(executor.map(submit,requests))
    def test_concurrent_reference_declarations_across_members_accept_once(self):
        self.as_user("tl")
        responses=self.race_requests([("POST","/payments",{"user_id":str(self.users[who].id),
            "method":"wave","reference":ref,"amount":1000})
            for who,ref in (("a","  Shared-Reference  "),("b","shared-reference"))])
        self.assertEqual(sorted(r.status_code for r in responses),[200,409],[r.text for r in responses])
        self.assertEqual(self.db.query(Payment).filter(Payment.method=="wave").count(),1)
    def test_concurrent_identical_checksums_on_distinct_files_accept_once(self):
        self.as_user("tl")
        proofs=[self.proof(checksum="same-global-checksum",owner="tl",bound=False) for _ in range(2)]
        responses=self.race_requests([("POST","/payments",{"user_id":str(self.users[who].id),
            "method":"wave","proof_file_id":str(proof.id),"amount":1000})
            for who,proof in zip(("a","b"),proofs)])
        self.assertEqual(sorted(r.status_code for r in responses),[200,409],[r.text for r in responses])
        self.assertEqual(self.db.query(Payment).filter(Payment.method=="wave").count(),1)
    def test_concurrent_first_account_creation_returns_single_account(self):
        self.as_user("tl");target=self.users["b"].id
        responses=self.race_requests([("GET",f"/accounts/user/{target}",None)]*2)
        self.assertEqual([r.status_code for r in responses],[200,200],[r.text for r in responses])
        self.assertEqual(responses[0].json()["id"],responses[1].json()["id"])
        self.assertEqual(self.db.query(FinancialAccount).filter_by(user_id=target).count(),1)

# Avoid discovery of the imported portable base class in this module.
del _FinanceBoundaryTests
if __name__=="__main__":unittest.main()
