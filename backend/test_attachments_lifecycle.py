"""Cross-module proof, EnacChef and alumni flows on isolated data."""
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from fastapi import HTTPException
from sqlalchemy import select

import test_veille as veille_fixture
from app.api.routes import files, recruitment, attendance, events, impact, alumni, auth
from app.models.attendance import AttendanceRecord, AttendanceSession
from app.models.event import Event
from app.models.impact import ImpactProject
from app.core.time import utc_now
from app.core.security import hash_password
from app.models.pole import PoleMember
from app.models.project import Project, ProjectMember
from app.models.role import Role, UserRole
from app.models.task import Task, TaskAssignee
from app.models.stored_file import StoredFile
from app.models.recruitment import RecruitmentCampaign, Application
from app.models.notification import Notification
from app.services.recruitment_questionnaire import effective_questions, questionnaire_version
from app.services.operational_integrity import reconcile_user_lifecycle


PDF = b"%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\n%%EOF\n"


class AttachmentLifecycleTests(unittest.TestCase):
    make_task = veille_fixture.VeilleFlowTests.make_task
    as_user = veille_fixture.VeilleFlowTests.as_user
    call = veille_fixture.VeilleFlowTests.call

    def setUp(self):
        veille_fixture.VeilleFlowTests.setUp(self)
        self.client.app.include_router(files.router, prefix="/api")
        self.client.app.include_router(recruitment.router, prefix="/api")
        for module in (attendance, events, impact, alumni, auth):
            self.client.app.include_router(module.router, prefix="/api")
        self.directory = tempfile.TemporaryDirectory()
        self.storage = patch("app.services.file_storage_service.UPLOAD_ROOT", Path(self.directory.name))
        self.storage.start()

    def tearDown(self):
        self.storage.stop()
        self.directory.cleanup()
        veille_fixture.VeilleFlowTests.tearDown(self)

    def upload(self, task=None, name="livrable.pdf", data=PDF):
        task = task or self.task
        return self.client.post(f"/api/tasks/{task.id}/proof-file", files={"file": (name, data, "application/octet-stream")})

    def campaign(self, questions=None):
        item = RecruitmentCampaign(title="Rejoindre l’équipe", is_active=True, application_questions=questions)
        self.db.add(item)
        self.db.commit()
        return item

    def application_payload(self, campaign):
        return {"campaign_id":str(campaign.id),"first_name":"Aïta","last_name":"Test","gender":"femme",
            "email":"candidate@example.org","phone":"771234567","department":"Génie Électrique","study_level":"DIC1",
            "motivation":"Agir avec les communautés et apprendre en équipe.","availability":"Quelques heures chaque semaine.",
            "questionnaire_version":questionnaire_version(campaign.application_questions),
            "questionnaire_answers":{q["id"]:"Une réponse complète pour partager mon expérience." for q in effective_questions(campaign.application_questions)}}

    def test_assignee_upload_remit_then_assigner_validate(self):
        self.task.status="a_faire";self.task.proof_url=None;self.db.commit()
        self.as_user("a")
        response=self.client.post(f"/api/tasks/{self.task.id}/status",json={"status":"en_cours"})
        self.assertEqual(response.status_code,200,response.text)
        response=self.upload();self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(response.json()["proof_filename"],"livrable.pdf")
        url=response.json()["proof_url"]
        response=self.client.post(f"/api/tasks/{self.task.id}/status",json={"status":"termine"})
        self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(self.upload().status_code,409)
        self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/validate").status_code,403)
        self.as_user("lead")
        self.assertEqual(self.client.get(url).content,PDF)
        self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/validate").status_code,200)

    def test_unassigned_member_cannot_upload_or_download(self):
        self.as_user("a");response=self.upload();self.assertEqual(response.status_code,200)
        self.as_user("b")
        self.assertEqual(self.upload().status_code,403)
        self.assertEqual(self.client.get(response.json()["proof_url"]).status_code,403)

    def test_veille_reads_attachment_but_cannot_replace_assignment_authority(self):
        self.as_user("a");url=self.upload().json()["proof_url"]
        self.client.post(f"/api/tasks/{self.task.id}/status",json={"status":"termine"})
        self.as_user("veille")
        self.assertEqual(self.client.get(url).status_code,200)
        detail=self.call("GET",f"/tasks/{self.task.id}")
        self.assertFalse(detail["can_review"])
        self.call("POST",f"/tasks/{self.task.id}/reviews",{"verdict":"accepted","feedback":"Le travail est correct.","expected_updated_at":detail["updated_at"]},403)

    def test_uploaded_file_cannot_be_deleted_through_generic_files(self):
        self.as_user("a");url=self.upload().json()["proof_url"]
        self.assertEqual(self.client.delete(url.removesuffix("/download")).status_code,409)
        self.assertEqual(self.client.get(url).status_code,200)

    def test_generic_upload_cannot_spoof_task_attachment(self):
        self.as_user("b")
        response=self.client.post("/api/files/upload",files={"file":("proof.pdf",PDF)},data={"entity_type":"task","entity_id":str(self.task.id)})
        self.assertEqual(response.status_code,400)
        self.assertEqual(self.db.query(StoredFile).count(),0)

    def test_invalid_empty_and_executable_attachments_are_rejected(self):
        self.as_user("a")
        for name,data in [("empty.pdf",b""),("wrong.pdf",b"not a PDF"),("script.html",b"<script>"),("run.exe",b"MZ"),("document.docx",b"PKbroken")]:
            with self.subTest(name=name):self.assertEqual(self.upload(name=name,data=data).status_code,400)
        self.assertEqual(self.db.query(StoredFile).count(),0)

    def test_attachment_size_limit_is_enforced(self):
        self.as_user("a")
        response=self.upload(name="report.txt",data=b"x"*(20*1024*1024+1))
        self.assertEqual(response.status_code,413)
        self.assertEqual(self.db.query(StoredFile).count(),0)

    def test_rework_allows_new_file_without_losing_first_proof(self):
        self.as_user("a");first=self.upload().json()["proof_url"]
        self.client.post(f"/api/tasks/{self.task.id}/status",json={"status":"termine"})
        self.as_user("lead");detail=self.call("GET",f"/tasks/{self.task.id}")
        self.call("POST",f"/tasks/{self.task.id}/reviews",{"verdict":"rework","feedback":"Complétez le rapport avec les résultats.","expected_updated_at":detail["updated_at"]})
        self.as_user("a");second=self.upload(name="rapport-complete.pdf").json()["proof_url"]
        self.assertNotEqual(first,second);self.assertEqual(self.client.get(first).content,PDF)

    def test_public_application_files_are_private_and_bound_to_application(self):
        campaign=self.campaign();payload=self.application_payload(campaign)
        response=self.client.post("/api/recruitment/applications/with-files",data={"payload":json.dumps(payload)},files={"cv":("cv.pdf",PDF),"motivation_letter":("lettre.pdf",PDF)})
        self.assertEqual(response.status_code,200,response.text)
        body=response.json();self.assertTrue(body["tracking_code"])
        self.assertEqual(self.db.query(StoredFile).count(),2)
        self.as_user("b");self.assertEqual(self.client.get(body["cv_url"]).status_code,403)
        self.as_user("veille");self.assertEqual(self.client.get(body["cv_url"]).content,PDF)
        self.as_user("sg");self.assertEqual(self.client.get(body["cv_url"]).content,PDF)
        self.assertEqual(self.client.delete(body["cv_url"].removesuffix("/download")).status_code,409)

    def test_public_invalid_file_creates_neither_application_nor_files(self):
        campaign=self.campaign()
        response=self.client.post("/api/recruitment/applications/with-files",data={"payload":json.dumps(self.application_payload(campaign))},files={"cv":("cv.pdf",PDF),"attachment":("bad.pdf",b"bad")})
        self.assertEqual(response.status_code,400)
        self.assertEqual(self.db.query(Application).count(),0);self.assertEqual(self.db.query(StoredFile).count(),0)
        self.assertEqual(list(Path(self.directory.name).rglob("*")),[])

    def test_duplicate_application_with_files_does_not_leave_orphan_files(self):
        campaign=self.campaign();payload=json.dumps(self.application_payload(campaign))
        for code in [200,409]:
            response=self.client.post("/api/recruitment/applications/with-files",data={"payload":payload},files={"cv":("cv.pdf",PDF)})
            self.assertEqual(response.status_code,code,response.text)
        self.assertEqual(self.db.query(Application).count(),1);self.assertEqual(self.db.query(StoredFile).count(),1)

    def test_changed_questionnaire_is_rejected_before_file_storage(self):
        campaign=self.campaign();payload=self.application_payload(campaign);payload["questionnaire_version"]="obsolete"
        response=self.client.post("/api/recruitment/applications/with-files",data={"payload":json.dumps(payload)},files={"cv":("cv.pdf",PDF)})
        self.assertEqual(response.status_code,409);self.assertEqual(self.db.query(StoredFile).count(),0)

    def test_closed_campaign_refuses_files_and_application(self):
        campaign=self.campaign();campaign.is_active=False;self.db.commit()
        response=self.client.post("/api/recruitment/applications/with-files",data={"payload":json.dumps(self.application_payload(campaign))},files={"cv":("cv.pdf",PDF)})
        self.assertEqual(response.status_code,400);self.assertEqual(self.db.query(StoredFile).count(),0)

    def test_enacchef_includes_project_deputy_without_generic_role(self):
        project=Project(name="Une équipe projet",status="idee");self.db.add(project);self.db.flush()
        self.db.add(ProjectMember(project_id=project.id,user_id=self.users["b"].id,position="adjoint_chef_projet"));self.db.commit()
        context=self.call("GET","/context")
        self.assertIn(str(self.users["b"].id),{p["id"] for p in context["bureau"]})
        self.assertIn(str(self.users["lead"].id),{p["id"] for p in context["bureau"]})

    def test_faculty_advisor_is_not_automatically_enacchef(self):
        role=Role(name="faculty_advisor");self.db.add(role);self.db.flush();self.db.add(UserRole(user_id=self.users["b"].id,role_id=role.id));self.db.commit()
        self.assertNotIn(str(self.users["b"].id),{p["id"] for p in self.call("GET","/context")["bureau"]})

    def test_alumni_preview_is_read_only_and_conversion_removes_operational_writes(self):
        self.as_user("tl")
        preview=self.client.get(f"/api/users/{self.users['a'].id}/alumni-transition")
        self.assertEqual(preview.status_code,200,preview.text)
        self.assertEqual(len(preview.json()["pending_tasks"]),1)
        self.db.expire_all();self.assertEqual(self.users["a"].status,"active")
        response=self.client.post(f"/api/users/{self.users['a'].id}/make-alumni")
        self.assertEqual(response.status_code,200,response.text)
        self.db.expire_all();member=self.users["a"]
        self.assertEqual(member.status,"alumni");self.assertTrue(member.is_active)
        self.assertEqual(self.db.query(PoleMember).filter_by(user_id=member.id,is_active=True).count(),0)
        self.assertEqual(self.db.query(TaskAssignee).filter_by(user_id=member.id).count(),1)
        self.assertNotEqual(self.db.get(Task,self.task.id).status,"valide")
        self.assertTrue(self.db.query(Notification).filter_by(title="Une tâche à transmettre",user_id=self.users["lead"].id).first())
        self.as_user("a")
        self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/status",json={"status":"termine"}).status_code,409)
        self.assertEqual(self.upload().status_code,409)
        self.call("GET","/context",code=403)

    def test_alumni_transition_preview_is_restricted(self):
        self.as_user("b")
        self.assertEqual(self.client.get(f"/api/users/{self.users['a'].id}/alumni-transition").status_code,403)

    def test_remitting_notifies_assigner_once_and_keeps_proof_frozen_on_patch(self):
        self.as_user("a");url=self.upload().json()["proof_url"]
        for _ in range(2):
            self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/status",json={"status":"termine"}).status_code,200)
        self.assertEqual(self.db.query(Notification).filter_by(user_id=self.users["lead"].id,type="task_review_requested").count(),1)
        self.as_user("lead")
        response=self.client.patch(f"/api/tasks/{self.task.id}",json={"title":"Le même travail avec un titre précisé","proof_url":url})
        self.assertEqual(response.status_code,200,response.text)
        response=self.client.patch(f"/api/tasks/{self.task.id}",json={"proof_url":"https://example.org/replacement.pdf"})
        self.assertEqual(response.status_code,409,response.text)

    def test_latest_assigner_validates_after_assignment_handover(self):
        self.task.assigned_by=self.users["sg"].id;self.db.commit()
        self.as_user("a");self.assertEqual(self.upload().status_code,200)
        self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/status",json={"status":"termine"}).status_code,200)
        self.as_user("lead")
        self.assertFalse(self.client.get(f"/api/tasks/{self.task.id}").json()["can_validate"])
        self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/validate").status_code,403)
        self.as_user("sg");self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/validate").status_code,200)

    def test_legacy_proof_reference_cannot_copy_another_task_private_file(self):
        self.as_user("b");url=self.upload(self.secret_task).json()["proof_url"]
        self.as_user("a")
        self.assertEqual(self.client.post(f"/api/tasks/{self.task.id}/proof",json={"proof_url":url}).status_code,400)
        self.as_user("lead")
        self.assertEqual(self.client.patch(f"/api/tasks/{self.task.id}",json={"proof_url":url}).status_code,400)

    def test_public_custom_required_questions_cannot_be_bypassed_by_old_json_client(self):
        campaign=self.campaign([{"id":"impact","label":"Quelle action veux-tu mener ?","section":"motivation","required":True}])
        payload=self.application_payload(campaign);payload.pop("questionnaire_answers")
        response=self.client.post("/api/recruitment/applications",json=payload)
        self.assertEqual(response.status_code,422,response.text)
        self.assertEqual(self.db.query(Application).count(),0)

    def test_public_file_limit_is_ten_megabytes(self):
        campaign=self.campaign()
        response=self.client.post("/api/recruitment/applications/with-files",data={"payload":json.dumps(self.application_payload(campaign))},files={"cv":("cv.pdf",PDF+b"x"*(10*1024*1024))})
        self.assertEqual(response.status_code,413,response.text)
        self.assertEqual(self.db.query(Application).count(),0)

    def absence(self):
        session=AttendanceSession(title="Une réunion",scope_type="pole",pole_id=self.pole.id,created_by=self.users["lead"].id)
        self.db.add(session);self.db.flush()
        record=AttendanceRecord(session_id=session.id,user_id=self.users["a"].id,status="absent",justification_status="not_submitted")
        self.db.add(record);self.db.commit();return record

    def test_absence_file_submission_review_and_private_download(self):
        record=self.absence();self.as_user("b")
        path=f"/api/attendance/records/{record.id}/justify-with-file"
        self.assertEqual(self.client.post(path,data={"reason":"Rendez-vous médical."},files={"file":("justificatif.pdf",PDF)}).status_code,403)
        self.as_user("a")
        response=self.client.post(path,data={"reason":"Rendez-vous médical."},files={"file":("justificatif.pdf",PDF)})
        self.assertEqual(response.status_code,200,response.text)
        body=response.json();self.assertEqual(body["justification_status"],"pending")
        self.assertEqual(self.client.get(body["justification_file_url"]).content,PDF)
        self.assertEqual(self.client.post(path,data={"reason":"Remplacement."},files={"file":("autre.pdf",PDF)}).status_code,409)
        self.as_user("b");self.assertEqual(self.client.get(body["justification_file_url"]).status_code,403)
        self.as_user("lead")
        self.assertEqual(self.client.get(body["justification_file_url"]).status_code,200)
        response=self.client.post(f"/api/attendance/records/{record.id}/justification/approve",json={})
        self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(response.json()["justification_status"],"approved")
        self.assertEqual(self.client.delete(body["justification_file_url"].removesuffix("/download")).status_code,409)

    def test_absence_cannot_reference_someone_else_task_file(self):
        self.as_user("a");url=self.upload().json()["proof_url"]
        record=self.absence()
        response=self.client.post(f"/api/attendance/records/{record.id}/justify",json={"reason":"Une explication.","file_id":url.split("/")[3]})
        self.assertEqual(response.status_code,400,response.text)

    def test_event_report_file_can_be_opened_and_requires_event_manager(self):
        event=Event(title="Immersion",event_type="immersion",start_time=utc_now(),created_by=self.users["lead"].id,pole_id=self.pole.id)
        self.db.add(event);self.db.commit()
        path=f"/api/events/{event.id}/report-file";self.as_user("a")
        self.assertEqual(self.client.post(path,files={"file":("rapport.pdf",PDF)}).status_code,403)
        self.as_user("lead")
        response=self.client.post(path,files={"file":("rapport.pdf",PDF)})
        self.assertEqual(response.status_code,200,response.text)
        url=response.json()["report_url"]
        self.as_user("a");self.assertEqual(self.client.get(url).content,PDF)
        self.assertEqual(self.client.delete(url.removesuffix("/download")).status_code,409)

    def impact_record(self,name="Impact de terrain"):
        project=Project(name=name,status="idee");self.db.add(project);self.db.flush()
        record=ImpactProject(project_id=project.id,title=name,created_by_id=self.users["lead"].id)
        self.db.add(record);self.db.commit();return record

    def test_impact_file_creates_metric_and_evidence_and_cannot_cross_records(self):
        record=self.impact_record();other=self.impact_record("Une autre action");self.as_user("a")
        args={"entity_type":"impact_record","entity_id":str(record.id),"storage_scope":"impact"}
        self.assertEqual(self.client.post("/api/files/upload",data=args,files={"file":("bilan.pdf",PDF)}).status_code,403)
        self.as_user("lead")
        response=self.client.post("/api/files/upload",data=args,files={"file":("bilan.pdf",PDF)})
        self.assertEqual(response.status_code,200,response.text);stored=response.json()
        metric={"title":"Participants formés","semantic_key":"participants","value":12,"claim_type":"MEASURED","evidence_file_id":stored["id"]}
        response=self.client.post(f"/api/impact/records/{record.id}/metrics",json=metric)
        self.assertEqual(response.status_code,200,response.text);metric_id=response.json()["id"]
        response=self.client.post(f"/api/impact/records/{record.id}/evidence",json={"title":"Bilan de formation","file_id":stored["id"],"metric_id":metric_id})
        self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(self.client.post(f"/api/impact/records/{other.id}/metrics",json=metric).status_code,400)
        self.assertEqual(self.client.get(stored["download_url"]).content,PDF)
        self.as_user("a");self.assertEqual(self.client.get(stored["download_url"]).status_code,403)
        self.as_user("tl");self.assertEqual(self.client.get(stored["download_url"]).status_code,200)
        self.assertEqual(self.client.delete(stored["download_url"].removesuffix("/download")).status_code,409)

    def test_alumni_can_log_in_keep_identity_and_manage_private_profile(self):
        member=self.users["a"];member.password_hash=hash_password("Test-only-alumni-2026!");self.db.commit()
        before=self.client.post("/api/auth/token",data={"username":member.email,"password":"Test-only-alumni-2026!"})
        self.assertEqual(before.status_code,200,before.text)
        self.as_user("tl");self.assertEqual(self.client.post(f"/api/users/{member.id}/make-alumni").status_code,200)
        login=self.client.post("/api/auth/token",data={"username":member.email,"password":"Test-only-alumni-2026!"})
        self.assertEqual(login.status_code,200,login.text)
        response=self.client.get("/api/users/me",headers={"Authorization":"Bearer "+login.json()["access_token"]})
        self.assertEqual(response.status_code,200,response.text)
        self.assertEqual(response.json()["id"],str(member.id));self.assertEqual(response.json()["status"],"alumni")
        self.as_user("a")
        profile=self.client.get(f"/api/alumni/profiles/user/{member.id}").json()
        response=self.client.patch(f"/api/alumni/profiles/{profile['id']}",json={"graduation_year":2026,"current_position":"Ingénieur","visibility":"private","available_for_mentoring":True})
        self.assertEqual(response.status_code,200,response.text);profile_id=response.json()["id"]
        self.assertEqual(self.client.patch(f"/api/alumni/profiles/{profile_id}",json={"skills":"Gestion de projet et accompagnement."}).status_code,200)
        self.as_user("b");self.assertEqual(self.client.get(f"/api/alumni/profiles/{profile_id}").status_code,403)


if __name__ == "__main__":
    unittest.main()
