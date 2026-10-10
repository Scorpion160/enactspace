"""PostgreSQL authorization changes and profile/mentorship races."""
import os,unittest,threading
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.alumni import AlumniProfile,Mentorship
from app.models.role import UserRole
from app.services.operational_integrity import lock_row,reconcile_user_lifecycle
from app.api.routes import alumni
from app.services import alumni_integrity
import test_prelaunch_alumni_boundaries as portable
import test_prelaunch_structure_boundaries_postgresql as postgres

@unittest.skipUnless(os.getenv("VEILLE_TEST_POSTGRESQL_URL"),"Dedicated PostgreSQL database required")
class AlumniPostgreSQLTests(postgres.StructurePostgreSQLTests,portable.AlumniBoundaryTests):
    def wait_race(self,target,change,request,expected):
        self.as_user("sg");entered=threading.Event();original=alumni.lock_people
        def observed(*args,**kwargs):
            entered.set();return original(*args,**kwargs)
        with Session(self.pg_engine,expire_on_commit=False) as holder:
            user=lock_row(holder,User,self.users[target].id)
            with patch.object(alumni,"lock_people",side_effect=observed),patch.object(alumni_integrity,"lock_people",side_effect=observed),ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(request)
                self.assertTrue(entered.wait(3));change(holder,user);holder.commit()
                result=future.result(timeout=15)
            self.assertEqual(result.status_code,expected,result.text)
    def test_suspension_committed_while_profile_update_waits_refuses_write(self):
        self.wait_race("mentor",lambda db,u:reconcile_user_lifecycle(db,u,"suspended"),
            lambda:self.client.patch(f"/api/alumni/profiles/{self.profile.id}",json={"domain":"Denied"}),409)
        self.db.expire_all();self.assertIsNone(self.profile.domain)
    def test_role_loss_committed_while_profile_update_waits_refuses_write(self):
        def revoke(db,user):
            for row in db.query(UserRole).filter_by(user_id=user.id).all():db.delete(row)
        self.wait_race("sg",revoke,lambda:self.client.patch(
            f"/api/alumni/profiles/{self.profile.id}",json={"domain":"Denied"}),403)
        self.db.expire_all();self.assertIsNone(self.profile.domain)
    def test_availability_changed_while_creation_waits_refuses_mentorship(self):
        def unavailable(db,user):
            db.query(AlumniProfile).filter_by(user_id=user.id).one().available_for_mentoring=False
        self.wait_race("mentor",unavailable,lambda:self.client.post("/api/alumni/mentorships",
            json={"alumni_id":str(self.users["mentor"].id),"project_id":str(self.project.id)}),409)
        self.db.expire_all();self.assertEqual(self.db.query(Mentorship).count(),0)
    def test_profile_delete_and_mentorship_creation_do_not_leave_orphan(self):
        self.as_user("sg");barrier=threading.Barrier(2)
        def create():
            barrier.wait(5);return self.client.post("/api/alumni/mentorships",
                json={"alumni_id":str(self.users["mentor"].id),"project_id":str(self.project.id)})
        def delete():
            barrier.wait(5);return self.client.delete(f"/api/alumni/profiles/{self.profile.id}")
        with ThreadPoolExecutor(max_workers=2) as pool:
            first=pool.submit(create);second=pool.submit(delete)
            codes=[first.result(15).status_code,second.result(15).status_code]
        self.assertIn(codes,([200,409],[409,200]),codes)
        self.db.expire_all()
        if self.db.query(Mentorship).count():
            self.assertIsNotNone(self.db.get(AlumniProfile,self.profile.id))
if __name__=="__main__":unittest.main()
