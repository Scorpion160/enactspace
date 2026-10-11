"""Governance races in a disposable PostgreSQL schema."""
import os,unittest,threading
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from sqlalchemy.orm import Session
from app.api.routes import users,seasons,academic
from app.models.user import User
from app.models.role import Role
from app.models.season import Season
from app.services.operational_integrity import get_or_create_role,lock_row,reconcile_user_lifecycle
import test_prelaunch_governance as governance
import test_prelaunch_structure_boundaries_postgresql as postgres

@unittest.skipUnless(os.getenv("VEILLE_TEST_POSTGRESQL_URL"),"Dedicated PostgreSQL required")
class GovernancePostgreSQLTests(postgres.StructurePostgreSQLTests,governance.GovernanceTests):
    def test_concurrent_initial_role_creation_produces_one_role(self):
        barrier=threading.Barrier(2)
        def create(_):
            with Session(self.pg_engine) as db:
                barrier.wait(timeout=3)
                role=get_or_create_role(db,"synthetic_concurrent_role")
                value=role.id;db.commit();return value
        with ThreadPoolExecutor(max_workers=2) as pool:ids=list(pool.map(create,(1,2)))
        self.assertEqual(ids[0],ids[1])
        self.assertEqual(self.db.query(Role).filter(Role.name=="synthetic_concurrent_role").count(),1)
    def test_concurrent_year_activations_keep_one_current_year(self):
        old,new=self.initial_years()
        later=self.year("2027–2028","2027-10-01","2028-09-30")
        barrier=threading.Barrier(2)
        def activate(year):
            barrier.wait(timeout=3)
            return self.client.post(f"/api/seasons/{year['id']}/activate",
                json={"expected_current_id":old["id"]})
        with ThreadPoolExecutor(max_workers=2) as pool:rows=list(pool.map(activate,(new,later)))
        self.assertEqual(sorted(row.status_code for row in rows),[200,409],[row.text for row in rows])
        self.assertEqual(self.db.query(Season).filter(Season.is_current.is_(True)).count(),1)
    def test_actor_suspension_while_role_assignment_is_pending_prevents_write(self):
        self.as_user("sg");entered=threading.Event();original=users.lock_role_write
        def observed(*args,**kwargs):
            entered.set();return original(*args,**kwargs)
        with Session(self.pg_engine,expire_on_commit=False) as db:
            actor=lock_row(db,User,self.users["sg"].id)
            with patch.object(users,"lock_role_write",side_effect=observed),ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(self.client.post,f"/api/users/{self.users['a'].id}/roles",
                    json={"role_names":["financier"]})
                self.assertTrue(entered.wait(3));reconcile_user_lifecycle(db,actor,"suspended");db.commit()
                result=future.result(timeout=15)
            self.assertEqual(result.status_code,403,result.text)


    def test_year_creation_and_academic_confirmation_share_lock_order(self):
        from app.services.annual_transition import lock_year_transition
        self.initial_years()
        year_entered=threading.Event();profile_entered=threading.Event()
        original_year=seasons.lock_row;original_profile=academic.lock_user
        def observed_year(*args,**kwargs):
            year_entered.set();return original_year(*args,**kwargs)
        def observed_profile(*args,**kwargs):
            profile_entered.set();return original_profile(*args,**kwargs)
        with Session(self.pg_engine) as blocker:
            lock_year_transition(blocker)
            with patch.object(seasons,"lock_row",side_effect=observed_year),patch.object(
                academic,"lock_user",side_effect=observed_profile),ThreadPoolExecutor(max_workers=2) as pool:
                first=pool.submit(self.client.post,"/api/seasons/",
                    json={"name":"2027–2028","start_date":"2027-10-01","is_current":False})
                self.assertTrue(year_entered.wait(3))
                second=pool.submit(self.client.put,"/api/academic-profile/me/confirm",
                    json={"department":"Génie Électrique","cursus":"DIC","level":"DIC2"})
                self.assertTrue(profile_entered.wait(3));blocker.commit()
                rows=[first.result(timeout=15),second.result(timeout=15)]
            self.assertEqual([row.status_code for row in rows],[200,200],[row.text for row in rows])
if __name__=="__main__":unittest.main()

