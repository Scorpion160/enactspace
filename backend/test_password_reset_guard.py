"""Bounded password-reset attempts; fixtures never send email."""
import os
os.environ.setdefault("DATABASE_URL","sqlite://")
os.environ.setdefault("APP_ENV","test")
os.environ.setdefault("SECRET_KEY","isolated-prelaunch-secret")
os.environ.setdefault("AUTO_CREATE_TABLES","false")
import unittest
from datetime import timedelta
from unittest.mock import patch
from fastapi import HTTPException
from pydantic import ValidationError
from app.api.routes import auth
from app.core.security import hash_password, verify_password
from app.models.user import PasswordResetOtp
from app.schemas.auth import PasswordResetConfirm, PasswordResetRequest
from app.services.session_service import utc_now
import test_profile_photo as photo_fixture

class PasswordResetGuardTests(unittest.TestCase):
    setUp=photo_fixture.ProfilePhotoTests.setUp
    tearDown=photo_fixture.ProfilePhotoTests.tearDown

    def code(self):
        self.user.email="reset@example.org"
        self.db.add(PasswordResetOtp(user_id=self.user.id,otp_hash=hash_password("123456"),
                                    expires_at=utc_now()+timedelta(minutes=15)))
        self.db.commit()

    def confirm(self,otp="000000"):
        return auth.confirm_password_reset(PasswordResetConfirm(email=self.user.email,otp=otp,new_password="New-test-password-2026!"),db=self.db)

    def reject(self,otp="000000"):
        with self.assertRaises(HTTPException) as error:self.confirm(otp)
        self.assertEqual(error.exception.status_code,400)
        self.assertEqual(error.exception.detail,"Code OTP invalide ou expiré")
        self.db.rollback()

    def test_five_wrong_codes_invalidate_challenge_even_across_rollbacks(self):
        self.code()
        for expected in range(1,5):
            self.reject()
            self.assertEqual(self.db.query(PasswordResetOtp).one().failed_attempts,expected)
        self.reject()
        self.assertEqual(self.db.query(PasswordResetOtp).count(),0)
        self.reject("123456")
        self.assertEqual(self.user.password_hash,"not-used")

    def test_valid_code_after_four_failures_resets_password_once(self):
        self.code()
        for _ in range(4):self.reject()
        self.assertTrue(self.confirm("123456")["ok"])
        self.assertTrue(verify_password("New-test-password-2026!",self.user.password_hash))
        self.assertEqual(self.db.query(PasswordResetOtp).count(),0)
        self.reject("123456")

    def test_requesting_new_code_resets_attempt_budget(self):
        self.code();self.reject();self.reject()
        with patch.object(auth.secrets,"randbelow",return_value=654321):
            auth.request_password_reset(PasswordResetRequest(email=self.user.email),db=self.db)
        self.assertEqual(self.db.query(PasswordResetOtp).one().failed_attempts,0)
        self.reject("123456")
        self.assertTrue(self.confirm("654321")["ok"])

    def test_expired_code_is_deleted_without_password_change(self):
        self.code();row=self.db.query(PasswordResetOtp).one()
        row.expires_at=utc_now()-timedelta(seconds=1);self.db.commit()
        self.reject("123456")
        self.assertEqual(self.db.query(PasswordResetOtp).count(),0)

    def test_disabled_user_cannot_reset_password(self):
        self.code();self.user.is_active=False;self.db.commit()
        self.reject("123456")
        self.assertEqual(self.user.password_hash,"not-used")

    def test_only_six_ascii_digits_are_accepted(self):
        for otp in ["12345","1234567","abcdef","１２３４５６","x"*10000]:
            with self.assertRaises(ValidationError):
                PasswordResetConfirm(email="reset@example.org",otp=otp,new_password="New-test-password-2026!")



import test_attachments_lifecycle as attachment_fixture
class RecruitmentPermissionTests(unittest.TestCase):
    setUp=attachment_fixture.AttachmentLifecycleTests.setUp
    tearDown=attachment_fixture.AttachmentLifecycleTests.tearDown
    make_task=attachment_fixture.AttachmentLifecycleTests.make_task
    as_user=attachment_fixture.AttachmentLifecycleTests.as_user
    call=attachment_fixture.AttachmentLifecycleTests.call
    campaign=attachment_fixture.AttachmentLifecycleTests.campaign
    application_payload=attachment_fixture.AttachmentLifecycleTests.application_payload

    def application(self):
        campaign=self.campaign()
        response=self.client.post("/api/recruitment/applications",json=self.application_payload(campaign))
        self.assertEqual(response.status_code,200,response.text)
        return response.json()

    def test_regular_member_cannot_access_candidate_list_detail_or_export(self):
        application=self.application();self.as_user("a")
        for path in ["/applications","/applications/export.csv","/applications/"+application["id"],"/campaigns"]:
            self.assertEqual(self.client.get("/api/recruitment"+path).status_code,403)

    def test_alumni_cannot_keep_recruitment_access_through_old_role_or_membership(self):
        self.campaign()
        self.users["veille"].status="alumni";self.db.commit();self.as_user("veille")
        self.assertEqual(self.client.get("/api/recruitment/applications").status_code,403)
        self.assertEqual(self.client.get("/api/recruitment/campaigns").status_code,403)

    def test_authorized_veille_secretary_and_team_leader_can_read_candidates(self):
        application=self.application()
        for key in ["veille","sg","tl"]:
            self.as_user(key)
            response=self.client.get("/api/recruitment/applications/"+application["id"])
            self.assertEqual(response.status_code,200,response.text)

    def test_another_recruiter_cannot_change_or_delete_someone_elses_review(self):
        application=self.application();self.as_user("veille")
        response=self.client.post("/api/recruitment/reviews",json={"application_id":application["id"],"score":12,"recommendation":"favorable","comment":"Avis de test uniquement."})
        self.assertEqual(response.status_code,200,response.text);identifier=response.json()["id"]
        self.as_user("sg")
        path="/api/recruitment/reviews/"+identifier
        self.assertEqual(self.client.patch(path,json={"score":14}).status_code,403)
        self.assertEqual(self.client.delete(path).status_code,403)
        self.as_user("tl")
        self.assertEqual(self.client.patch(path,json={"score":14}).status_code,200)

if __name__=="__main__":unittest.main()
