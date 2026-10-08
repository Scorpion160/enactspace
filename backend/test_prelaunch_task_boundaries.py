"""Task scope, frozen submitted work and Alumni historical access."""
import unittest
from datetime import timedelta
from uuid import uuid4
from app.core.time import utc_now
from app.models.role import Role, UserRole
from app.models.project import Project,ProjectMember
from app.models.task import Task,TaskAssignee,TaskChecklistItem
from app.services.veille_service import VeilleAccess
import test_veille as fixture

class TaskBoundaryTests(unittest.TestCase):
    setUp=fixture.VeilleFlowTests.setUp
    tearDown=fixture.VeilleFlowTests.tearDown
    make_task=fixture.VeilleFlowTests.make_task
    as_user=fixture.VeilleFlowTests.as_user

    def request(self,method,path,body=None,code=200):
        response=self.client.request(method,"/api/tasks"+path,json=body)
        self.assertEqual(response.status_code,code,response.text)
        return response

    def set_status(self,status):
        self.task.status=status;self.db.commit();self.as_user("lead")

    def test_dual_scope_cannot_use_owned_project_to_assign_foreign_pole(self):
        project=Project(name="Owned project",status="idee")
        self.db.add(project);self.db.flush()
        self.db.add(ProjectMember(project_id=project.id,user_id=self.users["lead"].id,position="chef_projet"))
        self.db.commit();self.as_user("lead")
        before=self.db.query(Task).count()
        self.request("POST","/",{"title":"Cross-scope assignment","pole_id":str(self.other.id),
            "project_id":str(project.id),"assignee_ids":[str(self.users["b"].id)]},400)
        self.assertEqual(self.db.query(Task).count(),before)

    def test_authorized_single_pole_creation_still_works(self):
        self.as_user("lead")
        self.request("POST","/",{"title":"Valid task","pole_id":str(self.pole.id),
            "assignee_ids":[str(self.users["a"].id)]})
    
    def test_foreign_pole_creation_still_denied(self):
        self.as_user("lead")
        self.request("POST","/",{"title":"Forbidden task","pole_id":str(self.other.id),
            "assignee_ids":[str(self.users["b"].id)]},403)

    def test_alumni_legacy_global_and_veille_roles_do_not_expose_other_tasks(self):
        alumni=self.users["veille"];alumni.status="alumni";alumni.profile_type="alumni"
        role=Role(name="pole_veille");self.db.add(role);self.db.flush()
        self.db.add(UserRole(user_id=alumni.id,role_id=role.id))
        role=Role(name="secretaire_generale");existing=self.db.query(Role).filter(Role.name==role.name).first()
        self.db.add(UserRole(user_id=alumni.id,role_id=existing.id));self.db.commit();self.as_user("veille")
        access=VeilleAccess(self.db,alumni)
        self.assertFalse(access.full);self.assertFalse(access.veille);self.assertFalse(access.coordinate)
        self.assertEqual(self.request("GET","/").json(),[])
        self.request("GET",f"/{self.secret_task.id}",code=403)

    def test_alumni_keeps_read_access_to_own_historical_assignment(self):
        alumni=self.users["a"];alumni.status="alumni";alumni.profile_type="alumni";self.db.commit();self.as_user("a")
        self.request("GET",f"/{self.task.id}")
        self.request("GET",f"/{self.secret_task.id}",code=403)
        self.request("POST",f"/{self.task.id}/status",{"status":"termine"},409)

    def test_alumni_legacy_leader_cannot_create_task(self):
        alumni=self.users["sg"];alumni.status="alumni";alumni.profile_type="alumni";self.db.commit();self.as_user("sg")
        self.request("POST","/",{"title":"Forbidden alumni task","assignee_ids":[str(self.users["a"].id)]},409)

    def test_assignee_removal_frozen_after_submission_and_closure(self):
        for status in ["termine","valide","annule"]:
            self.set_status(status)
            self.request("DELETE",f"/{self.task.id}/assignees/{self.users['a'].id}",code=409)
        self.assertEqual(self.db.query(TaskAssignee).filter_by(task_id=self.task.id).count(),1)

    def test_assignee_addition_frozen_after_submission(self):
        self.set_status("termine")
        self.request("POST","/assignees",{"task_id":str(self.task.id),
                     "user_ids":[str(self.users["lead"].id)]},409)

    def test_removing_self_cannot_unlock_self_validation(self):
        self.db.add(TaskAssignee(task_id=self.task.id,user_id=self.users["lead"].id));self.db.commit()
        self.set_status("termine")
        self.request("DELETE",f"/{self.task.id}/assignees/{self.users['lead'].id}",code=409)
        self.request("POST",f"/{self.task.id}/validate",code=403)

    def test_checklist_creation_and_deletion_frozen_after_submission(self):
        item=TaskChecklistItem(task_id=self.task.id,title="Original step")
        self.db.add(item);self.db.commit();self.set_status("termine")
        self.request("POST","/checklist",{"task_id":str(self.task.id),"title":"Late step"},409)
        self.request("DELETE",f"/checklist/{item.id}",code=409)
        self.assertEqual(self.db.query(TaskChecklistItem).filter_by(task_id=self.task.id).count(),1)

    def test_submitted_deadline_cannot_be_changed_through_generic_patch(self):
        original=self.task.due_date
        for status in ["termine","valide","annule"]:
            self.set_status(status)
            self.request("PATCH",f"/{self.task.id}",{"due_date":(utc_now()+timedelta(days=20)).isoformat(),
                        "deadline_change_reason":"A new deadline explained."},409)
        self.db.expire_all();self.assertEqual(self.db.get(Task,self.task.id).due_date,original)

    def test_submitted_proof_requirement_cannot_be_removed(self):
        self.set_status("termine")
        self.request("PATCH",f"/{self.task.id}",{"proof_required":False},409)
        self.db.expire_all();self.assertTrue(self.db.get(Task,self.task.id).proof_required)

    def test_rework_reopens_assignment_and_checklist_changes(self):
        self.set_status("termine")
        self.request("POST",f"/{self.task.id}/status",{"status":"en_cours"})
        self.request("POST","/checklist",{"task_id":str(self.task.id),"title":"Step after rework"})
        self.request("DELETE",f"/{self.task.id}/assignees/{self.users['a'].id}")

    def test_malformed_route_identifiers_rejected_before_database_access(self):
        self.as_user("lead")
        for path in ["/not-a-uuid","/not-a-uuid/checklist","/pole/not-a-uuid","/project/not-a-uuid"]:
            self.request("GET",path,code=422)
        self.request("DELETE","/checklist/not-a-uuid",code=422)

if __name__=="__main__":
    unittest.main()
