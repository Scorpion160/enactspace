"""First-login HTTP and credential boundaries; synthetic records, no SMTP."""
import unittest
from datetime import timedelta
from unittest.mock import patch
from fastapi import FastAPI,Depends
from fastapi.testclient import TestClient
from sqlalchemy import create_engine,event,text
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool
import app.models.base
from app.db.database import Base,get_db
from app.api.deps import get_current_active_validated_user
from app.api.routes import first_access,auth,users
from app.models.user import User
from app.models.role import Role,UserRole
from app.models.first_access import ActivationChallenge
from app.models.account import AuthSession
from app.models.alumni import AlumniProfile
from app.models.audit import AuditLog
from app.core.security import hash_password,verify_password,create_access_token
from app.core.time import utc_now
from app.services import first_access as service
from app.services.request_rate_limit import protect_public_request,POLICIES

class FirstAccessTests(unittest.TestCase):
    def make_engine(self):
        return create_engine("sqlite://",connect_args={"check_same_thread":False},poolclass=StaticPool)
    def setUp(self):
        self.engine=self.make_engine()
        if self.engine.dialect.name=="sqlite":
            @event.listens_for(self.engine,"connect")
            def foreign_keys(conn,_):conn.execute("PRAGMA foreign_keys=ON")
        Base.metadata.create_all(self.engine)
        self.db=Session(self.engine,expire_on_commit=False)
        self.user=User(first_name="Synthetic",last_name="Member",email="member@example.com",
            username="synthetic.member",password_hash=hash_password("Original password 123"),status="active",
            is_active=True,email_verified=False,profile_type="enacteur",credential_setup_required=True,onboarding_required=True)
        self.sg=User(first_name="Synthetic",last_name="Secretary",email="sg@example.com",username="synthetic.sg",
            password_hash="unused",status="active",is_active=True,email_verified=True,profile_type="enacteur")
        self.other=User(first_name="Synthetic",last_name="Other",email="other@example.com",username="synthetic.other",
            password_hash="unused",status="active",is_active=True,email_verified=True,profile_type="enacteur")
        self.db.add_all([self.user,self.sg,self.other]);self.db.flush()
        role=Role(name="secretaire_generale");self.db.add(role);self.db.flush()
        self.db.add(UserRole(user_id=self.sg.id,role_id=role.id));self.db.commit()
        app=FastAPI()
        from fastapi.exceptions import RequestValidationError
        from app.core.http_errors import safe_validation_error
        app.add_exception_handler(RequestValidationError,safe_validation_error)
        for router in (first_access.public_router,first_access.router,auth.router,users.router):app.include_router(router,prefix="/api")
        @app.get("/api/activities")
        def activities(user=Depends(get_current_active_validated_user)):return {"accessible":True}
        @app.get("/api/legal/status/me")
        def legal(user=Depends(get_current_active_validated_user)):return {"accessible":True}
        def test_db():
            with Session(self.engine,expire_on_commit=False) as db:yield db
        app.dependency_overrides[get_db]=test_db
        app.dependency_overrides[protect_public_request]=lambda:None
        self.client=TestClient(app);self.mail=[]
        self.patches=[patch.object(service.secrets,"randbelow",return_value=12345678),
            patch.object(service,"enqueue_email_delivery",side_effect=lambda db,**kw:self.mail.append(kw))]
        for item in self.patches:item.start()
    def tearDown(self):
        for item in self.patches:item.stop()
        self.client.close();self.db.close()
        if self.engine.dialect.name=="postgresql":
            assert self.engine.url.database.startswith("enactspace_pr2b_test_")
            # The existing attendance/fee FK cycle prevents metadata.drop_all.
            with self.engine.begin() as conn:
                names=','.join('"'+name+'"' for name in Base.metadata.tables)
                conn.execute(text("TRUNCATE "+names+" RESTART IDENTITY CASCADE"))
        self.engine.dispose()
    def call(self,method,path,body=None,code=200,actor=None):
        headers={"Authorization":"Bearer "+create_access_token(str(actor.id))} if actor else {}
        response=self.client.request(method,"/api/"+path,json=body,headers=headers)
        self.assertEqual(response.status_code,code,response.text)
        return response
    def request(self,identifier=None):
        return self.call("POST","auth/activation/request",{"identifier":identifier or self.user.email})
    def confirm(self,code="12345678",password="My own password 2026",expected=200):
        return self.call("POST","auth/activation/confirm",{"identifier":self.user.username,"code":code,"new_password":password},expected)
    def profile(self,**values):
        body=dict(first_name="Synthetic",last_name="Member",phone="+221 770000000",gender="femme",
            enactus_join_year=2020,department="Gestion",cursus="DUT",study_level="DUT2")
        body.update(values);return body
    def prepare_signed(self):
        self.user.credential_setup_required=False;self.user.email_verified=True;self.db.commit()
    def test_generic_response_does_not_disclose_account_or_code(self):
        existing=self.request().json();missing=self.request("missing@example.com").json()
        self.assertEqual(existing,missing);self.assertEqual(set(existing),{"message"})
        self.assertEqual(len(self.mail),1)
        self.db.expire_all();challenge=self.db.query(ActivationChallenge).one()
        self.assertNotEqual(challenge.code_hash,"12345678");self.assertEqual(len(challenge.code_hash),64)
        self.assertNotIn("Original password",self.mail[0]["text_body"])
    def test_username_and_case_insensitive_email_both_resolve(self):
        self.request(self.user.username.upper())
        self.assertEqual(len(self.mail),1)
        self.confirm();self.db.expire_all()
        self.assertTrue(self.user.email_verified);self.assertFalse(self.user.credential_setup_required)
    def test_code_is_single_use_and_does_not_auto_login(self):
        self.request();self.assertNotIn("access_token",self.confirm().json())
        self.confirm(expected=400);self.assertEqual(len(self.mail),2)
        self.db.expire_all();self.assertEqual(self.db.query(ActivationChallenge).count(),0)
        self.assertIsNotNone(self.user.credential_activated_at)
    def test_password_is_exact_including_outer_spaces(self):
        value="  My own password 2026  ";self.request();self.confirm(password=value)
        self.db.expire_all();self.assertTrue(verify_password(value,self.user.password_hash))
        self.assertFalse(verify_password(value.strip(),self.user.password_hash))
        self.assertNotIn(value,self.mail[-1]["text_body"])
    def test_short_whitespace_and_overlong_utf8_passwords_rejected(self):
        self.request()
        for password in ("too short"," "*16,"é"*40):
            self.confirm(password=password,expected=422)
        self.db.expire_all();self.assertTrue(self.user.credential_setup_required)
    def test_five_failed_codes_invalidate_challenge(self):
        self.request()
        for _ in range(5):self.confirm(code="00000000",expected=400)
        self.confirm(expected=400);self.db.expire_all()
        self.assertEqual(self.db.query(ActivationChallenge).count(),0)
        self.assertTrue(self.user.credential_setup_required)
    def test_expired_code_rejected(self):
        self.request();row=self.db.query(ActivationChallenge).one();row.expires_at=utc_now()-timedelta(seconds=1);self.db.commit()
        self.confirm(expected=400)
    def test_changed_email_invalidates_code(self):
        self.request();self.user.email="new@example.com";self.db.commit();self.confirm(expected=400)
    def test_resend_cooldown_prevents_duplicate_email(self):
        self.request();self.request();self.assertEqual(len(self.mail),1)
        row=self.db.query(ActivationChallenge).one();row.created_at=utc_now()-timedelta(seconds=61);self.db.commit()
        self.request();self.assertEqual(len(self.mail),2)
    def test_pending_suspended_rejected_and_inconsistent_accounts_cannot_activate(self):
        for status,kind in (("pending","enacteur"),("suspended","enacteur"),("rejected","enacteur"),("active","alumni")):
            self.user.status=status;self.user.profile_type=kind;self.db.commit();self.request()
        self.assertEqual(self.mail,[])
        self.confirm(expected=400)
    def test_bootstrap_administrator_cannot_use_activation(self):
        role=Role(name="administrateur");self.db.add(role);self.db.flush()
        self.db.add(UserRole(user_id=self.user.id,role_id=role.id));self.db.commit()
        self.request();self.assertEqual(self.mail,[])
        self.call("POST",f"first-access/members/{self.user.id}/invite",{},409,actor=self.sg)
    def test_existing_used_account_keeps_credentials(self):
        self.prepare_signed()
        row=AuthSession(user_id=self.user.id,refresh_token_hash="a"*64,expires_at=utc_now()+timedelta(days=1))
        self.db.add(row);self.db.commit();self.request();self.assertEqual(self.mail,[])
        self.call("POST",f"first-access/members/{self.user.id}/invite",{},409,actor=self.sg)
    def test_login_by_email_and_username_after_activation(self):
        self.request();self.confirm()
        for identifier in (self.user.email,self.user.username):
            result=self.call("POST","auth/login",{"identifier":identifier,"password":"My own password 2026"}).json()
            self.assertIn("access_token",result)
        self.db.expire_all();self.assertEqual(self.db.query(AuthSession).count(),2)
    def test_old_password_cannot_login_before_activation(self):
        self.call("POST","auth/login",{"identifier":self.user.email,"password":"Original password 123"},403)
    def test_private_access_blocked_until_profile_complete(self):
        self.prepare_signed()
        self.call("GET","activities",code=403,actor=self.user)
        data=self.call("GET","users/me",actor=self.user).json();self.assertTrue(data["onboarding_required"])
        self.call("GET","legal/status/me",actor=self.user)
        self.call("POST","first-access/me/complete",self.profile(),actor=self.user)
        self.call("GET","activities",actor=self.user)
        self.db.expire_all();self.assertFalse(self.user.onboarding_required)
        self.assertIsNotNone(self.user.onboarding_completed_at);self.assertEqual(self.user.profile_type,"enactrice")
    def test_profile_resumes_with_known_information(self):
        self.prepare_signed();self.user.phone="+221 770000000";self.user.enactus_join_year=2020;self.db.commit()
        data=self.call("GET","first-access/me",actor=self.user).json()
        self.assertEqual((data["phone"],data["enactus_join_year"]),(self.user.phone,2020))
        self.call("GET","activities",code=403,actor=self.user)
    def test_invalid_academic_path_and_missing_required_fields_are_rejected(self):
        self.prepare_signed()
        for data in (self.profile(cursus="DIC"),self.profile(study_level="DIC3"),self.profile(department="Unknown"),self.profile(phone="abc"),self.profile(phone="(())()"),self.profile(enactus_join_year=1899)):
            self.call("POST","first-access/me/complete",data,422,actor=self.user)
        self.call("POST","first-access/me/complete",{},422,actor=self.user)
        self.db.expire_all();self.assertTrue(self.user.onboarding_required)
    def test_completion_is_idempotent_and_does_not_overwrite_with_replay(self):
        self.prepare_signed();self.call("POST","first-access/me/complete",self.profile(),actor=self.user)
        self.call("POST","first-access/me/complete",self.profile(first_name="Replay"),actor=self.user)
        self.db.expire_all();self.assertEqual(self.user.first_name,"Synthetic")
        self.assertEqual(self.db.query(AuditLog).filter_by(action="first_access_completed").count(),1)
    def test_alumni_has_adapted_profile_and_keeps_history(self):
        self.prepare_signed();self.user.status="alumni";self.user.profile_type="alumni";self.db.commit()
        self.call("POST","first-access/me/complete",self.profile(cursus=None,study_level=None),422,actor=self.user)
        self.call("POST","first-access/me/complete",self.profile(cursus=None,study_level=None,graduation_year=2024),actor=self.user)
        self.db.expire_all();profile=self.db.query(AlumniProfile).filter_by(user_id=self.user.id).one()
        self.assertEqual((profile.graduation_year,profile.enactus_join_year),(2024,2020))
        self.assertEqual(self.user.profile_type,"alumni")
    def test_manager_can_correct_missing_email_then_invite(self):
        self.user.email="imported@enactspace.local";self.db.commit()
        self.request();self.assertEqual(self.mail,[])
        data=self.call("GET","first-access/members",actor=self.sg).json()
        self.assertEqual(next(row for row in data if row["id"]==str(self.user.id))["state"],"contact_missing")
        self.call("PATCH",f"first-access/members/{self.user.id}/contact",{"email":"verified@example.com"},actor=self.sg)
        self.call("POST",f"first-access/members/{self.user.id}/invite",{},actor=self.sg)
        self.assertEqual(self.mail[0]["recipient_email"],"verified@example.com")
    def test_regular_member_cannot_manage_contacts_or_invite(self):
        self.call("GET","first-access/members",code=403,actor=self.other)
        self.call("PATCH",f"first-access/members/{self.user.id}/contact",{"email":"new@example.com"},403,actor=self.other)
        self.call("POST",f"first-access/members/{self.user.id}/invite",{},403,actor=self.other)
    def test_contact_collision_refused_and_old_contact_preserved(self):
        self.call("PATCH",f"first-access/members/{self.user.id}/contact",{"email":self.other.email},409,actor=self.sg)
        self.db.expire_all();self.assertEqual(self.user.email,"member@example.com")
    def test_used_account_cannot_be_rebound_to_another_email(self):
        self.request();self.confirm()
        self.call("PATCH",f"first-access/members/{self.user.id}/contact",{"email":"new@example.com"},409,actor=self.sg)
    def test_alumni_secretary_legacy_role_is_not_authorized(self):
        self.sg.status="alumni";self.sg.profile_type="alumni";self.db.commit()
        self.call("GET","first-access/members",code=403,actor=self.sg)
        self.call("POST",f"first-access/members/{self.user.id}/invite",{},403,actor=self.sg)
    def test_admin_created_profile_does_not_require_manager_chosen_password(self):
        response=self.call("POST","users/",{"first_name":"New","last_name":"Member","email":"created@example.com"},actor=self.sg).json()
        self.assertTrue(response["credential_setup_required"]);self.assertTrue(response["onboarding_required"])
        self.call("POST",f"users/{response['id']}/approve",{},actor=self.sg)
        self.assertTrue(any(mail["recipient_email"]=="created@example.com" for mail in self.mail))
    def test_activation_email_queue_remains_redirected_in_test_mode(self):
        from app.core.config import settings
        from app.models.email_delivery import EmailDelivery
        from app.services.email_delivery_service import enqueue_email_delivery
        with patch.object(service,"enqueue_email_delivery",wraps=enqueue_email_delivery), \
             patch.object(settings,"EMAIL_ENABLED",True), \
             patch.object(settings,"EMAIL_RESTRICT_TO_TEST_RECIPIENT",True), \
             patch.object(settings,"EMAIL_TEST_RECIPIENT","dioppylsci@gmail.com"), \
             patch.object(settings,"SMTP_HOST","smtp.example.test"):
            self.request()
        self.db.expire_all();delivery=self.db.query(EmailDelivery).one()
        self.assertEqual(delivery.recipient_email,"dioppylsci@gmail.com")
        self.assertNotIn("Original password",delivery.text_body)

    def current_year(self):
        from datetime import date
        from app.models.season import Season
        row=Season(name="2026–2027",start_date=date(2026,10,1),is_current=True,archived=False)
        self.db.add(row);self.db.commit();return row
    def test_onboarding_confirms_current_academic_year_once(self):
        from app.models.academic import UserAcademicHistory
        self.prepare_signed();year=self.current_year()
        status=self.call("GET","first-access/me",actor=self.user).json()
        self.assertEqual(status["academic_year_id"],str(year.id))
        payload=self.profile(academic_year_id=str(year.id))
        self.call("POST","first-access/me/complete",payload,actor=self.user)
        self.call("POST","first-access/me/complete",payload,actor=self.user)
        self.db.expire_all()
        self.assertEqual(self.user.academic_confirmed_season_id,year.id)
        self.assertEqual(self.db.query(UserAcademicHistory).filter_by(user_id=self.user.id,season_id=year.id).count(),1)
    def test_existing_academic_confirmation_is_reused_without_rewriting(self):
        from app.models.academic import UserAcademicHistory
        self.prepare_signed();year=self.current_year();moment=utc_now()-timedelta(days=7)
        history=UserAcademicHistory(user_id=self.user.id,season_id=year.id,department="Gestion",cursus="DUT",study_level="DUT2",confirmed_at=moment)
        self.db.add(history);self.db.commit()
        status=self.call("GET","first-access/me",actor=self.user).json()
        self.assertTrue(status["academic_year_confirmed"]);self.assertEqual(status["cursus"],"DUT")
        self.call("POST","first-access/me/complete",self.profile(academic_year_id=str(year.id),study_level="DUT1"),422,actor=self.user)
        self.call("POST","first-access/me/complete",self.profile(academic_year_id=str(year.id)),actor=self.user)
        self.db.expire_all();self.assertEqual(history.confirmed_at,moment)
        self.assertEqual(self.user.academic_confirmed_at,moment)
    def test_changed_year_draft_is_rejected_without_completing_onboarding(self):
        self.prepare_signed();year=self.current_year()
        self.call("POST","first-access/me/complete",self.profile(),409,actor=self.user)
        self.db.expire_all();self.assertTrue(self.user.onboarding_required)
    def test_alumni_onboarding_does_not_create_active_academic_confirmation(self):
        from app.models.academic import UserAcademicHistory
        self.prepare_signed();self.user.status="alumni";self.user.profile_type="alumni";self.db.commit();self.current_year()
        self.call("POST","first-access/me/complete",self.profile(cursus=None,study_level=None,graduation_year=2024),actor=self.user)
        self.assertEqual(self.db.query(UserAcademicHistory).count(),0)

    def test_invalid_password_validation_never_echoes_secret_or_raw_input(self):
        secret="Sensitive private password "+("x"*80)
        self.request()
        response=self.call("POST","auth/activation/confirm",{"identifier":self.user.username,"code":"12345678","new_password":secret},422)
        self.assertNotIn(secret,response.text)
        self.assertNotIn('"input"',response.text)
        self.assertIsInstance(response.json()["detail"],str)
    def test_alumni_historical_cursus_and_level_are_preserved(self):
        self.prepare_signed();self.user.status="alumni";self.user.profile_type="alumni"
        self.user.cursus="DIC";self.user.study_level="DIC3";self.db.commit()
        self.call("POST","first-access/me/complete",self.profile(cursus=None,study_level=None,graduation_year=2024),actor=self.user)
        self.db.expire_all();self.assertEqual((self.user.cursus,self.user.study_level),("DIC","DIC3"))

    def make_admin(self):
        role=Role(name="administrateur");self.db.add(role);self.db.flush()
        self.db.add(UserRole(user_id=self.sg.id,role_id=role.id));self.db.commit()
    def recovery_payload(self,**values):
        body=dict(email="recovered@example.com",expected_email=self.user.email,
            verification_note="Identité confirmée en personne avec les informations du membre.",
            identity_verified=True,sessions_revocation_acknowledged=True)
        body.update(values);return body
    def used_account(self,complete=False):
        self.request();self.confirm()
        self.original_tokens=self.call("POST","auth/login",{"identifier":self.user.email,"password":"My own password 2026"}).json()
        if complete:self.call("POST","first-access/me/complete",self.profile(),actor=self.user)
        self.db.expire_all()
    def test_used_contact_recovery_is_administrator_only(self):
        self.used_account()
        self.call("POST",f"first-access/members/{self.user.id}/recover-contact",self.recovery_payload(),403,actor=self.sg)
        self.db.expire_all();self.assertEqual(self.user.email,"member@example.com")
    def test_recovery_requires_explicit_identity_and_session_acknowledgments(self):
        self.used_account();self.make_admin()
        for changes in ({"identity_verified":False},{"sessions_revocation_acknowledged":False},{"verification_note":"short"},{"verification_note":" "*25}):
            self.call("POST",f"first-access/members/{self.user.id}/recover-contact",self.recovery_payload(**changes),422,actor=self.sg)
    def test_recovery_revokes_old_sessions_and_preserves_completed_profile(self):
        self.used_account(complete=True);self.make_admin();completed=self.user.onboarding_completed_at
        from app.api.routes import first_access as first_routes
        with patch.object(first_routes,"enqueue_email_delivery",side_effect=lambda db,**kw:self.mail.append(kw)):
            self.call("POST",f"first-access/members/{self.user.id}/recover-contact",self.recovery_payload(),actor=self.sg)
        notice=next(mail for mail in self.mail if mail["recipient_email"]=="member@example.com" and "récupération" in mail["subject"])
        self.assertNotIn("code personnel",notice["text_body"])
        self.assertNotIn("recovered@example.com",notice["text_body"])
        self.db.expire_all()
        self.assertEqual(self.user.email,"recovered@example.com");self.assertTrue(self.user.credential_setup_required)
        old_access=self.client.get("/api/users/me",headers={"Authorization":"Bearer "+self.original_tokens["access_token"]})
        self.assertEqual(old_access.status_code,401)

        self.assertTrue(all(row.revoked_at is not None for row in self.db.query(AuthSession).all()))
        self.assertEqual(self.user.onboarding_completed_at,completed)
        self.assertFalse(verify_password("My own password 2026",self.user.password_hash))
        self.confirm(password="Recovered own password 2026")
        completions=[mail["dedupe_key"] for mail in self.mail if mail["subject"]=="Votre accès EnactSpace est prêt"]
        self.assertEqual(len(completions),2);self.assertEqual(len(set(completions)),2)
        self.db.expire_all();self.assertTrue(self.user.email_verified);self.assertFalse(self.user.onboarding_required)
        self.call("GET","activities",actor=self.user)
        self.assertEqual(self.db.query(AuditLog).filter_by(action="account_contact_recovery_prepared").count(),1)
    def test_recovery_email_conflict_rolls_back_password_and_sessions(self):
        self.used_account();self.make_admin();old_hash=self.user.password_hash
        self.call("POST",f"first-access/members/{self.user.id}/recover-contact",self.recovery_payload(email=self.other.email),409,actor=self.sg)
        self.db.expire_all();self.assertEqual(self.user.email,"member@example.com");self.assertEqual(self.user.password_hash,old_hash)
        self.assertTrue(all(row.revoked_at is None for row in self.db.query(AuthSession).all()))
    def test_stale_recovery_contact_is_rejected(self):
        self.used_account();self.make_admin()
        self.call("POST",f"first-access/members/{self.user.id}/recover-contact",self.recovery_payload(expected_email="stale@example.com"),409,actor=self.sg)
    def test_missing_email_of_used_account_requires_recovery_before_onboarding(self):
        self.used_account();self.user.email="placeholder@enactspace.local";self.db.commit()
        self.call("POST","first-access/me/complete",self.profile(),409,actor=self.user)
        self.make_admin()
        data=self.call("GET","first-access/members",actor=self.sg).json()
        row=next(row for row in data if row["id"]==str(self.user.id))
        self.assertTrue(row["can_prepare_recovery"]);self.assertFalse(row["can_prepare_contact"])

    def test_activation_endpoint_limits_are_configured(self):
        self.assertIn("/api/auth/activation/request",POLICIES)
        self.assertIn("/api/auth/activation/confirm",POLICIES)
    def test_suspended_after_challenge_cannot_confirm(self):
        self.request();self.user.status="suspended";self.db.commit();self.confirm(expected=400)
        self.db.expire_all();self.assertTrue(self.user.credential_setup_required)

if __name__=="__main__":unittest.main()
