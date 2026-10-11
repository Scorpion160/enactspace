"""Finance authority, own history and cancellation on isolated HTTP data."""
import unittest
from unittest.mock import patch
from uuid import uuid4
from fastapi import HTTPException
import test_veille as fixture
from app.api.routes import finance, files
from app.api.deps import can_manage_finance
from app.models.role import Role, UserRole
from app.models.finance import Fee, FinancialAccount, Payment
from app.models.mobile_money import MobileMoneyTransaction
from app.models.stored_file import StoredFile
from app.services.mobile_money_service import can_access_transaction
from app.api.routes.files import ensure_file_access

class FinanceBoundaryTests(unittest.TestCase):
    make_task = fixture.VeilleFlowTests.make_task
    as_user = fixture.VeilleFlowTests.as_user
    def setUp(self):
        fixture.VeilleFlowTests.setUp(self)
        self.client.app.include_router(finance.router, prefix="/api")
        self.client.app.include_router(files.router, prefix="/api")
        role=Role(name="financier");self.db.add(role);self.db.flush()
        self.db.add(UserRole(user_id=self.users["lead"].id,role_id=role.id))
        self.payment=Payment(user_id=self.users["a"].id,amount=1000,method="especes",status="pending")
        self.fee=Fee(user_id=self.users["a"].id,type="membership_fee",label="Cotisation",
                     amount=1000,amount_paid=0,status="unpaid")
        self.account=FinancialAccount(user_id=self.users["a"].id,balance_due=3000,total_paid=0)
        self.db.add_all([self.payment,self.fee,self.account]);self.db.commit()
        self.patches=[patch.object(finance,"notify_user"),patch.object(finance,"notify_users")]
        for item in self.patches:item.start()
    def tearDown(self):
        for item in self.patches:item.stop()
        fixture.VeilleFlowTests.tearDown(self)
    def alumni(self, name):
        self.users[name].status="alumni";self.users[name].profile_type="alumni"
        self.db.commit();self.as_user(name)
    def request(self,method,path,body=None,code=200):
        response=self.client.request(method,"/api/finance"+path,json=body)
        self.assertEqual(response.status_code,code,response.text)
        return response
    def test_alumni_legacy_admin_leader_financier_cannot_read_management(self):
        for who in ("admin","tl","lead"):
            self.alumni(who)
            for path in ("/fees","/accounts","/payments","/stats","/transactions",
                         "/export/fees.csv","/export/payments.csv","/mobile-money/admin/summary"):
                with self.subTest(who=who,path=path):self.request("GET",path,code=403)
    def test_alumni_legacy_roles_cannot_validate_reject_or_cancel_other_payment(self):
        for who in ("admin","tl","lead"):
            self.alumni(who)
            self.request("POST",f"/payments/{self.payment.id}/validate",code=403)
            self.request("POST",f"/payments/{self.payment.id}/reject",{"reason":"A vérifier"},403)
            self.request("POST",f"/payments/{self.payment.id}/cancel",code=403)
        self.db.expire_all();self.assertEqual(self.payment.status,"pending")
    def test_alumni_cannot_create_fee_or_manual_payment_for_another_member(self):
        self.alumni("tl")
        self.request("POST","/fees",{"user_id":str(self.users["b"].id),"type":"contribution",
            "label":"Contribution","amount":1000},403)
        self.request("POST","/payments",{"user_id":str(self.users["b"].id),"method":"manuel","amount":1000},403)
    def test_alumni_keeps_own_fees_payments_account_and_stats(self):
        self.alumni("a")
        self.assertEqual(len(self.request("GET","/fees/me").json()),1)
        self.assertEqual(len(self.request("GET","/payments/me").json()),1)
        self.assertEqual(self.request("GET","/accounts/me").json()["balance_due"],3000)
        self.request("GET","/stats/me")
    def test_alumni_can_declare_and_cancel_own_cash_payment(self):
        self.alumni("a")
        result=self.request("POST","/payments",{"user_id":str(self.users["a"].id),
            "method":"especes","amount":500}).json()
        self.assertFalse(result["can_validate"]);self.assertTrue(result["can_cancel"])
        self.request("POST",f"/payments/{result['id']}/cancel")
    def test_alumni_legacy_admin_cannot_read_other_receipt(self):
        self.payment.status="validated";self.db.commit();self.alumni("admin")
        self.request("GET",f"/payments/{self.payment.id}/receipt",code=403)
        self.alumni("a");self.request("GET",f"/payments/{self.payment.id}/receipt")
    def test_current_managers_keep_access_and_member_cannot_manage(self):
        for who in ("admin","tl","lead"):
            self.as_user(who);self.request("GET","/payments");self.request("GET","/stats")
        self.as_user("b");self.request("GET","/payments",code=403)
    def test_financier_cannot_review_own_payment(self):
        self.payment.user_id=self.users["lead"].id;self.db.commit();self.as_user("lead")
        self.request("POST",f"/payments/{self.payment.id}/validate",code=403)
        self.request("POST",f"/payments/{self.payment.id}/reject",{"reason":"A vérifier"},403)
    def test_finance_notifications_exclude_alumni_disabled_and_unverified(self):
        self.users["tl"].status="alumni";self.users["admin"].is_active=False
        self.db.commit();self.assertEqual(finance.finance_manager_ids(self.db),[self.users["lead"].id])
        self.users["lead"].email_verified=False;self.db.commit()
        self.assertEqual(finance.finance_manager_ids(self.db),[])
        self.assertFalse(can_manage_finance(self.db,self.users["lead"]))
    def test_mobile_money_and_private_proof_reject_alumni_legacy_authority(self):
        transaction=MobileMoneyTransaction(member_id=self.users["a"].id,provider="paydunya",
            idempotency_key=uuid4().hex,amount=1000,currency="XOF",status="pending")
        proof=StoredFile(original_filename="recu.pdf",stored_filename="owned.pdf",
            storage_path="owned.pdf",mime_type="application/pdf",file_size=1,checksum="fake",
            uploaded_by_id=self.users["a"].id,visibility="private",storage_scope="finance",
            entity_type="payment",entity_id=self.payment.id,is_temporary=False)
        self.db.add_all([transaction,proof]);self.db.flush();self.payment.proof_file_id=proof.id;self.db.commit()
        self.alumni("tl")
        self.assertFalse(can_access_transaction(self.db,self.acting,transaction))
        with self.assertRaises(HTTPException) as error:ensure_file_access(self.db,proof,self.acting)
        self.assertEqual(error.exception.status_code,403)
        self.alumni("a");self.assertTrue(can_access_transaction(self.db,self.acting,transaction))
        ensure_file_access(self.db,proof,self.acting)
    def test_repeated_fee_cancellation_does_not_reduce_other_debts(self):
        self.as_user("lead")
        path=f"/fees/{self.fee.id}/cancel"
        self.request("POST",path,{"reason":"Montant corrigé"})
        self.request("POST",path,{"reason":"Nouvel essai"})
        self.db.expire_all();self.assertEqual(float(self.account.balance_due),2000)
        self.assertEqual(self.fee.description.count("Annulation:"),1)
    def test_invalid_route_ids_return_validation_errors(self):
        self.as_user("tl")
        for path in ("/fees/user/bad","/accounts/user/bad","/payments/user/bad",
                     "/payments/bad/receipt","/mobile-money/bad"):
            self.request("GET",path,code=422)
        self.request("POST","/fees/bad/cancel",{"reason":"Erreur"},422)
        with self.assertRaises(HTTPException) as error:finance.get_payment_or_404(self.db,"bad")
        self.assertEqual(error.exception.status_code,404)

    def proof(self, checksum="test-checksum", owner="a", bound=True):
        row=StoredFile(original_filename="recu.pdf",stored_filename="test.pdf",
            storage_path="test.pdf",mime_type="application/pdf",file_size=1,checksum=checksum,
            uploaded_by_id=self.users[owner].id,visibility="private",storage_scope="finance",
            entity_type="payment" if bound else None,entity_id=self.payment.id if bound else None,
            is_temporary=not bound)
        self.db.add(row);self.db.flush()
        if bound:self.payment.proof_file_id=row.id
        self.db.commit();return row

    def test_bound_proof_cannot_be_deleted_by_owner_or_manager(self):
        proof=self.proof()
        for who in ("a","lead","tl","admin"):
            self.as_user(who)
            response=self.client.delete(f"/api/files/{proof.id}")
            self.assertEqual(response.status_code,409,response.text)
        self.db.expire_all();self.assertIsNotNone(self.db.get(StoredFile,proof.id))
        self.assertEqual(self.payment.proof_file_id,proof.id)
    def test_payment_owner_reads_proof_uploaded_by_manager_but_secretary_cannot(self):
        proof=self.proof(owner="lead")
        for who in ("a","lead","tl","admin"):
            self.as_user(who);self.assertEqual(self.client.get(f"/api/files/{proof.id}").status_code,200)
        self.as_user("sg");self.assertEqual(self.client.get(f"/api/files/{proof.id}").status_code,403)
        self.alumni("a");self.assertEqual(self.client.get(f"/api/files/{proof.id}").status_code,200)
    def test_legacy_proof_without_entity_binding_still_protected(self):
        proof=self.proof();proof.entity_type=None;proof.entity_id=None;proof.visibility="internal"
        self.db.commit();self.as_user("b")
        self.assertEqual(self.client.get(f"/api/files/{proof.id}").status_code,403)
        self.as_user("a");self.assertEqual(self.client.delete(f"/api/files/{proof.id}").status_code,409)
    def test_forged_payment_binding_does_not_grant_file_access(self):
        proof=self.proof(bound=False);proof.entity_type="payment";proof.entity_id=self.payment.id
        self.db.commit();self.as_user("a")
        self.assertEqual(self.client.get(f"/api/files/{proof.id}").status_code,403)
    def test_exports_escape_formula_text_and_keep_numeric_amounts(self):
        import csv,io
        self.fee.label="  =1+1";self.payment.reference="@SUM(1,2)";self.payment.rejection_reason="\t=2+2"
        self.db.commit();self.as_user("lead")
        fees=list(csv.reader(io.StringIO(self.request("GET","/export/fees.csv").text)))
        payments=list(csv.reader(io.StringIO(self.request("GET","/export/payments.csv").text)))
        self.assertEqual(fees[1][3],"'  =1+1");self.assertEqual(float(fees[1][4]),1000)
        self.assertEqual(payments[1][6],"'@SUM(1,2)");self.assertEqual(payments[1][9],"'\t=2+2")
    def test_invalid_amounts_rejected_before_writes(self):
        from pydantic import ValidationError
        from app.schemas.finance import FeeCreate,FeeBulkCreate,PaymentCreate,ClubTransactionCreate
        for value in (float("nan"),float("inf"),float("-inf"),0,-1,0.001,1.234,10000000000):
            for cls,kwargs in (
                (FeeCreate,{"user_id":self.users["a"].id,"type":"contribution","label":"Test"}),
                (FeeBulkCreate,{"label":"Test"}),
                (PaymentCreate,{"user_id":self.users["a"].id,"method":"especes"}),
                (ClubTransactionCreate,{"type":"income","label":"Test"})):
                with self.subTest(value=value,cls=cls.__name__),self.assertRaises(ValidationError):
                    cls(amount=value,**kwargs)
        self.as_user("a");self.request("POST","/payments",{"user_id":str(self.users["a"].id),
            "method":"especes","amount":0.001},422)
    def test_unknown_target_member_does_not_create_payment_or_account(self):
        self.as_user("tl");unknown=uuid4()
        self.request("POST","/payments",{"user_id":str(unknown),"method":"especes","amount":1000},404)
        self.request("GET",f"/accounts/user/{unknown}",code=404)
        self.assertEqual(self.db.query(Payment).filter_by(user_id=unknown).count(),0)
        self.assertEqual(self.db.query(FinancialAccount).filter_by(user_id=unknown).count(),0)

    def test_declared_proof_becomes_permanent_without_expiration(self):
        from datetime import timedelta
        from app.core.time import utc_now
        proof=self.proof(bound=False)
        proof.is_ephemeral=True;proof.ephemeral_duration="24h";proof.expires_at=utc_now()+timedelta(hours=1)
        self.db.commit();self.as_user("a")
        self.request("POST","/payments",{"user_id":str(self.users["a"].id),"method":"wave",
            "proof_file_id":str(proof.id),"amount":1000})
        self.db.expire_all()
        self.assertFalse(proof.is_temporary);self.assertFalse(proof.is_ephemeral)
        self.assertIsNone(proof.expires_at);self.assertIsNone(proof.ephemeral_duration)
    def test_legacy_expired_bound_proof_remains_readable_and_cleanup_skips_it(self):
        from datetime import timedelta
        from app.core.time import utc_now
        from app.services.file_storage_service import cleanup_expired_files
        proof=self.proof()
        proof.is_temporary=True;proof.expires_at=utc_now()-timedelta(days=1)
        self.db.commit();self.as_user("a")
        self.assertEqual(self.client.get(f"/api/files/{proof.id}").status_code,200)
        result=cleanup_expired_files(self.db,dry_run=True)
        self.assertEqual(result["deleted"],0);self.assertEqual(result["skipped"],1)
        self.as_user("b");self.assertEqual(self.client.get(f"/api/files/{proof.id}").status_code,403)

if __name__=="__main__":unittest.main()
