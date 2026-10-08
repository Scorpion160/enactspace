import unittest, importlib.util
from datetime import date
from pathlib import Path
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import select
import test_veille as fixture
from app.api.routes import alumni, seasons, academic
from app.models.alumni import AlumniProfile
from app.models.season import Season
from app.models.project import Project
from app.models.academic import UserAcademicHistory
from app.models.notification import Notification
from app.services.operational_integrity import reconcile_user_lifecycle
from app.services.project_catalog_completion import complete_project_catalog

class AlumniYearCatalogTests(unittest.TestCase):
    make_task = fixture.VeilleFlowTests.make_task
    as_user = fixture.VeilleFlowTests.as_user
    def setUp(self):
        fixture.VeilleFlowTests.setUp(self)
        for module in (alumni, seasons, academic):
            self.client.app.include_router(module.router, prefix="/api")
        self.as_user("sg")
    def tearDown(self):
        fixture.VeilleFlowTests.tearDown(self)
    def create_year(self, name="Année 2025-2026", start="2025-10-01", end="2026-09-30", current=True):
        response=self.client.post("/api/seasons/",json={"name":name,"start_date":start,"end_date":end,"is_current":current})
        self.assertEqual(response.status_code,200,response.text)
        return response.json()
    def activate(self, year, old, status=200):
        response=self.client.post("/api/seasons/"+year["id"]+"/activate",json={"expected_current_id":old["id"] if old else None})
        self.assertEqual(response.status_code,status,response.text)
        return response
    def test_both_member_identities_enter_directory_and_keep_profile_choices(self):
        for identity,key in [("enacteur","a"),("enactrice","b")]:
            member=self.users[key];member.profile_type=identity;self.db.commit()
            self.as_user("tl")
            response=self.client.post(f"/api/users/{member.id}/make-alumni")
            self.assertEqual(response.status_code,200,response.text)
            self.as_user(key)
            response=self.client.get(f"/api/alumni/profiles/user/{member.id}")
            self.assertEqual(response.status_code,200,response.text)
            profile=response.json()
            self.assertFalse(profile["available_for_mentoring"])
            self.assertIsNone(profile["graduation_year"])
            self.assertEqual(profile["photo_url"],member.photo_url)
            self.assertEqual(self.client.patch("/api/alumni/profiles/"+profile["id"],json={"visibility":"private","skills":"Écoute et organisation."}).status_code,200)
            self.db.expire_all();reconcile_user_lifecycle(self.db,self.db.get(type(member),member.id),"alumni");self.db.commit()
            self.assertEqual(self.db.query(AlumniProfile).filter_by(user_id=member.id).count(),1)
            self.assertEqual(self.db.query(AlumniProfile).filter_by(user_id=member.id).one().visibility,"private")
            self.as_user("lead")
            visible=self.client.get("/api/alumni/profiles").json()
            self.assertNotIn(str(member.id),[p["user_id"] for p in visible])
    def test_year_transition_preserves_tasks_members_and_confirmations(self):
        old=self.create_year()
        self.as_user("a")
        body={"season_id":old["id"],"department":"Génie Électrique","cursus":"DUT","level":"DUT1"}
        response=self.client.put("/api/academic-profile/me/confirm",json=body)
        self.assertEqual(response.status_code,200,response.text)
        task_before=(self.task.id,self.task.status,self.task.pole_id)
        self.as_user("sg")
        new=self.create_year("Année 2026-2027","2026-10-01","2027-09-30",False)
        self.activate(new,old)
        self.db.expire_all()
        self.assertEqual((self.task.id,self.task.status,self.task.pole_id),task_before)
        self.assertEqual(self.users["a"].status,"active")
        self.assertTrue(self.db.get(Season,old["id"]).archived)
        self.assertEqual(self.db.query(Season).filter_by(is_current=True).count(),1)
        notifications=self.db.query(Notification).filter_by(title="Une nouvelle année commence").count()
        self.activate(new,old)
        self.assertEqual(self.db.query(Notification).filter_by(title="Une nouvelle année commence").count(),notifications)
        self.as_user("a")
        profile=self.client.get("/api/academic-profile/me").json()
        self.assertFalse(profile["confirmed_current_season"])
        self.assertEqual(profile["current_season_id"],new["id"])
        self.assertEqual(profile["suggested_next_level"],"DUT2")
        self.assertEqual(self.client.put("/api/academic-profile/me/confirm",json=body).status_code,409)
        body.update(season_id=new["id"],level="DUT2")
        self.assertEqual(self.client.put("/api/academic-profile/me/confirm",json=body).status_code,200)
        history=self.client.get("/api/academic-profile/me/history").json()
        self.assertEqual(len(history),2)
        self.assertEqual(history[0]["progression_action"],"progress")
        self.assertEqual(self.client.put("/api/academic-profile/me/confirm",json=body).status_code,409)
    def test_years_reject_overlap_stale_activation_and_unprivileged_changes(self):
        old=self.create_year()
        overlap=self.create_year("Chevauchement","2026-09-01","2027-08-31",False)
        self.activate(overlap,old,409)
        new=self.create_year("Année 2026-2027","2026-10-01","2027-09-30",False)
        self.activate(new,None,409)
        self.as_user("a")
        self.assertFalse(self.client.get("/api/seasons/context").json()["can_manage"])
        self.activate(new,old,403)
        self.assertEqual(self.client.post("/api/seasons/",json={"name":"Interdite","start_date":"2027-10-01"}).status_code,403)
    def test_catalog_completion_is_editable_idempotent_and_does_not_invent_dates(self):
        project=Project(name="Cherry",status="prototype",description="Projet actif de Enactus ESP.")
        custom=Project(name="Aquatus",status="test",solution="Notre solution revue par l’équipe.",budget_estimated=12345)
        self.db.add_all([project,custom]);self.db.flush()
        changes=complete_project_catalog(self.db);self.db.commit()
        self.assertEqual(project.name,"SHERY")
        for field in ["description","problem_statement","solution","objectives","expected_impact"]:
            self.assertGreater(len(getattr(project,field)),100)
        self.assertEqual(custom.solution,"Notre solution revue par l’équipe.")
        self.assertEqual(custom.status,"test")
        self.assertEqual(float(custom.budget_estimated),12345)
        self.assertIsNone(project.started_at);self.assertIsNone(project.ended_at)
        self.assertEqual(complete_project_catalog(self.db),[])
        project.objectives="Une évolution décidée par l’équipe.";self.db.commit()
        complete_project_catalog(self.db)
        self.assertEqual(project.objectives,"Une évolution décidée par l’équipe.")
    def test_repair_migration_is_idempotent_and_preserves_existing_profiles(self):
        member=self.users["a"];member.status="alumni";member.profile_type="alumni"
        other=self.users["b"];other.status="alumni";other.profile_type="alumni"
        custom=AlumniProfile(user_id=other.id,visibility="private",skills="Mon expérience.",available_for_mentoring=True,graduation_year=2024)
        self.db.add(custom);self.db.add(Season(name="Saison 2025-2026",start_date=date(2025,10,1),is_current=True));self.db.commit()
        path=Path(__file__).parent/"alembic/versions/20261006_0025_alumni_directory_and_current_year.py"
        spec=importlib.util.spec_from_file_location("repair25",path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        with self.engine.begin() as conn:
            with Operations.context(MigrationContext.configure(conn)):
                module.upgrade();module.upgrade()
        self.db.expire_all()
        self.assertEqual(self.db.query(AlumniProfile).count(),2)
        self.assertEqual(self.db.query(AlumniProfile).filter_by(user_id=other.id).one().visibility,"private")
        self.assertEqual(self.db.query(AlumniProfile).filter_by(user_id=member.id).one().available_for_mentoring,False)
        self.assertEqual(self.db.query(Season).one().name,"Année 2025-2026")


    def test_impact_completion_attaches_real_files_without_verifying_claims(self):
        import tempfile
        from unittest.mock import patch
        from app.models.impact import ImpactProject,ImpactEvidence
        from app.models.stored_file import StoredFile
        from app.services.project_impact_completion import complete_impact_catalog
        project=Project(name="SHERY",status="prototype")
        self.db.add(project);self.db.flush()
        record=ImpactProject(project_id=project.id,title="Notre bilan",summary="Résumé personnalisé",sdgs=["Notre sélection"],validation_status="DRAFT")
        self.db.add(record);self.db.commit()
        with tempfile.TemporaryDirectory() as directory:
            source=Path(directory)/"dossier.pdf";source.write_bytes(b"%PDF-1.4\\nDocument de test.")
            with patch("app.services.file_storage_service.UPLOAD_ROOT",Path(directory)/"files"):
                first=complete_impact_catalog(self.db,{"shery":source});self.db.commit()
                self.assertEqual(len(first),1)
                self.assertEqual(record.summary,"Résumé personnalisé")
                self.assertEqual(record.sdgs,["Notre sélection"])
                self.assertEqual(record.validation_status,"DRAFT")
                evidence=self.db.query(ImpactEvidence).one()
                self.assertEqual(evidence.validation_status,"EVIDENCE_ATTACHED")
                stored=self.db.query(StoredFile).one()
                self.assertEqual((Path(directory)/'files'/stored.storage_path).read_bytes(),source.read_bytes())
                self.assertEqual(stored.entity_id,record.id)
                self.assertFalse(stored.is_temporary)
                self.assertEqual(complete_impact_catalog(self.db,{"shery":source}),[])

if __name__=="__main__": unittest.main()

import os,uuid,threading
import sqlalchemy as sa
from sqlalchemy.orm import Session
from app.db.database import Base
from app.services.annual_transition import activate_year
from fastapi import HTTPException

@unittest.skipUnless(os.environ.get("VEILLE_TEST_POSTGRESQL_URL"),"Dedicated PostgreSQL required")
class AlumniYearPostgresqlTests(unittest.TestCase):
    def setUp(self):
        url=os.environ["VEILLE_TEST_POSTGRESQL_URL"].replace("postgresql://","postgresql+psycopg://",1)
        self.admin_engine=sa.create_engine(url)
        self.schema="annual_alumni_"+uuid.uuid4().hex
        with self.admin_engine.begin() as conn: conn.exec_driver_sql('CREATE SCHEMA "'+self.schema+'"')
        self.engine=sa.create_engine(url,connect_args={"options":"-csearch_path="+self.schema})
        Base.metadata.create_all(self.engine)
    def tearDown(self):
        self.engine.dispose()
        with self.admin_engine.begin() as conn:conn.exec_driver_sql('DROP SCHEMA "'+self.schema+'" CASCADE')
        self.admin_engine.dispose()
    def test_concurrent_year_activations_keep_one_current_and_reject_stale_choice(self):
        with Session(self.engine) as db:
            old=Season(name="2025",start_date=date(2025,10,1),end_date=date(2026,9,30),is_current=True)
            first=Season(name="2026-A",start_date=date(2026,10,1),is_current=False)
            second=Season(name="2026-B",start_date=date(2026,10,2),is_current=False)
            db.add_all([old,first,second]);db.commit()
            ids=(old.id,first.id,second.id)
        barrier=threading.Barrier(2);results=[]
        def worker(target):
            with Session(self.engine) as db:
                year=db.get(Season,target);barrier.wait(timeout=15)
                try:activate_year(db,year,expected_current_id=ids[0]);db.commit();results.append(200)
                except HTTPException as exc:db.rollback();results.append(exc.status_code)
        threads=[threading.Thread(target=worker,args=(target,)) for target in ids[1:]]
        for t in threads:t.start()
        for t in threads:t.join(timeout=30)
        self.assertFalse(any(t.is_alive() for t in threads))
        self.assertEqual(sorted(results),[200,409])
        with Session(self.engine) as db:
            self.assertEqual(db.query(Season).filter_by(is_current=True).count(),1)
            self.assertTrue(db.get(Season,ids[0]).archived)
    def test_postgresql_directory_backfill_preserves_uuids_and_existing_privacy(self):
        from app.models.user import User
        with Session(self.engine) as db:
            one=User(first_name="Test",last_name="Alumni",email="one@example.test",password_hash="unused",status="alumni",profile_type="alumni",is_active=True)
            two=User(first_name="Autre",last_name="Test",email="two@example.test",password_hash="unused",status="alumni",profile_type="alumni",is_active=True)
            db.add_all([one,two]);db.flush();ids=(one.id,two.id)
            db.add(AlumniProfile(user_id=two.id,visibility="private",graduation_year=2024,available_for_mentoring=True));db.commit()
        path=Path(__file__).parent/"alembic/versions/20261006_0025_alumni_directory_and_current_year.py"
        spec=importlib.util.spec_from_file_location("repair25pg",path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        with self.engine.begin() as conn:
            with Operations.context(MigrationContext.configure(conn)):module.upgrade();module.upgrade()
        with Session(self.engine) as db:
            self.assertEqual(db.query(AlumniProfile).count(),2)
            self.assertFalse(db.query(AlumniProfile).filter_by(user_id=ids[0]).one().available_for_mentoring)
            self.assertEqual(db.query(AlumniProfile).filter_by(user_id=ids[1]).one().graduation_year,2024)
