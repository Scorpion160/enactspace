"""Alumni privacy, root authorization and mentorship boundaries."""
import unittest
from datetime import date,timedelta
from uuid import uuid4
from app.api.routes import alumni
from app.models.alumni import AlumniProfile,Mentorship
from app.models.audit import AuditLog
from app.models.role import UserRole
from app.models.user import User
from app.services.operational_integrity import get_or_create_role
import test_prelaunch_governance as governance

class AlumniBoundaryTests(governance.GovernanceTests):
    def setUp(self):
        super().setUp()
        self.client.app.include_router(alumni.router,prefix="/api")
        mentor=User(first_name="Mentor",last_name="Synthetic",email="mentor@example.test",password_hash="unused",status="alumni",profile_type="alumni",is_active=True,email_verified=True,enactus_join_year=2020)
        self.db.add(mentor);self.db.flush();self.users["mentor"]=mentor
        self.profile=AlumniProfile(user_id=mentor.id,visibility="internal",available_for_mentoring=True,enactus_join_year=2020)
        self.db.add(self.profile);self.db.commit()
    def test_secretariat_completes_unverified_alumni_without_activation(self):
        user = self.users["mentor"]
        user.email_verified = False
        self.db.commit()
        for actor in ("sg", "admin"):
            self.as_user(actor)
            self.call("PATCH", f"alumni/profiles/{self.profile.id}", {"current_company": "Entreprise"})
            self.db.expire_all()
            self.assertFalse(user.email_verified)
        self.as_user("a")
        self.call("PATCH", f"alumni/profiles/{self.profile.id}", {"current_company": "Interdit"}, 403)

    def test_signed_sessions_obey_individual_request_visibility(self):
        import secrets

        from app.api.deps import get_current_active_validated_user
        from app.api.routes import auth
        from app.core.security import hash_password

        self.client.app.include_router(auth.router, prefix="/api")
        self.client.app.dependency_overrides.pop(get_current_active_validated_user)
        password = secrets.token_urlsafe(24)
        password_hash = hash_password(password)
        identities = ("a", "b", "mentor", "admin")
        for identity in identities:
            self.users[identity].password_hash = password_hash
        self.db.commit()

        headers = {}
        for identity in identities:
            login = self.call("POST", "auth/login", {
                "email": self.users[identity].email, "password": password, "platform": "web",
            })
            headers[identity] = {"Authorization": f"Bearer {login.json()['access_token']}"}

        path = "/api/alumni/individual-mentorships"
        request = self.client.post(path, headers=headers["a"], json={
            "mentor_id": str(self.users["mentor"].id), "objective": "Préparer un entretien.",
        })
        self.assertEqual(request.status_code, 200, request.text)
        self.assertIn(self.client.get(path).status_code, {401, 403})
        for identity in identities:
            response = self.client.get(path, headers=headers[identity])
            self.assertEqual(response.status_code, 200, response.text)
            expected = [] if identity == "b" else [request.json()]
            self.assertEqual(response.json(), expected)

    def test_individual_requests_keep_participants_and_collective_scopes_separate(self):
        self.as_user("a")
        path = "alumni/individual-mentorships"
        payload = {"mentor_id": str(self.users["mentor"].id), "objective": "  Préparer un entretien.  "}
        created = self.call("POST", path, payload).json()
        self.assertEqual(created["objective"], "Préparer un entretien.")
        self.assertEqual(created["status"], "pending")
        self.assertEqual(created["mentee_id"], str(self.users["a"].id))
        self.assertEqual(self.call("POST", path, payload).json()["id"], created["id"])
        self.call("POST", path, {**payload, "objective": "Autre objectif"}, 409)
        self.call("POST", path, {**payload, "mentee_id": str(self.users["b"].id)}, 403)
        self.call("POST", path, {**payload, "objective": " "}, 422)
        detail = f"{path}/{created['id']}"
        self.call("PATCH", detail, {"status": "active"}, 403)
        self.assertEqual(self.call("GET", "alumni/mentorships").json(), [])
        for actor in ("a", "mentor", "sg"):
            self.as_user(actor)
            self.assertEqual(self.call("GET", path).json(), [created])
        for actor in ("b", "lead"):
            self.as_user(actor)
            self.assertEqual(self.call("GET", path).json(), [])
            self.call("PATCH", detail, {"status": "active"}, 403)

        self.as_user("sg")
        self.call("PATCH", detail, {"status": "completed"}, 409)
        self.profile.available_for_mentoring = False
        self.db.commit()
        self.call("PATCH", detail, {"status": "active"}, 409)
        self.profile.available_for_mentoring = True
        self.db.commit()
        self.assertEqual(self.call("PATCH", detail, {"status": "active"}).json()["status"], "active")
        self.profile.available_for_mentoring = False
        self.db.commit()
        self.assertEqual(self.call("GET", path).json()[0]["status"], "active")
        self.assertEqual(self.call("PATCH", detail, {"status": "completed"}).json()["status"], "completed")
        self.call("PATCH", detail, {"status": "active"}, 409)

    def test_individual_manager_can_select_mentee_and_cancel(self):
        self.as_user("admin")
        path = "alumni/individual-mentorships"
        payload = {"mentor_id": str(self.users["mentor"].id), "mentee_id": str(self.users["a"].id),
                   "objective": "Préparer un entretien."}
        for visibility in ("private", "alumni_only", "enacchef_only"):
            self.profile.visibility = visibility
            self.db.commit()
            self.call("POST", path, payload, 409)
        self.profile.visibility = "internal"
        self.db.commit()
        row = self.call("POST", path, payload).json()
        self.assertEqual(self.call("PATCH", f"{path}/{row['id']}", {"status": "cancelled"}).json()["status"], "cancelled")
        self.assertNotEqual(self.call("POST", path, payload).json()["id"], row["id"])

    def test_transition_control_repair_uses_audit_and_preserves_restrictions(self):
        self.as_user("admin")
        path = f"users/{self.users['a'].id}/alumni-transition"
        original_alumni = f"users/{self.users['mentor'].id}/alumni-transition"
        self.assertEqual(self.call("GET", original_alumni).json()["control"]["state"], "unconfirmed")
        self.call("POST", f"{original_alumni}/repair", code=409)
        self.assertEqual(self.call("GET", path).json()["control"]["state"], "unconfirmed")
        self.call("POST", f"{path}/repair", code=409)
        self.call("POST", f"users/{self.users['a'].id}/make-alumni")
        initial = self.call("GET", path).json()["control"]
        self.assertEqual(initial["state"], "linked_visible")
        self.assertIsNotNone(initial["confirmed_at"])
        self.db.query(AlumniProfile).filter_by(user_id=self.users["a"].id).delete()
        self.db.commit()
        self.assertTrue(self.call("GET", path).json()["control"]["can_repair"])

        self.as_user("sg")
        self.call("GET", path, code=403)
        self.call("POST", f"{path}/repair", code=403)
        self.as_user("tl")
        repaired = self.call("POST", f"{path}/repair").json()
        self.assertEqual(repaired["state"], "linked_visible")
        self.assertNotEqual(initial["profile_id"], repaired["profile_id"])
        self.assertEqual(self.call("POST", f"{path}/repair").json(), repaired)
        profile = self.db.query(AlumniProfile).filter_by(user_id=self.users["a"].id).one()
        self.assertFalse(profile.available_for_mentoring)
        profile.visibility = "private"
        self.db.commit()
        self.assertEqual(self.call("POST", f"{path}/repair").json()["state"], "linked_restricted")
        self.assertEqual(self.call("GET", path).json()["control"]["visibility"], "private")
        self.assertEqual(self.db.query(AuditLog).filter_by(action="reparation_fiche_alumni").count(), 1)
        self.db.refresh(self.users["a"])
        self.users["a"].profile_type = "enacteur"
        self.db.commit()
        self.assertEqual(self.call("GET", path).json()["control"]["state"], "inconsistent_account")
        self.call("POST", f"{path}/repair", code=409)

    def new_mentorship(self,scope=None,code=200):
        return self.call("POST","alumni/mentorships",dict(alumni_id=str(self.users["mentor"].id),
            project_id=str((scope or self.project).id),title="Accompagnement test",started_at=str(date.today())),code)
    def test_owner_edit_clears_optional_fields_and_syncs_year(self):
        self.as_user("mentor")
        self.call("PATCH",f"alumni/profiles/{self.profile.id}",{"current_company":"Entreprise","enactus_join_year":2019})
        self.call("PATCH",f"alumni/profiles/{self.profile.id}",{"current_company":None})
        self.db.expire_all();self.assertIsNone(self.profile.current_company)
        self.assertEqual((self.profile.enactus_join_year,self.users["mentor"].enactus_join_year),(2019,2019))
        self.assertEqual(self.call("GET",f"alumni/profiles/{self.profile.id}").json()["enactus_join_year"],2019)
    def test_legacy_alumni_role_cannot_edit_other_profile_or_mentor(self):
        actor=self.users["admin"];actor.status="alumni";actor.profile_type="alumni";self.db.commit();self.as_user("admin")
        self.call("PATCH",f"alumni/profiles/{self.profile.id}",{"domain":"Denied"},403)
        self.call("DELETE",f"alumni/profiles/{self.profile.id}",code=403)
        self.new_mentorship(code=403)
    def test_regular_member_cannot_edit_other_profile(self):
        self.as_user("a");self.call("PATCH",f"alumni/profiles/{self.profile.id}",{"domain":"Denied"},403)
    def test_sg_can_edit_profile(self):
        self.as_user("sg");self.call("PATCH",f"alumni/profiles/{self.profile.id}",{"domain":"Gestion"})
        self.db.expire_all();self.assertEqual(self.profile.domain,"Gestion")
    def test_pending_or_suspended_profiles_do_not_leak(self):
        self.as_user("sg")
        for change in ({"status":"pending"},{"status":"suspended"},{"profile_type":"enacteur"}):
            u=self.users["mentor"];u.status="alumni";u.profile_type="alumni";u.email_verified=True
            for field,value in change.items():setattr(u,field,value)
            self.db.commit()
            ids=[row["id"] for row in self.call("GET","alumni/profiles").json()]
            self.assertNotIn(str(self.profile.id),ids)
            self.call("GET",f"alumni/profiles/{self.profile.id}",code=404)
    def test_unverified_owner_profile_is_visible_without_activating_account(self):
        user=self.users["mentor"];user.email_verified=False;self.db.commit()
        for reader in ("a","sg"):
            self.as_user(reader)
            ids=[row["id"] for row in self.call("GET","alumni/profiles").json()]
            self.assertIn(str(self.profile.id),ids)
            self.call("GET",f"alumni/profiles/{self.profile.id}")
            self.call("GET",f"alumni/profiles/user/{user.id}")
            self.assertEqual(self.call("GET","alumni/profiles?available_for_mentoring=true").json(),[])
        self.assertFalse(user.email_verified)
        self.as_user("sg");self.new_mentorship(code=409)
        self.profile.visibility="private";self.db.commit();self.as_user("a")
        self.assertEqual(self.call("GET","alumni/profiles").json(),[])
        self.call("GET",f"alumni/profiles/{self.profile.id}",code=403)
        self.call("GET",f"alumni/profiles/user/{user.id}",code=403)
        self.as_user("mentor");self.call("GET","alumni/profiles",code=403)
    def test_private_visibility_protects_profile_and_mentorship(self):
        self.as_user("sg");row=self.new_mentorship().json()
        self.profile.visibility="private";self.db.commit();self.as_user("a")
        self.call("GET",f"alumni/profiles/{self.profile.id}",code=403)
        self.call("GET",f"alumni/mentorships/{row['id']}",code=403)
        self.assertEqual(self.call("GET","alumni/mentorships").json(),[])
        self.as_user("mentor");self.call("GET",f"alumni/mentorships/{row['id']}")
    def test_private_profile_cannot_be_bypassed_by_mentorship_assignment(self):
        self.profile.visibility="private";self.db.commit();self.as_user("lead")
        self.new_mentorship(code=403)
        self.as_user("sg");row=self.new_mentorship().json()
        self.as_user("lead")
        self.call("PATCH",f"alumni/mentorships/{row['id']}",{"status":"paused"},403)
        self.call("POST",f"alumni/mentorships/{row['id']}/complete",code=403)
        self.call("DELETE",f"alumni/mentorships/{row['id']}",code=403)
        self.as_user("sg");self.call("POST",f"alumni/mentorships/{row['id']}/complete")
    def test_scoped_chief_can_only_manage_own_structures(self):
        self.as_user("lead");self.new_mentorship()
        self.new_mentorship(self.other_project,403)
    def test_scoped_chief_cannot_move_mentorship_outside_scope(self):
        self.as_user("lead");row=self.new_mentorship().json()
        self.call("PATCH",f"alumni/mentorships/{row['id']}",{"project_id":str(self.other_project.id)},403)
        self.db.expire_all();self.assertEqual(self.db.get(Mentorship,row["id"]).project_id,self.project.id)
    def test_mentor_must_be_verified_and_available(self):
        self.as_user("sg");self.profile.available_for_mentoring=False;self.db.commit();self.new_mentorship(code=409)
        self.profile.available_for_mentoring=True;self.users["mentor"].email_verified=False;self.db.commit();self.new_mentorship(code=409)
    def test_invalid_uuid_and_missing_structures_are_validation_errors(self):
        self.as_user("sg")
        for path in ("alumni/profiles/bad-id","alumni/profiles/user/bad-id","alumni/mentorships/bad-id","alumni/mentorships?project_id=bad-id"):
            self.call("GET",path,code=422)
        self.call("POST","alumni/mentorships",{"alumni_id":str(self.users["mentor"].id),"project_id":str(uuid4())},422)
    def test_invalid_fields_and_dates_are_rejected(self):
        self.as_user("mentor")
        for body in ({"current_company":"x"*151},{"visibility":None},{"available_for_mentoring":None},
                     {"linkedin_url":"javascript:alert(1)"},{"enactus_join_year":1800}):
            self.call("PATCH",f"alumni/profiles/{self.profile.id}",body,422)
        self.as_user("sg");row=self.new_mentorship().json()
        for body in ({"status":None},{"title":" "},{"started_at":None},{"ended_at":str(date.today()-timedelta(days=1))},
                     {"project_id":None}):
            self.call("PATCH",f"alumni/mentorships/{row['id']}",body,422)
    def test_profile_with_mentorship_history_cannot_be_deleted(self):
        self.as_user("sg");self.new_mentorship()
        self.call("DELETE",f"alumni/profiles/{self.profile.id}",code=409)
        self.db.expire_all();self.assertIsNotNone(self.db.get(AlumniProfile,self.profile.id))
    def test_duplicate_profile_creation_is_refused(self):
        self.as_user("sg");self.call("POST","alumni/profiles",{"user_id":str(self.users["mentor"].id)},400)
    def test_unavailable_mentor_can_be_paused_or_completed(self):
        self.as_user("sg");row=self.new_mentorship().json()
        self.profile.available_for_mentoring=False;self.db.commit()
        self.call("PATCH",f"alumni/mentorships/{row['id']}",{"status":"paused"})
        self.call("PATCH",f"alumni/mentorships/{row['id']}",{"status":"active"},409)
        self.call("POST",f"alumni/mentorships/{row['id']}/complete")
if __name__=="__main__":unittest.main()
