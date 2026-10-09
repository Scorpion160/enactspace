"""Account management races in an owned disposable PostgreSQL schema."""
import os,unittest,threading
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from sqlalchemy.orm import Session
from starlette.requests import Request
from fastapi import HTTPException
from app.api.routes import users
from app.models.user import User
from app.models.role import Role,UserRole
from app.services.operational_integrity import lock_row,reconcile_user_lifecycle,get_or_create_role
import test_prelaunch_account_lifecycle as accounts
import test_prelaunch_structure_boundaries_postgresql as postgres

@unittest.skipUnless(os.getenv("VEILLE_TEST_POSTGRESQL_URL"),"Dedicated PostgreSQL required")
class AccountLifecyclePostgreSQLTests(postgres.StructurePostgreSQLTests,accounts.AccountLifecycleTests):
    def test_two_administrators_cannot_suspend_each_other_concurrently(self):
        role=get_or_create_role(self.db,"administrateur")
        self.db.add(UserRole(user_id=self.users["a"].id,role_id=role.id));self.db.commit()
        ids=(self.users["admin"].id,self.users["a"].id);barrier=threading.Barrier(2)
        def suspend(index):
            with Session(self.pg_engine) as db:
                actor=db.get(User,ids[index]);barrier.wait(timeout=3)
                request=Request({"type":"http","client":("127.0.0.1",1),"headers":[]})
                try:
                    users.suspend_user(str(ids[1-index]),request,db,actor);return 200
                except HTTPException as exc:db.rollback();return exc.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:outcomes=list(pool.map(suspend,(0,1)))
        self.assertEqual(sorted(outcomes),[200,403])
        self.db.expire_all()
        count=self.db.query(User).join(UserRole).join(Role).filter(Role.name=="administrateur",
            User.status=="active",User.is_active.is_(True),User.email_verified.is_(True)).count()
        self.assertEqual(count,1)
    def test_two_unverification_requests_leave_one_verified_administrator(self):
        role=get_or_create_role(self.db,"administrateur")
        self.db.add(UserRole(user_id=self.users["a"].id,role_id=role.id));self.db.commit();self.as_user("sg")
        ids=(self.users["admin"].id,self.users["a"].id);barrier=threading.Barrier(2)
        def unverify(member_id):
            barrier.wait(timeout=3)
            return self.client.patch(f"/api/users/{member_id}/admin",json={"email_verified":False})
        with ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(unverify,ids))
        self.assertEqual(sorted(row.status_code for row in rows),[200,409],[row.text for row in rows])
        self.db.expire_all()
        self.assertEqual(sum(bool(self.db.get(User,member_id).email_verified) for member_id in ids),1)
    def pending_actor_change(self,mode):
        self.as_user("tl");entered=threading.Event();original=users.lock_account_management
        def observed(*args,**kwargs):
            entered.set();return original(*args,**kwargs)
        with Session(self.pg_engine,expire_on_commit=False) as db:
            actor=lock_row(db,User,self.users["tl"].id)
            with patch.object(users,"lock_account_management",side_effect=observed),ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(self.client.post,f"/api/users/{self.users['a'].id}/suspend")
                self.assertTrue(entered.wait(3))
                if mode=="alumni":reconcile_user_lifecycle(db,actor,"alumni")
                else:
                    link=db.query(UserRole).join(Role).filter(UserRole.user_id==actor.id,Role.name=="team_leader").one()
                    db.delete(link)
                db.commit();result=future.result(timeout=15)
            self.assertEqual(result.status_code,403,result.text)
        self.db.expire_all();self.assertEqual(self.users["a"].status,"active")
    def test_role_loss_during_pending_suspension_prevents_write(self):
        self.pending_actor_change("role")
    def test_actor_alumni_transition_during_pending_suspension_prevents_write(self):
        self.pending_actor_change("alumni")

if __name__=="__main__":unittest.main()
