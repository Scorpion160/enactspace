"""Structure writes and replacement races in a disposable PostgreSQL schema."""
import os,unittest,threading
from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
from unittest.mock import patch
from sqlalchemy import text
import test_veille as fixture
import test_veille_postgresql as postgres
import test_prelaunch_structure_boundaries as structure
from app.models.pole import PoleMember
from app.models.project import ProjectMember

@unittest.skipUnless(os.getenv("VEILLE_TEST_POSTGRESQL_URL"),"Dedicated PostgreSQL database required")
class StructurePostgreSQLTests(structure.StructureBoundaryTests):
    setUpClass=classmethod(postgres.VeillePostgreSQLTests.setUpClass.__func__)
    tearDownClass=classmethod(postgres.VeillePostgreSQLTests.tearDownClass.__func__)
    def setUp(self):
        quote=self.pg_engine.dialect.identifier_preparer.quote
        tables=[quote(self.schema)+"."+quote(table.name) for table in fixture.Base.metadata.tables.values()]
        with self.pg_engine.begin() as conn:conn.execute(text("TRUNCATE TABLE "+",".join(tables)+" RESTART IDENTITY CASCADE"))
        with patch.object(fixture,"create_engine",return_value=self.pg_engine),patch.object(
            fixture,"event",SimpleNamespace(listens_for=lambda *_:lambda function:function)),patch.object(
            fixture.Base.metadata,"create_all"):super().setUp()
    def tearDown(self):
        with patch.object(self.pg_engine,"dispose"):super().tearDown()
    def test_concurrent_leadership_replacement_leaves_one_current_leader(self):
        self.as_user("sg")
        for kind,item,other,model,key,leader in self.structures():
            barrier=threading.Barrier(2)
            def assign(who):
                barrier.wait(timeout=10)
                return self.client.post(f"/api/{kind}/{item.id}/members",
                    json={"user_id":str(self.users[who].id),"position":leader})
            with ThreadPoolExecutor(max_workers=2) as pool:
                results=list(pool.map(assign,("a","b")))
            self.assertIn(200,[row.status_code for row in results])
            self.assertTrue(all(row.status_code in (200,409) for row in results),[row.text for row in results])
            self.db.expire_all()
            current=self.db.query(model).filter(getattr(model,key)==item.id,
                model.position==leader,model.is_active.is_(True),model.left_at.is_(None)).all()
            self.assertEqual(len(current),1)


    def lifecycle_race(self, target, lifecycle, expected):
        from sqlalchemy.orm import Session
        from app.models.user import User
        from app.services.operational_integrity import lock_row,reconcile_user_lifecycle
        from app.api.routes import poles,projects
        self.as_user("sg")
        user_id=self.users[target].id
        entered=threading.Event()
        original=poles.lock_structure_write
        def observed(*args,**kwargs):
            entered.set()
            return original(*args,**kwargs)
        with Session(self.pg_engine,expire_on_commit=False) as lifecycle_db:
            user=lock_row(lifecycle_db,User,user_id)
            with patch.object(poles,"lock_structure_write",side_effect=observed),patch.object(
                projects,"lock_structure_write",side_effect=observed),ThreadPoolExecutor(max_workers=2) as pool:
                def request(kind,item):
                    if target=="sg":
                        return self.client.patch(f"/api/{kind}/{item.id}",json={"description":"Must not change"})
                    return self.client.post(f"/api/{kind}/{item.id}/members",
                        json={"user_id":str(user_id),"position":"membre"})
                futures=[pool.submit(request,kind,item) for kind,item,*_ in self.structures()]
                self.assertTrue(entered.wait(3))
                reconcile_user_lifecycle(lifecycle_db,user,lifecycle)
                lifecycle_db.commit()
                results=[future.result(timeout=15) for future in futures]
            self.assertEqual([row.status_code for row in results],[expected,expected],[row.text for row in results])
        self.db.expire_all()
        for kind,item,other,model,key,leader in self.structures():
            if target=="sg":self.assertNotEqual(item.description,"Must not change")
            else:
                rows=self.db.query(model).filter(getattr(model,key)==item.id,model.user_id==user_id,
                    model.is_active.is_(True),model.left_at.is_(None)).all()
                self.assertEqual(rows,[])
    def test_actor_suspension_committed_while_update_waits_prevents_write(self):
        self.lifecycle_race("sg","suspended",403)
    def test_target_alumni_committed_while_assignment_waits_prevents_reactivation(self):
        self.lifecycle_race("a","alumni",409)
if __name__=="__main__":unittest.main()

