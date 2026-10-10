"""Alumni privacy, root authorization and mentorship boundaries."""
import unittest
from datetime import date,timedelta
from uuid import uuid4
from app.api.routes import alumni
from app.models.alumni import AlumniProfile,Mentorship
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
