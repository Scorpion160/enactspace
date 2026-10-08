import os
os.environ.setdefault("DATABASE_URL","sqlite://")
os.environ.setdefault("SECRET_KEY","veille-isolated-test")
os.environ.setdefault("APP_ENV","test")
os.environ.setdefault("EMAIL_ENABLED","false")
os.environ.setdefault("PUSH_ENABLED","false")

import unittest
from datetime import timedelta
from types import SimpleNamespace

from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, select
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

import app.models.base
from app.api.deps import get_current_active_validated_user
from app.api.routes.veille import router
from app.api.routes import tasks as task_routes
from app.api.routes import users as user_routes
from app.api.routes import poles as pole_routes
from app.core.time import utc_now
from app.db.database import Base,get_db
from app.models.user import User
from app.models.role import Role,UserRole
from app.models.pole import Pole,PoleMember
from app.models.project import Project,ProjectMember
from app.models.task import Task,TaskAssignee
from app.models.academy import AcademyCourse,AcademyLesson
from app.models.attendance import AttendanceSession,AttendanceExpectedMember,AttendanceRecord
from app.models.finance import Fee,FinancialAccount
from app.models.notification import Notification
from app.models.veille import VeilleSettings,VeilleEvent,VeilleCase,VeilleRule,VeilleReport,VeilleReminder
from app.services.veille_scheduler import run_cycle


