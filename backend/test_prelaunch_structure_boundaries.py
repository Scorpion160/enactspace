"""HTTP permissions and leadership replacement in synthetic structures."""
import unittest
from uuid import uuid4
from datetime import date
from unittest.mock import patch
import test_veille as fixture
from app.api.routes import poles,projects
from app.models.pole import PoleMember
from app.models.project import Project,ProjectMember
from app.api.deps import get_user_role_names

class StructureBoundaryTests(unittest.TestCase):
    make_task=fixture.VeilleFlowTests.make_task
    as_user=fixture.VeilleFlowTests.as_user
    def setUp(self):
        fixture.VeilleFlowTests.setUp(self)
        self.client.app.include_router(projects.router,prefix="/api")
        self.project=Project(name="Projet test",status="idee")
        self.other_project=Project(name="Projet autre",status="idee")
        self.db.add_all([self.project,self.other_project]);self.db.flush()
        self.db.add(ProjectMember(project_id=self.project.id,user_id=self.users["lead"].id,position="chef_projet"))
        self.db.add(ProjectMember(project_id=self.project.id,user_id=self.users["a"].id,position="membre"))
        self.db.commit();self.as_user("lead")
        self.patches=[patch.object(poles,"notify_user"),patch.object(projects,"notify_user")]
        for item in self.patches:item.start()
    def tearDown(self):
        for item in self.patches:item.stop()
        fixture.VeilleFlowTests.tearDown(self)
    def structures(self):
        return (("poles",self.pole,self.other,PoleMember,"pole_id","chef_pole"),
                ("projects",self.project,self.other_project,ProjectMember,"project_id","chef_projet"))
    def call(self,method,path,body=None,code=200):
        result=self.client.request(method,"/api/"+path,json=body)
        self.assertEqual(result.status_code,code,result.text);return result
    def test_alumni_with_legacy_global_roles_cannot_manage_but_can_read(self):
        for actor in ("admin","tl","sg"):
            user=self.users[actor];user.status="alumni";user.profile_type="alumni";self.db.commit();self.as_user(actor)
            for kind,item,other,model,key,leader in self.structures():
                self.call("GET",kind+"/")
                self.call("GET",f"{kind}/{item.id}/members")
                self.call("PATCH",f"{kind}/{item.id}",{"name":"Denied"},403)
                self.call("POST",f"{kind}/{item.id}/members",{"user_id":str(self.users["b"].id)},403)
                self.call("DELETE",f"{kind}/{item.id}/members/{self.users['a'].id}",code=403)
                payload={"name":"Denied","type":"support"} if kind=="poles" else {"name":"Denied"}
                self.call("POST",kind+"/",payload,403)
    def test_inactive_unverified_and_inconsistent_profile_cannot_manage(self):
        user=self.users["lead"]
        for change in ({"status":"suspended"},{"is_active":False},{"email_verified":False},{"profile_type":"alumni"}):
            user.status="active";user.is_active=True;user.email_verified=True;user.profile_type="enacteur"
            for key,value in change.items():setattr(user,key,value)
            self.db.commit()
            for kind,item,*_ in self.structures():self.call("PATCH",f"{kind}/{item.id}",{"name":"Denied"},403)
    def test_local_manager_cannot_modify_or_assign_in_other_scope(self):
        for kind,item,other,*_ in self.structures():
            self.call("PATCH",f"{kind}/{other.id}",{"name":"Denied"},403)
            self.call("POST",f"{kind}/{other.id}/members",{"user_id":str(self.users["a"].id)},403)
    def test_local_manager_cannot_demote_leader_through_member_assignment(self):
        for kind,item,other,model,key,leader in self.structures():
            self.call("POST",f"{kind}/{item.id}/members",
                {"user_id":str(self.users["lead"].id),"position":"membre"},403)
            self.db.expire_all()
            self.assertEqual(self.db.query(model).filter(getattr(model,key)==item.id,
                model.user_id==self.users["lead"].id).one().position,leader)
    def test_local_manager_can_manage_regular_members_and_own_details(self):
        for kind,item,other,model,key,leader in self.structures():
            self.call("PATCH",f"{kind}/{item.id}",{"description":"Un objectif précis."})
            self.call("POST",f"{kind}/{item.id}/members",{"user_id":str(self.users["b"].id)})
            self.call("DELETE",f"{kind}/{item.id}/members/{self.users['b'].id}")
            self.db.expire_all();membership=self.db.query(model).filter(getattr(model,key)==item.id,
                model.user_id==self.users["b"].id).one()
            self.assertFalse(membership.is_active);self.assertIsNotNone(membership.left_at)
    def test_global_manager_replaces_leader_without_constraint_error_and_syncs_roles(self):
        self.as_user("sg")
        for kind,item,other,model,key,leader in self.structures():
            self.call("POST",f"{kind}/{item.id}/members",{"user_id":str(self.users["a"].id),"position":leader})
            self.db.expire_all()
            rows=self.db.query(model).filter(getattr(model,key)==item.id,model.is_active.is_(True),
                model.position==leader).all()
            self.assertEqual([row.user_id for row in rows],[self.users["a"].id])
            self.assertIn(leader,get_user_role_names(self.db,self.users["a"].id))
            self.assertNotIn(leader,get_user_role_names(self.db,self.users["lead"].id))
    def test_local_manager_cannot_nominate_remove_leader_or_change_project_year(self):
        for kind,item,other,model,key,leader in self.structures():
            self.call("POST",f"{kind}/{item.id}/members",{"user_id":str(self.users["a"].id),"position":leader},403)
            self.call("DELETE",f"{kind}/{item.id}/members/{self.users['lead'].id}",code=403)
        self.call("PATCH",f"projects/{self.project.id}",{"season_id":str(uuid4())},403)
        self.call("PATCH",f"projects/{self.project.id}",{"season_id":None,"description":"Même année."})
    def test_malformed_route_identifiers_are_validation_errors(self):
        self.as_user("sg")
        for kind,item,*_ in self.structures():
            self.call("PATCH",kind+"/bad-id",{"description":"Bad"},422)
            self.call("GET",kind+"/bad-id/members",code=422)
            self.call("DELETE",f"{kind}/{item.id}/members/bad-id",code=422)
    def test_invalid_names_null_fields_and_budget_are_rejected_before_sql(self):
        for kind,item,*_ in self.structures():
            for body in ({"name":None},{"name":" "},{"name":"x"*151}):
                self.call("PATCH",f"{kind}/{item.id}",body,422)
        self.call("PATCH",f"poles/{self.pole.id}",{"type":None},422)
        for body in ({"budget_estimated":None},{"budget_estimated":-1},{"budget_estimated":10000000000},
                     {"budget_estimated":0.001},{"status":None}):
            self.call("PATCH",f"projects/{self.project.id}",body,422)
    def test_departed_project_members_are_not_listed_as_current(self):
        row=self.db.query(ProjectMember).filter(ProjectMember.project_id==self.project.id,
            ProjectMember.user_id==self.users["a"].id).one()
        row.left_at=date.today();row.is_active=True;self.db.commit()
        listing=self.call("GET",f"projects/{self.project.id}/members").json()
        self.assertNotIn(str(self.users["a"].id),[item["user_id"] for item in listing])


    def test_missing_year_is_rejected_for_create_and_update(self):
        self.as_user("sg")
        for kind,item,*_ in self.structures():
            body={"name":"Année invalide","season_id":str(uuid4())}
            if kind=="poles":body["type"]="support"
            self.call("POST",kind+"/",body,422)
        self.call("PATCH",f"projects/{self.project.id}",{"season_id":str(uuid4())},422)
    def test_valid_year_and_project_date_updates(self):
        from app.models.season import Season
        self.as_user("sg")
        year=Season(name="2026–2027",start_date=date(2026,10,1))
        self.db.add(year);self.db.commit()
        self.call("PATCH",f"projects/{self.project.id}",{"season_id":str(year.id),
            "started_at":"2026-10-10","ended_at":"2026-11-01"})
        self.call("PATCH",f"projects/{self.project.id}",{"started_at":"2026-12-01"},422)
        self.call("PATCH",f"projects/{self.project.id}",{"ended_at":"2026-10-01"},422)
        self.call("PATCH",f"projects/{self.project.id}",{"ended_at":None})
        self.call("PATCH",f"projects/{self.project.id}",{"started_at":None})
    def test_reversed_project_dates_rejected_on_create(self):
        self.as_user("sg")
        self.call("POST","projects/",{"name":"Dates invalides","started_at":"2026-11-01",
            "ended_at":"2026-10-01"},422)
    def test_responsibility_role_remains_until_last_membership_removed(self):
        self.as_user("sg")
        for kind,item,other,model,key,leader in self.structures():
            for root in (item,other):
                self.call("POST",f"{kind}/{root.id}/members",
                    {"user_id":str(self.users["a"].id),"position":leader})
            self.call("DELETE",f"{kind}/{item.id}/members/{self.users['a'].id}")
            self.db.expire_all()
            self.assertIn(leader,get_user_role_names(self.db,self.users["a"].id))
            self.call("DELETE",f"{kind}/{other.id}/members/{self.users['a'].id}")
            self.db.expire_all()
            self.assertNotIn(leader,get_user_role_names(self.db,self.users["a"].id))
if __name__=="__main__":unittest.main()

