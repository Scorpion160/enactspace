"""Role and annual-transition HTTP checks using synthetic records."""
import unittest
from uuid import UUID,uuid4
from datetime import date
from unittest.mock import patch
from app.api.routes import seasons,users,academic
from app.services import annual_transition
from app.services.operational_integrity import get_or_create_role
from app.models.season import Season
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.task import Task,TaskAssignee
from app.models.role import UserRole
from app.api.deps import get_user_role_names
import test_prelaunch_structure_boundaries as structure

class GovernanceTests(structure.StructureBoundaryTests):
    def setUp(self):
        super().setUp()
        self.client.app.include_router(seasons.router,prefix="/api")
        self.client.app.include_router(academic.router,prefix="/api")
        for module in (annual_transition,users):
            item=patch.object(module,"notify_user");item.start();self.patches.append(item)
        get_or_create_role(self.db,"financier");self.db.commit()
    def year(self,name,start,end=None,current=False):
        return self.call("POST","seasons/",{"name":name,"start_date":start,
            "end_date":end,"is_current":current}).json()
    def initial_years(self):
        self.as_user("sg")
        old=self.year("2025–2026","2025-10-01","2026-09-30",True)
        new=self.year("2026–2027","2026-10-01","2027-09-30")
        return old,new
    def test_alumni_legacy_roles_cannot_change_roles_or_years(self):
        for actor in ("admin","tl","sg"):
            row=self.users[actor];row.status="alumni";row.profile_type="alumni";self.db.commit();self.as_user(actor)
            self.call("POST",f"users/{self.users['a'].id}/roles",{"role_names":["financier"]},403)
            self.call("DELETE",f"users/{self.users['a'].id}/roles/financier",code=403)
            self.call("POST","seasons/",{"name":"Refus","start_date":"2026-10-01"},403)
            self.call("POST",f"seasons/{uuid4()}/activate",{},403)
            self.assertFalse(self.call("GET","seasons/context").json()["can_manage"])
    def test_inactive_unverified_or_inconsistent_actor_cannot_change_roles(self):
        self.as_user("sg");row=self.users["sg"]
        for change in ({"status":"suspended"},{"is_active":False},{"email_verified":False},{"profile_type":"alumni"}):
            row.status="active";row.is_active=True;row.email_verified=True;row.profile_type="enacteur"
            for key,value in change.items():setattr(row,key,value)
            self.db.commit()
            self.call("POST",f"users/{self.users['a'].id}/roles",{"role_names":["financier"]},403)
            self.call("DELETE",f"users/{self.users['a'].id}/roles/financier",code=403)
    def test_legitimate_finance_role_assignment_and_removal(self):
        self.as_user("sg")
        self.call("POST",f"users/{self.users['a'].id}/roles",{"role_names":["financier"]})
        self.db.expire_all();self.assertIn("financier",get_user_role_names(self.db,self.users["a"].id))
        self.call("DELETE",f"users/{self.users['a'].id}/roles/financier")
        self.db.expire_all();self.assertNotIn("financier",get_user_role_names(self.db,self.users["a"].id))
    def test_exclusive_direction_roles_are_transferred(self):
        self.as_user("admin")
        self.call("POST",f"users/{self.users['b'].id}/roles",
            {"role_names":["team_leader","secretaire_generale"]})
        self.db.expire_all()
        self.assertNotIn("team_leader",get_user_role_names(self.db,self.users["tl"].id))
        self.assertNotIn("secretaire_generale",get_user_role_names(self.db,self.users["sg"].id))
        self.assertTrue({"team_leader","secretaire_generale"}.issubset(get_user_role_names(self.db,self.users["b"].id)))
    def test_year_activation_preserves_tasks_memberships_and_academic_profiles(self):
        old,new=self.initial_years()
        models=(Task,TaskAssignee,PoleMember,ProjectMember)
        before={model.__name__:[(str(row.id),getattr(row,"status",None),getattr(row,"is_active",None),
            getattr(row,"left_at",None)) for row in self.db.query(model).order_by(model.id).all()] for model in models}
        self.users["a"].study_level="DIC3";self.db.commit()
        self.call("POST",f"seasons/{new['id']}/activate",{"expected_current_id":old["id"]})
        self.db.expire_all()
        after={model.__name__:[(str(row.id),getattr(row,"status",None),getattr(row,"is_active",None),
            getattr(row,"left_at",None)) for row in self.db.query(model).order_by(model.id).all()] for model in models}
        self.assertEqual(before,after);self.assertEqual(self.users["a"].study_level,"DIC3")
        self.assertEqual(self.users["a"].status,"active")
        self.assertEqual(self.db.query(Season).filter(Season.is_current.is_(True)).count(),1)
        previous=self.db.get(Season,UUID(old["id"]))
        self.assertTrue(previous.archived);self.assertFalse(previous.is_current)
        calls=annual_transition.notify_user.call_count
        self.call("POST",f"seasons/{new['id']}/activate",{"expected_current_id":old["id"]})
        self.assertEqual(annual_transition.notify_user.call_count,calls)
        self.call("POST",f"seasons/{old['id']}/activate",{"expected_current_id":new["id"]},409)
    def test_stale_year_context_and_overlapping_dates_are_rejected(self):
        old,new=self.initial_years()
        self.call("POST",f"seasons/{new['id']}/activate",{"expected_current_id":str(uuid4())},409)
        overlapping=self.year("Chevauchement","2026-09-01","2027-08-31")
        self.call("POST",f"seasons/{overlapping['id']}/activate",{"expected_current_id":old["id"]},409)
        self.db.expire_all();self.assertEqual(self.db.query(Season).filter(Season.is_current.is_(True)).one().name,old["name"])
    def test_bad_year_identifier_duplicate_name_and_reversed_dates_rejected(self):
        self.as_user("sg")
        self.call("POST","seasons/bad-id/activate",{},422)
        self.call("POST",f"seasons/{uuid4()}/activate",{},404)
        self.call("POST","seasons/",{"name":" ","start_date":"2026-10-01"},422)
        self.call("POST","seasons/",{"name":"Dates","start_date":"2026-10-01","end_date":"2026-09-30"},422)
        self.year("2026","2026-10-01")
        self.call("POST","seasons/",{"name":"2026","start_date":"2027-10-01"},409)


    def test_alumni_cannot_confirm_current_academic_profile(self):
        self.initial_years();row=self.users["a"]
        row.status="alumni";row.profile_type="alumni";self.db.commit();self.as_user("a")
        self.call("PUT","academic-profile/me/confirm",
            {"department":"Génie Électrique","cursus":"DIC","level":"DIC3"},403)
if __name__=="__main__":unittest.main()