class VeilleFlowTests(unittest.TestCase):
    def setUp(self):
        self.engine=create_engine("sqlite://",connect_args={"check_same_thread":False},poolclass=StaticPool)
        @event.listens_for(self.engine,"connect")
        def foreign_keys(connection,_): connection.execute("PRAGMA foreign_keys=ON")
        Base.metadata.create_all(self.engine)
        self.db=Session(self.engine,expire_on_commit=False)
        self.users={}
        for key,roles in {"admin":["administrateur"],"tl":["team_leader"],"sg":["secretaire_generale"],"veille":[],"lead":["chef_pole"],"a":["enacteur"],"b":["enacteur"]}.items():
            u=User(first_name=key,last_name="Test",email=key+"@example.test",password_hash="unused",status="active",email_verified=True,is_active=True)
            self.db.add(u);self.db.flush();self.users[key]=u
            for name in roles:
                role=self.db.query(Role).filter(Role.name==name).first()
                if not role: role=Role(name=name);self.db.add(role);self.db.flush()
                self.db.add(UserRole(user_id=u.id,role_id=role.id))
        self.pole=Pole(name="Projet A",type="operationnel");self.other=Pole(name="Projet B",type="operationnel");self.watch=Pole(name="Pôle Veille",type="operationnel")
        self.db.add_all([self.pole,self.other,self.watch]);self.db.flush()
        for who,pole,position in [("lead",self.pole,"chef_pole"),("a",self.pole,"membre"),("b",self.other,"membre"),("veille",self.watch,"membre")]:
            self.db.add(PoleMember(user_id=self.users[who].id,pole_id=pole.id,position=position))
        self.course=AcademyCourse(title="Une formation",is_published=True,is_archived=False)
        self.db.add(self.course);self.db.flush()
        self.db.add(AcademyLesson(course_id=self.course.id,title="Une leçon",content="Une leçon complète.",is_published=True))
        self.config=VeilleSettings(id=1,effective_at=utc_now()-timedelta(days=60),reminders_enabled=True,auto_reports=False)
        self.db.add(self.config)
        self.task=self.make_task("a",self.pole,"en_cours")
        self.secret_task=self.make_task("b",self.other,"en_cours")
        self.db.commit();self.acting=self.users["veille"]
        app=FastAPI();app.include_router(router,prefix="/api");app.include_router(task_routes.router,prefix="/api");app.include_router(user_routes.router,prefix="/api");app.include_router(pole_routes.router,prefix="/api")
        def test_db():
            with Session(self.engine,expire_on_commit=False) as db: yield db
        app.dependency_overrides[get_db]=test_db
        app.dependency_overrides[get_current_active_validated_user]=lambda:self.acting
        self.client=TestClient(app)

    def tearDown(self): self.client.close();self.db.close();self.engine.dispose()

    def make_task(self,who,pole,status="en_cours",due=None):
        t=Task(title="Livrable "+who,pole_id=pole.id,creator_id=self.users["tl" if pole.id==self.other.id else "lead"].id,status=status,
            due_date=due or utc_now()+timedelta(days=3),proof_required=True,proof_url="https://example.test/proof")
        if status in {"termine","valide"}: t.completed_at=utc_now()
        if status=="valide":t.validated_at=utc_now();t.validated_by=self.users["tl"].id
        self.db.add(t);self.db.flush();self.db.add(TaskAssignee(task_id=t.id,user_id=self.users[who].id));self.db.flush()
        return t

    def as_user(self,name): self.acting=self.users[name]

    def call(self,method,path,body=None,code=200):
        response=self.client.request(method,"/api/veille"+path,json=body)
        self.assertEqual(response.status_code,code,response.text)
        return response.json() if response.headers.get("content-type","").startswith("application/json") else response

    def plan_payload(self,who="a",pole=True):
        return {"owner_id":str(self.users[who].id),"pole_id":str(self.pole.id) if pole else None,
            "title":"Préparer une immersion","expected_result":"Un diagnostic partagé avec la communauté.",
            "availability":"Deux après-midi cette semaine.","due_date":(utc_now()+timedelta(days=5)).isoformat()+"Z","course_ids":[str(self.course.id)]}

    def case_payload(self):
        return {"member_id":str(self.users["a"].id),"bureau_reviewer_id":str(self.users["sg"].id),
            "task_id":str(self.task.id),"title":"Un engagement à clarifier","facts":"Le livrable attendu doit être clarifié avec le membre."}

    def case_action(self,item,action,who="veille",outcome=None,amount=0,code=200):
        self.as_user(who)
        return self.call("POST",f"/cases/{item['id']}/actions",{"version":item["version"],"action":action,
            "message":"Les éléments et les prochaines actions ont été discutés.","outcome":outcome,"amount":amount},code)

    def notified_case(self,payload=None):
        self.as_user("veille");c=self.call("POST","/cases",payload or self.case_payload())
        return self.case_action(c,"notify")

    def decide_case(self,payload=None,outcome="accompagnement",amount=0):
        c=self.notified_case(payload);c=self.case_action(c,"respond","a")
        c=self.case_action(c,"propose",outcome=outcome,amount=amount)
        c=self.case_action(c,"endorse","sg")
        return self.case_action(c,"decide","tl",outcome,amount)

    def test_context_recognizes_veille_membership_without_role_alias(self):
        c=self.call("GET","/context")
        self.assertTrue(c["global_scope"]);self.assertFalse(c["can_decide"])
        self.assertEqual(len(c["members"]),7)
        self.call("POST","/rules",{"title":"Une règle","content":"Une règle adoptée et précise.","effective_from":str(utc_now().date()),"allowed_actions":["avertissement"]},403)

    def test_veille_role_assignment_and_removal_changes_actual_access(self):
        self.db.add(Role(name="pole_veille"));self.db.commit()
        path=f"/api/users/{self.users['a'].id}/roles"
        body={"role_names":["enacteur","pole_veille"]}
        for actor in ("a","sg"):
            self.as_user(actor)
            self.assertEqual(self.client.post(path,json=body).status_code,403)
        self.as_user("tl")
        response=self.client.post(path,json=body)
        self.assertEqual(response.status_code,200,response.text)
        self.as_user("a")
        self.assertTrue(self.call("GET","/context")["global_scope"])
        self.call("GET","/summary?member_id="+str(self.users['b'].id))
        self.as_user("tl")
        response=self.client.post(path,json={"role_names":["enacteur"]})
        self.assertEqual(response.status_code,200,response.text)
        self.as_user("a")
        self.assertFalse(self.call("GET","/context")["global_scope"])
        self.call("GET","/summary?member_id="+str(self.users['b'].id),code=403)

    def test_scoped_leader_cannot_gain_veille_access_by_renaming_pole(self):
        self.as_user("lead")
        response=self.client.patch(f"/api/poles/{self.pole.id}",json={"name":"Pôle Veille"})
        self.assertEqual(response.status_code,403,response.text)
        self.db.expire_all();self.assertEqual(self.db.get(Pole,self.pole.id).name,"Projet A")
        response=self.client.patch(f"/api/poles/{self.pole.id}",json={"name":"Une veille commerciale"})
        self.assertEqual(response.status_code,200,response.text)
        self.assertFalse(self.call("GET","/context")["global_scope"])

    def test_member_and_scoped_leader_cannot_read_other_scope(self):
        self.as_user("a");c=self.call("GET","/context")
        self.assertEqual([x["id"] for x in c["members"]],[str(self.users["a"].id)])
        self.call("GET","/summary?member_id="+str(self.users["b"].id),code=403)
        self.as_user("lead");s=self.call("GET","/summary")
        self.assertEqual([x["id"] for x in s["tasks"]],[str(self.task.id)])
        self.call("GET","/summary?pole_id="+str(self.other.id),code=403)
        self.call("GET","/summary?member_id="+str(self.users["b"].id),code=403)

    def test_alumni_excluded_and_invalid_period_rejected(self):
        self.users["a"].status="alumni";self.as_user("a");self.call("GET","/context",code=403)
        self.as_user("veille");self.call("GET","/summary?start=2026-02-02&end=2026-01-01",code=400)
        self.call("GET","/summary?end=2099-01-01",code=400)

    def test_engagement_round_trip_and_optimistic_lock(self):
        p=self.call("POST","/plans",self.plan_payload());d=self.call("GET",f"/records/plan/{p['id']}")
        self.assertEqual(d["assigned_courses"][0]["id"],str(self.course.id))
        self.as_user("a");change={**self.plan_payload(),"due_date":p["due_date"],"version":p["version"],"reason":"Disponibilité précisée avec le responsable.","status":"active"}
        updated=self.call("PATCH",f"/plans/{p['id']}",change);self.assertEqual(updated["version"],2)
        self.call("PATCH",f"/plans/{p['id']}",change,409)
        self.as_user("b");self.call("GET",f"/records/plan/{p['id']}",code=403)

    def test_engagement_scope_and_required_text(self):
        self.as_user("lead");self.call("POST","/plans",self.plan_payload("b"),403)
        self.as_user("a");p=self.plan_payload();p["availability"]="   ";self.call("POST","/plans",p,422)

    def test_blocker_creation_resolution_and_duplicate_protection(self):
        self.as_user("a")
        body={"task_id":str(self.task.id),"owner_id":str(self.users["a"].id),"title":"Besoin d’un contact terrain","cause":"dependance",
            "description":"Nous attendons une confirmation de disponibilité.","requested_help":"Confirmer le contact avec le partenaire.","next_action":"Relancer le partenaire demain matin.","review_at":(utc_now()+timedelta(days=1)).isoformat()+"Z"}
        b=self.call("POST","/blockers",body);self.call("POST","/blockers",body,409)
        self.db.expire_all();self.assertEqual(self.db.get(Task,self.task.id).status,"bloque")
        update={"version":1,"owner_id":body["owner_id"],"next_action":"Préparer le déplacement avec l’équipe.","review_at":body["review_at"],"status":"resolved","resolution":"Le partenaire a confirmé la rencontre."}
        self.call("PATCH",f"/blockers/{b['id']}",update)
        self.db.expire_all();self.assertEqual(self.db.get(Task,self.task.id).status,"en_cours")
        self.call("PATCH",f"/blockers/{b['id']}",update,409)

    def test_review_rework_then_accept_and_task_history(self):
        self.as_user("lead")
        self.task.status="termine";self.task.completed_at=utc_now();self.db.commit()
        task=self.call("GET","/summary")["tasks"];t=next(x for x in task if x["id"]==str(self.task.id))
        body={"verdict":"rework","feedback":"Précisez la méthode de collecte et les limites.","quality":2,"expected_updated_at":t["updated_at"]}
        self.call("POST",f"/tasks/{self.task.id}/reviews",body)
        self.db.expire_all();self.assertEqual(self.db.get(Task,self.task.id).status,"en_cours")
        self.task=self.db.get(Task,self.task.id);self.task.status="termine";self.task.completed_at=utc_now();self.task.updated_at=utc_now();self.db.commit()
        t=next(x for x in self.call("GET","/summary")["tasks"] if x["id"]==str(self.task.id))
        self.call("POST",f"/tasks/{self.task.id}/reviews",{**body,"verdict":"accepted","quality":4,"expected_updated_at":t["updated_at"]})
        history=self.call("GET",f"/tasks/{self.task.id}/history")
        self.assertEqual(len(history["reviews"]),2);self.assertTrue(any(e["action"]=="review_accepted" for e in history["events"]))

    def test_review_conflict_and_self_validation_cannot_bypass(self):
        self.task.status="termine";self.task.completed_at=utc_now();self.db.commit()
        self.db.add(TaskAssignee(task_id=self.task.id,user_id=self.users["admin"].id));self.db.commit();self.as_user("admin")
        t=next(x for x in self.call("GET","/summary")["tasks"] if x["id"]==str(self.task.id))
        self.call("POST",f"/tasks/{self.task.id}/reviews",{"verdict":"accepted","feedback":"Le travail correspond aux attentes.","expected_updated_at":t["updated_at"]},403)
        self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/validate").status_code,403)

    def test_deadline_requires_reason_and_keeps_original_date(self):
        s=self.call("GET","/summary");t=next(x for x in s["tasks"] if x["id"]==str(self.task.id))
        body={"due_date":(utc_now()+timedelta(days=8)).isoformat()+"Z","reason":"Le partenaire a proposé une nouvelle date.","expected_updated_at":t["updated_at"]}
        self.call("POST",f"/tasks/{self.task.id}/deadline",body)
        self.call("POST",f"/tasks/{self.task.id}/deadline",body,409)
        events=self.call("GET",f"/tasks/{self.task.id}/history")["events"]
        self.assertTrue(any(e["action"]=="deadline_changed" and "previous_due_date" in e["details"] for e in events))
        self.as_user("lead");response=self.client.patch(f"/api/tasks/{self.task.id}",json={"due_date":(utc_now()+timedelta(days=10)).isoformat()})
        self.assertEqual(response.status_code,400)

    def test_report_snapshot_export_and_confidentiality(self):
        self.as_user("lead");today=str(utc_now().date())
        report=self.call("POST","/reports",{"title":"Point hebdomadaire","kind":"weekly","period_start":today,"period_end":today,"pole_id":str(self.pole.id),
            "observations":"L’équipe a préparé les prochaines rencontres.","next_actions":"Confirmer les rendez-vous et relire le diagnostic."})
        exported=self.call("GET",f"/reports/{report['id']}/export")
        self.assertIn("text/csv",exported.headers["content-type"]);self.assertIn("Point hebdomadaire",exported.text)
        self.as_user("b");self.call("GET",f"/records/report/{report['id']}",code=403)
        self.call("GET",f"/reports/{report['id']}/export",code=403)

    def test_cases_require_response_and_distinct_bureau_opinion(self):
        c=self.notified_case();self.case_action(c,"propose",outcome="accompagnement",code=409)
        c=self.case_action(c,"respond","a");c=self.case_action(c,"propose",outcome="accompagnement")
        self.case_action(c,"decide","tl","accompagnement",code=409)
        self.as_user("b");self.call("GET",f"/records/case/{c['id']}",code=403)
        self.case_action(c,"endorse","a",code=403)

    def test_complete_case_response_decision_appeal_review_accept_close(self):
        c=self.decide_case();self.case_action(c,"close","tl",code=409)
        c=self.case_action(c,"appeal","a");c=self.case_action(c,"propose_review",outcome="clarification")
        c=self.case_action(c,"endorse","sg");c=self.case_action(c,"review_decide","tl","clarification")
        c=self.case_action(c,"accept","a");c=self.case_action(c,"close","tl")
        self.assertEqual(c["status"],"closed");self.assertEqual(self.db.query(Fee).count(),0)
        self.case_action(c,"comment",code=409)

    def test_rule_needed_for_warning_and_rules_not_retroactive(self):
        c=self.notified_case();c=self.case_action(c,"respond","a")
        self.case_action(c,"propose",outcome="avertissement",code=400)
        self.as_user("admin");r=self.call("POST","/rules",{"title":"Engagements convenus","content":"Une réponse contradictoire précède toute mesure.","effective_from":str(utc_now().date()+timedelta(days=1)),"allowed_actions":["avertissement"]})
        self.as_user("veille");payload={**self.case_payload(),"rule_id":r["id"]}
        c=self.notified_case(payload);c=self.case_action(c,"respond","a");self.case_action(c,"propose",outcome="avertissement",code=400)

    def test_monetary_case_closure_creates_one_fee_and_balance(self):
        self.as_user("admin");r=self.call("POST","/rules",{"title":"Règle financière adoptée","content":"Une pénalité discutée peut aller jusqu’à mille FCFA.","effective_from":str(utc_now().date()),"allowed_actions":["penalite_financiere"],"maximum_amount":1000})
        c=self.decide_case({**self.case_payload(),"rule_id":r["id"]},"penalite_financiere",1000)
        self.assertEqual(self.db.query(Fee).count(),0)
        c=self.case_action(c,"accept","a");c=self.case_action(c,"close","tl")
        self.db.expire_all();self.assertEqual(self.db.query(Fee).count(),1)
        self.assertEqual(float(self.db.query(FinancialAccount).filter_by(user_id=self.users["a"].id).one().balance_due),1000)
        self.case_action(c,"close","tl",code=409);self.assertEqual(self.db.query(Fee).count(),1)

    def test_approved_leave_exempts_due_date_and_reminder_and_self_approval_denied(self):
        self.as_user("a");day=self.task.due_date.date()
        leave=self.call("POST","/leaves",{"member_id":str(self.users["a"].id),"start_date":str(day),"end_date":str(day),"reason":"Une indisponibilité annoncée pour cette période."})
        self.call("PATCH",f"/leaves/{leave['id']}",{"version":1,"status":"approved","response":"Nous avons convenu d’une adaptation du travail."},403)
        self.as_user("veille");self.call("PATCH",f"/leaves/{leave['id']}",{"version":1,"status":"approved","response":"Nous avons convenu d’une adaptation du travail."})
        with Session(self.engine) as db:
            result=run_cycle(db,now=utc_now().replace(hour=12))
        self.assertGreaterEqual(result["reminders"],1)  # Other task remains eligible.
        self.assertFalse(self.db.query(VeilleReminder).filter_by(task_id=self.task.id).first())

    def test_reminders_are_durable_deduplicated_and_stop_on_completion(self):
        now=utc_now().replace(hour=12)
        with Session(self.engine) as db: first=run_cycle(db,now)
        self.assertEqual(first["reminders"],2)
        self.db.query(Notification).update({"is_read":True});self.db.commit()
        with Session(self.engine) as db: second=run_cycle(db,now)
        self.assertEqual(second["reminders"],0)
        self.task=self.db.get(Task,self.task.id);self.task.status="termine";self.task.completed_at=now;self.db.commit()
        with Session(self.engine) as db: later=run_cycle(db,now+timedelta(days=2))
        self.assertEqual(later["reminders"],1)

    def test_quiet_hours_and_automatic_report_once(self):
        now=utc_now().replace(hour=23)
        with Session(self.engine) as db: result=run_cycle(db,now)
        self.assertEqual(result["reminders"],0)
        self.config=self.db.get(VeilleSettings,1);self.config.auto_reports=True;self.db.commit()
        monday=utc_now().replace(hour=12)+timedelta(days=(7-utc_now().weekday())%7 or 7)
        # The snapshot covers the preceding week, never a future reporting interval.
        from unittest.mock import patch
        with patch("app.services.veille_service.utc_now",return_value=monday):
            with Session(self.engine) as db: first=run_cycle(db,monday)
            with Session(self.engine) as db: second=run_cycle(db,monday)
        self.assertEqual(first["reports"],2);self.assertEqual(second["reports"],0)

    def test_attendance_excludes_optional_and_approved_justification(self):
        now=utc_now();s=AttendanceSession(title="Réunion",status="closed",is_closed=True,scheduled_at=now,pole_id=self.pole.id)
        self.db.add(s);self.db.flush()
        self.db.add_all([AttendanceExpectedMember(session_id=s.id,user_id=self.users["a"].id,is_required=True),AttendanceExpectedMember(session_id=s.id,user_id=self.users["b"].id,is_required=False),
            AttendanceRecord(session_id=s.id,user_id=self.users["a"].id,status="absent",justification_status="approved",is_justified=True)])
        self.db.commit();data=self.call("GET","/summary")
        self.assertEqual(data["totals"]["attendance_due"],0);self.assertEqual(data["totals"]["attendance_excused"],1)
        self.assertIsNone(data["totals"]["attendance_rate"])

    def test_missing_data_is_not_zero_performance(self):
        data=self.call("GET","/summary")
        self.assertIsNone(data["totals"]["acceptance_rate"])
        self.assertIsNone(data["totals"]["quality"])
        self.assertNotIn("score",data["totals"])




    def action_payload(self,plan):
        return {"owner_id":str(self.users["a"].id),"pole_id":str(self.pole.id),"plan_id":plan["id"],
            "title":"Rencontrer les bénéficiaires","description":"Préparer les entretiens avec les membres de la communauté.",
            "due_date":(utc_now()+timedelta(days=2)).isoformat()+"Z","proof_required":True}

    def test_action_links_real_task_and_member_can_complete_before_independent_review(self):
        plan=self.call("POST","/plans",self.plan_payload())
        action=self.call("POST","/tasks",self.action_payload(plan))
        self.assertEqual(action["veille_plan_id"],plan["id"])
        self.assertEqual(action["status"],"a_faire")
        self.as_user("a")
        detail=self.call("GET",f"/tasks/{action['id']}")
        self.assertTrue(detail["current_user_assigned"]);self.assertFalse(detail["can_review"])
        for status in ("en_cours","termine"):
            if status=="termine":
                r=self.client.post(f"/api/tasks/{action['id']}/proof",json={"proof_url":"https://example.test/livrable.pdf"})
                self.assertEqual(r.status_code,200,r.text)
            r=self.client.post(f"/api/tasks/{action['id']}/status",json={"status":status})
            self.assertEqual(r.status_code,200,r.text)
        self.as_user("veille");detail=self.call("GET",f"/tasks/{action['id']}")
        self.assertTrue(detail["can_review"])
        self.call("POST",f"/tasks/{action['id']}/reviews",{"verdict":"accepted","feedback":"Les entretiens répondent à l’objectif convenu.","expected_updated_at":detail["updated_at"]})
        self.assertEqual(self.call("GET",f"/tasks/{action['id']}")["status"],"valide")
        self.assertEqual(self.call("GET",f"/records/plan/{plan['id']}")["tasks"][0]["id"],action["id"])

    def test_plan_completion_requires_accepted_actions_and_mastered_courses(self):
        from app.models.academy import AcademyProgress
        plan=self.call("POST","/plans",self.plan_payload())
        action=self.call("POST","/tasks",self.action_payload(plan))
        change={**self.plan_payload(),"version":1,"status":"completed","reason":"Les résultats sont prêts à être transmis."}
        self.call("PATCH",f"/plans/{plan['id']}",change,409)
        task=self.db.get(Task,__import__('uuid').UUID(action['id']));task.status="valide";task.validated_at=utc_now();self.db.commit()
        self.call("PATCH",f"/plans/{plan['id']}",change,409)
        lesson=self.db.query(AcademyLesson).filter_by(course_id=self.course.id).one()
        self.db.add(AcademyProgress(user_id=self.users['a'].id,course_id=self.course.id,lesson_id=lesson.id,status="completed",progress_percent=100));self.db.commit()
        complete=self.call("PATCH",f"/plans/{plan['id']}",change)
        self.assertEqual(complete["status"],"completed")
        self.call("POST","/tasks",self.action_payload(complete),400)

    def test_action_rejects_member_scope_mismatch_or_deadline_beyond_engagement(self):
        plan=self.call("POST","/plans",self.plan_payload());body=self.action_payload(plan)
        self.call("POST","/tasks",{**body,"owner_id":str(self.users['b'].id)},400)
        self.call("POST","/tasks",{**body,"due_date":(utc_now()+timedelta(days=9)).isoformat()+"Z"},400)
        self.as_user("a");self.call("POST","/tasks",body,403)

    def test_shared_task_not_excluded_for_available_member_when_other_assignee_on_leave(self):
        self.db.add(TaskAssignee(task_id=self.task.id,user_id=self.users['b'].id))
        self.task.due_date=utc_now()-timedelta(hours=1);self.db.commit()
        start=str(utc_now().date()-timedelta(days=1));end=str(utc_now().date()+timedelta(days=1))
        leave=self.call("POST","/leaves",{"member_id":str(self.users['a'].id),"start_date":start,"end_date":end,"reason":"Indisponibilité convenue avec les responsables."})
        self.call("PATCH",f"/leaves/{leave['id']}",{"version":1,"status":"approved","response":"La période est approuvée et les actions ajustées."})
        result=self.call("GET","/summary")
        people={row['id']:row for row in result['members']}
        self.assertEqual(people[str(self.users['a'].id)]['due'],0)
        self.assertEqual(people[str(self.users['b'].id)]['due'],1)
        row=next(t for t in result['tasks'] if t['id']==str(self.task.id));self.assertTrue(row['late']);self.assertFalse(row['leave_exempt'])

    def test_observed_date_prevents_retroactive_rule_and_future_facts(self):
        self.as_user("tl")
        rule=self.call("POST","/rules",{"title":"Une règle adoptée","content":"Un avertissement peut être examiné après réponse du membre.","effective_from":str(utc_now().date()),"allowed_actions":["avertissement"]})
        payload={**self.case_payload(),"rule_id":rule['id'],"observed_at":str(utc_now().date()-timedelta(days=10))}
        case=self.notified_case(payload);case=self.case_action(case,"respond","a")
        self.case_action(case,"propose",outcome="avertissement",code=400)
        self.call("POST","/cases",{**payload,"observed_at":str(utc_now().date()+timedelta(days=1))},400)

    def test_member_cannot_remove_assigned_courses_or_move_deadline_to_complete(self):
        plan=self.call("POST","/plans",self.plan_payload());self.as_user('a')
        body={**self.plan_payload(),"due_date":plan['due_date'],"version":1,"status":"completed","reason":"La disponibilité a été revue avec le responsable."}
        self.call('PATCH',f"/plans/{plan['id']}",{**body,"course_ids":[]},403)
        self.call('PATCH',f"/plans/{plan['id']}",{**body,"due_date":(utc_now()+timedelta(days=8)).isoformat()+'Z'},403)
        self.call('PATCH',f"/plans/{plan['id']}",body,409)

    def test_creator_and_bureau_subject_conflicts_rejected(self):
        self.as_user("lead");self.call("POST","/cases",{**self.case_payload(),"member_id":str(self.users['lead'].id),"task_id":None},403)
        self.as_user("veille");self.call("POST","/cases",{**self.case_payload(),"bureau_reviewer_id":str(self.users['a'].id)},400)

    def test_same_task_facts_cannot_charge_finance_twice(self):
        self.as_user("tl");rule=self.call("POST","/rules",{"title":"Une règle financière","content":"Une mesure financière est examinée contradictoirement.","effective_from":str(utc_now().date()),"allowed_actions":["penalite_financiere"],"maximum_amount":2000})
        payload={**self.case_payload(),"rule_id":rule['id']}
        closed=[]
        for _ in range(2):
            case=self.decide_case(payload,"penalite_financiere",1000)
            case=self.case_action(case,"accept","a");closed.append(self.case_action(case,"close","tl"))
        self.assertEqual(closed[0]['fee_id'],closed[1]['fee_id'])
        self.db.expire_all();self.assertEqual(self.db.query(Fee).count(),1)
        self.assertEqual(float(self.db.query(FinancialAccount).filter_by(user_id=self.users['a'].id).one().balance_due),1000)

    def test_expired_appeal_allows_closure_and_appeal_is_rejected(self):
        case=self.decide_case()
        row=self.db.get(VeilleCase,__import__('uuid').UUID(case['id']));row.appeal_until=utc_now()-timedelta(seconds=1);self.db.commit()
        self.case_action(case,"appeal","a",code=409)
        self.assertEqual(self.case_action(case,"close","tl")['status'],"closed")

    def test_settings_permissions_optimistic_lock_and_audit(self):
        from app.models.audit import AuditLog
        self.as_user("tl");config=self.call("GET","/context")['settings']
        body={k:config[k] for k in ('version','reminders_enabled','quiet_start_hour','quiet_end_hour','escalation_days','response_days','appeal_days','weekly_day','report_hour','auto_reports')}
        body['response_days']=9
        self.call("PUT","/settings",body)
        self.call("PUT","/settings",body,409)
        self.assertEqual(self.db.query(AuditLog).filter_by(action='veille_settings_updated').count(),1)
        self.as_user("veille");self.call("PUT","/settings",{**body,'version':2},403)

    def test_automatic_reports_catch_up_after_scheduled_day_and_clip_activation(self):
        from unittest.mock import patch
        now=utc_now().replace(hour=12)
        self.config.auto_reports=True;self.config.effective_at=now-timedelta(days=10);self.db.commit()
        with patch("app.services.veille_service.utc_now",return_value=now):
            with Session(self.engine) as db:first=run_cycle(db,now)
            with Session(self.engine) as db:second=run_cycle(db,now+timedelta(minutes=5))
        self.assertGreaterEqual(first['reports'],1);self.assertEqual(second['reports'],0)
        for report in self.db.query(VeilleReport):
            self.assertGreaterEqual(report.period_start,self.config.effective_at.date());self.assertLess(report.period_end,now.date())

    def test_report_csv_neutralizes_spreadsheet_formulas(self):
        self.as_user("tl");self.users['a'].first_name='=SUM(1;2)';self.db.commit()
        report=self.call("POST","/reports",{"title":"=Un bilan complet","kind":"weekly","period_start":str(utc_now().date()-timedelta(days=6)),"period_end":str(utc_now().date()),"observations":"=Une observation volontairement formulée ainsi.","next_actions":"Préparer la réunion avec les responsables."})
        export=self.call("GET",f"/reports/{report['id']}/export")
        self.assertIn("'=Un bilan complet",export.text);self.assertIn("'=SUM",export.text)

    def test_real_bearer_auth_scopes_and_history_actor(self):
        from app.core.security import create_access_token
        self.client.app.dependency_overrides.pop(get_current_active_validated_user)
        response=self.client.get('/api/veille/context');self.assertEqual(response.status_code,401)
        self.client.headers['Authorization']='Bearer invalid-token'
        self.assertEqual(self.client.get('/api/veille/context').status_code,401)
        self.client.headers['Authorization']='Bearer '+create_access_token(str(self.users['a'].id))
        context=self.call('GET','/context');self.assertFalse(context['can_coordinate'])
        self.call('GET',f'/tasks/{self.secret_task.id}',code=403)
        self.client.headers['Authorization']='Bearer '+create_access_token(str(self.users['veille'].id))
        plan=self.call('POST','/plans',self.plan_payload())
        action=self.call('POST','/tasks',self.action_payload(plan))
        history=self.call('GET',f"/tasks/{action['id']}/history")
        self.assertTrue(any(e['action']=='created' and e['created_by_id']==str(self.users['veille'].id) for e in history['events']))
        self.users['veille'].email_verified=False;self.db.commit()
        self.assertEqual(self.client.get('/api/veille/context').status_code,403)

    def test_existing_attendance_fee_is_reused_without_double_debt(self):
        from app.api.routes.finance import create_fee_record
        session=AttendanceSession(title='Réunion de travail',session_type='reunion',scheduled_at=utc_now(),status='closed',is_closed=True,scope_type='pole',pole_id=self.pole.id,created_by=self.users['lead'].id)
        self.db.add(session);self.db.flush()
        attendance=AttendanceRecord(session_id=session.id,user_id=self.users['a'].id,status='late')
        self.db.add(attendance);self.db.flush()
        fee=create_fee_record(self.db,user_id=self.users['a'].id,current_user=self.users['tl'],fee_type='manual_penalty',category='Présence',label='Retard',description='Retard à la réunion',amount=1000,currency='FCFA',source_type='attendance',source_id=attendance.id,related_attendance_id=attendance.id,due_date=utc_now().date())
        self.db.commit();self.as_user('tl')
        rule=self.call('POST','/rules',{'title':'Une règle financière','content':'La mesure doit être examinée avec le membre.','effective_from':str(utc_now().date()),'allowed_actions':['penalite_financiere'],'maximum_amount':2000})
        case=self.decide_case({**self.case_payload(),'task_id':None,'attendance_id':str(attendance.id),'rule_id':rule['id']},'penalite_financiere',1000)
        case=self.case_action(case,'accept','a');case=self.case_action(case,'close','tl')
        self.assertEqual(case['fee_id'],str(fee.id));self.db.expire_all();self.assertEqual(self.db.query(Fee).count(),1)
        self.assertEqual(float(self.db.query(FinancialAccount).filter_by(user_id=self.users['a'].id).one().balance_due),1000)

    def test_assignee_can_check_steps_but_cannot_rename_or_change_submitted_checklist(self):
        from app.models.task import TaskChecklistItem
        step=TaskChecklistItem(task_id=self.task.id,title='Préparer le guide d’entretien');self.db.add(step);self.db.commit()
        self.as_user('a');r=self.client.patch(f'/api/tasks/checklist/{step.id}',json={'is_done':True});self.assertEqual(r.status_code,200,r.text)
        r=self.client.patch(f'/api/tasks/checklist/{step.id}',json={'title':'Autre étape'});self.assertEqual(r.status_code,403)
        self.db.expire_all();self.task=self.db.get(Task,self.task.id);self.task.status='termine';self.task.completed_at=utc_now();self.db.commit()
        r=self.client.patch(f'/api/tasks/checklist/{step.id}',json={'is_done':False});self.assertEqual(r.status_code,409)

    def test_veille_can_contribute_to_task_discussion_but_other_member_cannot(self):
        self.as_user('veille');body={'task_id':str(self.task.id),'content':'Je peux aider à reprendre contact avec le partenaire.'}
        response=self.client.post('/api/tasks/comments',json=body);self.assertEqual(response.status_code,200,response.text)
        detail=self.call('GET',f'/tasks/{self.task.id}');self.assertEqual(detail['comments'][0]['author_name'],'veille Test')
        self.as_user('b');response=self.client.post('/api/tasks/comments',json=body);self.assertEqual(response.status_code,403)

    def test_standalone_action_keeps_explicit_season_and_filters_consistently(self):
        from app.models.season import Season
        first=Season(name='Saison 2026',start_date=utc_now().date(),end_date=utc_now().date()+timedelta(days=90))
        second=Season(name='Saison suivante',start_date=utc_now().date()+timedelta(days=91),end_date=utc_now().date()+timedelta(days=180))
        self.db.add_all([first,second]);self.db.flush();self.pole.season_id=second.id;self.db.commit()
        body={'owner_id':str(self.users['a'].id),'pole_id':str(self.pole.id),'season_id':str(first.id),'title':'Une immersion à préparer','description':'Préparer les entretiens avec la communauté.','due_date':(utc_now()+timedelta(days=2)).isoformat()+'Z'}
        action=self.call('POST','/tasks',body);self.assertEqual(action['veille_season_id'],str(first.id))
        first_ids={t['id'] for t in self.call('GET',f'/summary?season_id={first.id}')['tasks']}
        second_ids={t['id'] for t in self.call('GET',f'/summary?season_id={second.id}')['tasks']}
        self.assertIn(action['id'],first_ids);self.assertNotIn(action['id'],second_ids)

    def test_legacy_role_spelling_remains_valid_for_bureau_and_scheduler(self):
        from app.services.veille_scheduler import coordinator_ids
        role=self.db.query(Role).filter_by(name='team_leader').one();role.name='Team Leader';self.db.commit()
        self.as_user('tl');context=self.call('GET','/context');self.assertTrue(context['can_decide'])
        self.assertIn(str(self.users['tl'].id),{u['id'] for u in context['bureau']})
        self.assertIn(self.users['tl'].id,coordinator_ids(self.db))

    def test_leave_notifies_veille_membership_and_scoped_leader(self):
        self.as_user('a');self.call('POST','/leaves',{'member_id':str(self.users['a'].id),'start_date':str(utc_now().date()),'end_date':str(utc_now().date()+timedelta(days=1)),'reason':'Une indisponibilité est à examiner avec le responsable.'})
        ids={r[0] for r in self.db.query(Notification.user_id).filter_by(type='veille_update',related_type='veille_leave').all()}
        self.assertIn(self.users['veille'].id,ids);self.assertIn(self.users['lead'].id,ids);self.assertNotIn(self.users['b'].id,ids)

    def test_legacy_due_alert_does_not_duplicate_the_configured_veille_scheduler(self):
        self.task.due_date=utc_now()+timedelta(days=1);self.db.commit()
        task_routes.notify_task_due_soon(self.db,self.task);self.db.commit()
        self.assertEqual(self.db.query(Notification).filter_by(type='task_due_soon').count(),0)
        self.config.reminders_enabled=False;self.db.commit()
        task_routes.notify_task_due_soon(self.db,self.task);self.db.commit()
        with Session(self.engine) as db:result=run_cycle(db,utc_now().replace(hour=12))
        self.assertEqual(result['reminders'],0);self.assertEqual(self.db.query(Notification).count(),0)

if __name__=="__main__": unittest.main()
