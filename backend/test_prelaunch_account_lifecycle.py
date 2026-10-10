"""Account management permissions and lifecycle regressions on synthetic records."""
import secrets as _enactspace_fixture_secrets
_ENACTSPACE_EPHEMERAL_PASSWORD_1 = 'Aa9!' + _enactspace_fixture_secrets.token_hex(24)

import unittest
from uuid import uuid4
from app.api.deps import can_review_join_requests,get_user_role_names
from app.models.user import User
from app.models.role import UserRole
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.alumni import AlumniProfile
from app.services.operational_integrity import get_or_create_role
import test_prelaunch_governance as governance

class AccountLifecycleTests(governance.GovernanceTests):
    def new_pending(self,identity="enacteur"):
        row=User(first_name="Pending",last_name="Test",email=uuid4().hex+"@example.test",
            password_hash="unused",status="pending",profile_type=identity,is_active=False,email_verified=False)
        self.db.add(row);self.db.commit();return row
    def deny_account_actions(self,actor):
        self.as_user(actor);target=self.users["a"].id
        self.call("PATCH",f"users/{target}/admin",{"department":"Gestion"},403)
        for action in ("approve","reject","suspend","reactivate","make-alumni"):
            self.call("POST",f"users/{target}/{action}",code=403)
        self.call("GET",f"users/{target}/alumni-transition",code=403)
        self.call("POST","users/",{"first_name":"New","last_name":"Test","email":"new@example.test",
            "password":_ENACTSPACE_EPHEMERAL_PASSWORD_1},403)
    def test_alumni_legacy_direction_roles_cannot_manage_accounts(self):
        for actor in ("admin","tl","sg"):
            row=self.users[actor];row.status="alumni";row.profile_type="alumni";self.db.commit()
            self.deny_account_actions(actor)
            self.assertFalse(can_review_join_requests(self.db,row))
        self.db.expire_all();self.assertEqual(self.users["a"].department,None)
        self.assertEqual(self.users["a"].status,"active")
    def test_inactive_unverified_and_inconsistent_actor_cannot_manage_accounts(self):
        row=self.users["admin"]
        for change in ({"status":"suspended"},{"is_active":False},{"email_verified":False},{"profile_type":"alumni"}):
            row.status="active";row.is_active=True;row.email_verified=True;row.profile_type="enacteur"
            for key,value in change.items():setattr(row,key,value)
            self.db.commit();self.deny_account_actions("admin")
    def test_last_verified_administrator_cannot_be_unverified(self):
        self.as_user("sg")
        self.call("PATCH",f"users/{self.users['admin'].id}/admin",{"email_verified":False},409)
        self.db.expire_all();self.assertTrue(self.users["admin"].email_verified)
        role=get_or_create_role(self.db,"administrateur")
        self.db.add(UserRole(user_id=self.users["a"].id,role_id=role.id));self.db.commit()
        self.call("PATCH",f"users/{self.users['a'].id}/admin",{"email_verified":False})
        self.call("PATCH",f"users/{self.users['admin'].id}/admin",{"email_verified":False},409)
    def test_unrelated_veille_name_does_not_allow_join_request_review(self):
        self.pole.name="Veille commerciale";self.db.commit();self.as_user("lead")
        target=self.new_pending()
        self.assertFalse(can_review_join_requests(self.db,self.users["lead"]))
        self.call("GET","users/pending",code=403)
        self.call("POST",f"users/{target.id}/approve",code=403)
        self.call("POST",f"users/{target.id}/reject",code=403)
        self.db.expire_all();self.assertEqual(target.status,"pending")
    def test_true_veille_chief_and_adjoint_can_approve_and_reject(self):
        self.pole.name="Veille";self.db.commit();self.as_user("lead")
        member=self.db.query(PoleMember).filter_by(pole_id=self.pole.id,user_id=self.users["lead"].id).one()
        for position in ("chef_pole","adjoint_chef_pole"):
            member.position=position;self.db.commit()
            self.assertTrue(can_review_join_requests(self.db,self.users["lead"]))
            approved=self.new_pending();rejected=self.new_pending()
            self.call("POST",f"users/{approved.id}/approve")
            self.call("POST",f"users/{rejected.id}/reject")
            self.db.expire_all();self.assertEqual(approved.status,"active")
            self.assertTrue(approved.email_verified);self.assertEqual(rejected.status,"rejected")
    def test_secretary_creation_and_approval_do_not_grant_lifecycle_power(self):
        self.as_user("sg")
        response=self.call("POST","users/",{"first_name":"New","last_name":"Test",
            "email":"created@example.test","password":_ENACTSPACE_EPHEMERAL_PASSWORD_1}).json()
        self.assertEqual(response["status"],"pending");self.assertFalse(response["email_verified"])
        self.call("POST",f"users/{response['id']}/approve")
        for action in ("suspend","reactivate","make-alumni"):
            self.call("POST",f"users/{self.users['a'].id}/{action}",code=403)
    def test_alumni_conversion_suspension_reactivation_preserve_history(self):
        self.as_user("tl");target=self.users["a"]
        preview=self.call("GET",f"users/{target.id}/alumni-transition").json()
        self.assertTrue(preview["can_convert"]);self.assertTrue(preview["pending_tasks"])
        task_state=(self.task.id,self.task.status,self.task.creator_id)
        self.call("POST",f"users/{target.id}/make-alumni")
        self.call("POST",f"users/{target.id}/suspend")
        self.call("POST",f"users/{target.id}/reactivate")
        self.db.expire_all()
        self.assertEqual((target.status,target.profile_type,target.is_active),("alumni","alumni",True))
        self.assertEqual(get_user_role_names(self.db,target.id),{"alumni"})
        self.assertEqual((self.task.id,self.task.status,self.task.creator_id),task_state)
        for model in (PoleMember,ProjectMember):
            for row in self.db.query(model).filter_by(user_id=target.id).all():
                self.assertFalse(row.is_active);self.assertIsNotNone(row.left_at)
        self.assertEqual(self.db.query(AlumniProfile).filter_by(user_id=target.id).count(),1)


    def test_inconsistent_admin_profile_does_not_replace_available_admin(self):
        role=get_or_create_role(self.db,"administrateur")
        other=self.users["a"];other.profile_type="alumni"
        self.db.add(UserRole(user_id=other.id,role_id=role.id));self.db.commit();self.as_user("sg")
        self.call("PATCH",f"users/{self.users['admin'].id}/admin",{"email_verified":False},409)
        self.as_user("admin")
        self.call("POST",f"users/{self.users['admin'].id}/roles",{"role_names":[]},409)
        self.call("DELETE",f"users/{self.users['admin'].id}/roles/administrateur",code=409)

    def test_regular_member_without_authority_cannot_manage_accounts(self):
        self.deny_account_actions("a")
if __name__=="__main__":unittest.main()


