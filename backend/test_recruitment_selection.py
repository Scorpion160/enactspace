"""Eligibility, blind access, fair workloads and atomic candidate results."""
import json
from datetime import datetime, timedelta
from unittest import TestCase
from unittest.mock import patch
from uuid import UUID

import test_attachments_lifecycle as fixture
from test_recruitment_rubric import assessment
from app.core.config import settings
from app.core.time import utc_now
from app.models.email_delivery import EmailDelivery
from app.models.audit import AuditLog
from app.models.notification import Notification
from app.models.recruitment import (
    Application, ApplicationInterviewJuror, ApplicationReview,
    ApplicationScreeningAssignment, RecruitmentCampaign, RecruitmentJuryMember,
)
from app.models.user import User
from app.services.recruitment_selection import POLICY_VERSION
from app.api.routes import recruitment as recruitment_routes
from app.services import recruitment_selection as selection_service


NOVEMBER_PLAN = {
    "applications_open": "2026-11-06", "applications_close": "2026-11-09",
    "screening_start": "2026-11-09", "screening_end": "2026-11-14",
    "screening_results": "2026-11-15", "interviews_start": "2026-11-16",
    "interviews_end": "2026-11-21", "final_results": "2026-11-24",
}


PUBLIC_PLAN = {key: NOVEMBER_PLAN[key] for key in ("applications_open", "applications_close")}

class RecruitmentSelectionTests(TestCase):
    def setUp(self):
        fixture.AttachmentLifecycleTests.setUp(self)
        from app.services.request_rate_limit import protect_public_request
        self.client.app.dependency_overrides[protect_public_request] = lambda: None

    tearDown = fixture.AttachmentLifecycleTests.tearDown
    as_user = fixture.AttachmentLifecycleTests.as_user
    make_task = fixture.AttachmentLifecycleTests.make_task
    campaign = fixture.AttachmentLifecycleTests.campaign
    application_payload = fixture.AttachmentLifecycleTests.application_payload

    def complete_personality(self, application):
        from app.api.routes.recruitment_extensions import invite_required_questionnaire
        from app.models.recruitment import ApplicationPersonality
        invite_required_questionnaire(self.db, application, self.users["sg"])
        row = self.db.get(ApplicationPersonality, application.id)
        self.db.flush()
        if row is None:
            row = self.db.get(ApplicationPersonality, application.id)
        row.submitted_at = utc_now()
        self.db.commit()

    def post(self, path, body=None, code=200):
        response = self.client.post("/api/recruitment" + path, json=body or {})
        self.assertEqual(response.status_code, code, response.text)
        return response.json()

    def prepare(self, count=1, jurors=3):
        campaign = self.campaign()
        campaign.selection_policy_version = POLICY_VERSION
        self.db.commit()
        applications = []
        for index in range(count):
            body = dict(self.application_payload(campaign), email=f"candidate-{index}@example.org", other_clubs_count=0)
            applications.append(self.post("/applications", body))
        self.as_user("sg")
        members = []
        for index in range(jurors):
            user = User(
                first_name="Juror", last_name=str(index), email=f"juror-{index}@example.test",
                password_hash="unused", status="active", email_verified=True, is_active=True,
            )
            self.db.add(user)
            self.db.flush()
            member = RecruitmentJuryMember(campaign_id=campaign.id, user_id=user.id, appointed_by=self.users["sg"].id)
            self.db.add(member)
            members.append(member)
        self.db.commit()
        return campaign, applications, members

    def assign(self, campaign):
        self.as_user("sg")
        return self.post(f"/campaigns/{campaign.id}/selection/assign", {
            "minimum_reviews": 2, "disagreement_threshold": 20,
        })

    def rate(self, application, rating=3, reviewer=None):
        if reviewer is not None:
            self.acting = self.db.get(User, reviewer)
        return self.post("/reviews", {
            "application_id": application["id"], "criteria_assessment": assessment(rating),
        })

    def complete_screening(self, campaign, applications):
        self.assign(campaign)
        for application in applications:
            assignments = self.db.query(ApplicationScreeningAssignment).filter_by(
                application_id=UUID(application["id"]), declined_at=None,
            ).all()
            for row in assignments:
                self.rate(application, reviewer=row.reviewer_id)
        self.as_user("sg")

    def report(self, campaign):
        response = self.client.get(f"/api/recruitment/campaigns/{campaign.id}/selection")
        self.assertEqual(response.status_code, 200, response.text)
        return response.json()

    def test_new_dossiers_are_allocated_and_reviewed_while_submissions_remain_open(self):
        campaign, _, _ = self.prepare(count=0)
        self.post(f"/campaigns/{campaign.id}/selection/planning", NOVEMBER_PLAN)
        body = self.application_payload(campaign)
        with patch.object(recruitment_routes, "utc_now", return_value=datetime(2026, 11, 6, 10)):
            first = self.post("/applications", body)
            first_id = UUID(first["id"])
            original = {row.reviewer_id for row in self.db.query(ApplicationScreeningAssignment).filter_by(application_id=first_id)}
            self.assertEqual(len(original), 2)
            self.assertTrue(all(row.assigned_by is None for row in self.db.query(ApplicationScreeningAssignment)))
            review = self.rate(first, reviewer=next(iter(original)))
            self.as_user("sg")
            self.post(f"/applications/{first_id}/selection-decision", {"stage": "screening", "decision": "shortlisted"})
            report = self.report(campaign)
            with patch.object(selection_service, "utc_now", return_value=datetime(2026, 11, 6, 10)):
                rejected = self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "screening", "revision": report["revision"]}, 409)
                self.assertIn("Clôture", rejected["detail"])
            response = self.client.post("/api/recruitment/applications/with-files",
                data={"payload": json.dumps(dict(body, email="later-arrival@example.org"))},
                files={"cv": ("cv.pdf", fixture.PDF)})
            self.assertEqual(response.status_code, 200, response.text)
            later = response.json()
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).filter_by(application_id=UUID(later["id"])).count(), 2)
        self.assertEqual({row.reviewer_id for row in self.db.query(ApplicationScreeningAssignment).filter_by(application_id=first_id)}, original)
        self.assertEqual(str(self.db.query(ApplicationReview).one().id), review["id"])
        loads = self.assign(campaign)["loads"]
        self.assertEqual(sorted(row["assigned_count"] for row in loads), [1, 1, 2])
        self.assertEqual(self.client.get(later["cv_url"]).status_code, 403)
        tracking = self.post("/applications/track", {"application_id": first["tracking_code"], "email": first["email"]})
        self.assertEqual(tracking["status"], "under_review")
        self.assertIsNone(tracking["screening_result"])
        self.db.refresh(campaign)
        self.assertIsNone(campaign.screening_published_at)
        self.assertEqual(self.db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like("recruitment-results:%")).count(), 0)

    def test_late_jury_appointments_fill_waiting_dossiers_without_blocking_new_submissions(self):
        campaign, applications, _ = self.prepare(jurors=0)
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).count(), 0)
        self.post(f"/campaigns/{campaign.id}/jury", {"user_id": str(self.users["a"].id)})
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).count(), 1)
        later = self.post("/applications", dict(self.application_payload(campaign), email="while-jury-incomplete@example.org"))
        self.assertEqual(self.db.query(Application).count(), 2)
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).count(), 2)
        self.post(f"/campaigns/{campaign.id}/jury", {"user_id": str(self.users["b"].id)})
        for application in (applications[0], later):
            assignments = self.db.query(ApplicationScreeningAssignment).filter_by(application_id=UUID(application["id"])).all()
            self.assertEqual({row.reviewer_id for row in assignments}, {self.users["a"].id, self.users["b"].id})
        self.post(f"/campaigns/{campaign.id}/jury", {"user_id": str(self.users["b"].id)})
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).count(), 4)

    def test_planning_controls_the_submission_window_and_exposes_the_public_dates(self):
        campaign, _, members = self.prepare(count=0)
        self.acting = self.db.get(User, members[0].user_id)
        self.post(f"/campaigns/{campaign.id}/selection/planning", NOVEMBER_PLAN, 403)
        self.as_user("sg")
        self.post(f"/campaigns/{campaign.id}/selection/planning", dict(NOVEMBER_PLAN, final_results="2026-11-18"), 422)
        self.post(f"/campaigns/{campaign.id}/selection/planning", NOVEMBER_PLAN)
        self.db.refresh(campaign)
        self.assertEqual(campaign.start_date.isoformat(), "2026-11-06")
        self.assertEqual(campaign.end_date.isoformat(), "2026-11-09")
        body = self.application_payload(campaign)
        with patch.object(recruitment_routes, "utc_now", return_value=datetime(2026, 11, 5, 12)):
            self.post("/applications", body, 400)
            timeline = self.client.get("/api/recruitment/campaigns/timeline").json()["campaigns"][0]
            self.assertEqual(timeline["selection_schedule"], PUBLIC_PLAN)
            self.assertEqual(timeline["closes_at"], "2026-11-10T00:00:00Z")
        with patch.object(recruitment_routes, "utc_now", return_value=datetime(2026, 11, 6)):
            self.post("/applications", body)
        with patch.object(recruitment_routes, "utc_now", return_value=datetime(2026, 11, 9, 23, 59)):
            self.post("/applications", dict(body, email="last-day@example.org"))
        with patch.object(recruitment_routes, "utc_now", return_value=datetime(2026, 11, 10)):
            self.post("/applications", dict(body, email="too-late@example.org"), 400)
        changed = self.client.patch(f"/api/recruitment/campaigns/{campaign.id}", json={"end_date": "2026-11-08"})
        self.assertEqual(changed.status_code, 409, changed.text)

    def test_first_results_wait_until_the_announced_date_and_mail_supplies_any_missing_code(self):
        campaign, applications, _ = self.prepare()
        self.complete_screening(campaign, applications)
        self.post(f"/campaigns/{campaign.id}/selection/planning", NOVEMBER_PLAN)
        self.post(f"/applications/{applications[0]['id']}/selection-decision", {"stage": "screening", "decision": "not_shortlisted"})
        application = self.db.get(Application, UUID(applications[0]["id"]))
        application.tracking_code = None
        self.db.commit()
        with patch.object(selection_service, "utc_now", return_value=datetime(2026, 11, 14, 23, 59)):
            report = self.report(campaign)
            self.assertFalse(report["can_publish_on_date"])
            result = self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "screening", "revision": report["revision"]}, 409)
            self.assertIn("15/11/2026", result["detail"])
        with patch.object(selection_service, "utc_now", return_value=datetime(2026, 11, 15)), patch.object(
            settings, "EMAIL_ENABLED", True
        ), patch.object(settings, "SMTP_HOST", "smtp.example.test"):
            self.assertTrue(self.report(campaign)["can_publish_on_date"])
            self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "screening", "revision": report["revision"]})
        self.db.refresh(application)
        self.assertTrue(application.tracking_code.startswith("ESP-"))
        delivery = self.db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like("recruitment-results:%")).one()
        self.assertIn("Code de suivi : " + application.tracking_code, delivery.text_body)
        tracking = self.post("/applications/track", {"application_id": application.tracking_code, "email": application.email})
        self.assertEqual(tracking["selection_schedule"], PUBLIC_PLAN)
        self.post(f"/campaigns/{campaign.id}/selection/planning", dict(NOVEMBER_PLAN, final_results="2026-11-30"))
        tracking = self.post("/applications/track", {"application_id": application.tracking_code, "email": application.email})
        self.assertEqual(tracking["status"], "rejected")
        self.assertNotIn("final_results", tracking["selection_schedule"])
        self.assertEqual(self.report(campaign)["selection_schedule"]["final_results"], "2026-11-30")

    def test_calendar_remains_editable_after_screening_without_reopening_or_moving_appointments(self):
        campaign, applications, _ = self.prepare()
        self.post(f"/campaigns/{campaign.id}/selection/planning", NOVEMBER_PLAN)
        self.db.refresh(campaign)
        published_at = datetime(2026, 11, 15)
        campaign.screening_published_at = published_at
        campaign.identities_revealed_at = published_at
        application = self.db.get(Application, UUID(applications[0]["id"]))
        application.screening_decision = "shortlisted"
        application.status = "interview_scheduled"
        application.interview_at = datetime(2026, 11, 16, 10)
        application.interview_end_at = datetime(2026, 11, 16, 10, 20)
        self.db.commit()
        previous_revision = self.report(campaign)["revision"]
        revised = dict(NOVEMBER_PLAN, applications_close="2026-11-20", screening_end="2026-11-21",
                       screening_results="2026-11-22", interviews_start="2026-11-23",
                       interviews_end="2026-11-27", final_results="2026-11-30")
        report = self.post(f"/campaigns/{campaign.id}/selection/planning", revised)
        self.assertEqual(report["selection_schedule"], revised)
        self.assertNotEqual(report["revision"], previous_revision)
        with patch.object(selection_service, "utc_now", return_value=datetime(2026, 11, 24)):
            self.assertFalse(self.report(campaign)["can_publish_on_date"])
        self.db.refresh(campaign)
        self.db.refresh(application)
        self.assertEqual(campaign.screening_published_at, published_at)
        self.assertEqual(campaign.identities_revealed_at, published_at)
        self.assertEqual(application.interview_at, datetime(2026, 11, 16, 10))
        self.assertEqual(application.interview_end_at, datetime(2026, 11, 16, 10, 20))
        self.assertEqual(application.status, "interview_scheduled")
        for path in ("/api/recruitment/campaigns/public", "/api/recruitment/campaigns/timeline"):
            result = self.client.get(path)
            self.assertEqual(result.status_code, 200, result.text)
            self.assertNotIn(str(campaign.id), result.text)
        self.post("/applications", dict(self.application_payload(campaign), email="new-candidate@example.org"), 409)
        tracking = self.post("/applications/track", {
            "application_id": applications[0]["tracking_code"], "email": applications[0]["email"],
        })
        self.assertEqual(tracking["selection_schedule"], {key: revised[key] for key in PUBLIC_PLAN})
        self.assertEqual(tracking["status"], "interview_scheduled")
        self.assertEqual(self.db.query(EmailDelivery).count(), 0)
        audit = self.db.query(AuditLog).filter_by(action="planning_recrutement", entity_id=campaign.id).order_by(AuditLog.created_at.desc()).first()
        self.assertEqual(audit.user_id, self.users["sg"].id)
        self.assertEqual(audit.old_value, NOVEMBER_PLAN)
        self.assertEqual(audit.new_value, revised)

    def test_interviews_stay_in_the_announced_window_and_final_results_wait_until_november_24(self):
        campaign, applications, members = self.prepare()
        self.complete_screening(campaign, applications)
        self.post(f"/campaigns/{campaign.id}/selection/planning", NOVEMBER_PLAN)
        self.db.refresh(campaign)
        campaign.screening_published_at = datetime(2026, 11, 15)
        application = self.db.get(Application, UUID(applications[0]["id"]))
        application.screening_decision = "shortlisted"
        self.db.commit()
        for day, expected in ((15, 422), (22, 422), (16, 200)):
            self.post(f"/applications/{application.id}/interview", {
                "interview_at": f"2026-11-{day}T10:00:00Z", "interview_end_at": f"2026-11-{day}T10:30:00Z",
                "interview_mode": "in_person", "interview_location": "ESP",
                "jury_member_ids": [str(member.id) for member in members[:2]],
            }, expected)
        for member in members[:2]:
            self.rate(applications[0], reviewer=member.user_id)
        self.as_user("sg")
        self.complete_personality(application)
        with patch.object(selection_service, "utc_now", return_value=datetime(2026, 11, 23)):
            self.post(f"/applications/{application.id}/selection-decision", {"stage": "interview", "decision": "accepted"})
            report = self.report(campaign)
            result = self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "interview", "revision": report["revision"]}, 409)
            self.assertIn("24/11/2026", result["detail"])
        with patch.object(selection_service, "utc_now", return_value=datetime(2026, 11, 24)), patch.object(
            settings, "EMAIL_ENABLED", True
        ), patch.object(settings, "SMTP_HOST", "smtp.example.test"):
            self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "interview", "revision": report["revision"]})
        self.db.refresh(application)
        self.assertEqual(application.status, "accepted")
        self.db.refresh(campaign)
        published_at = campaign.final_published_at
        mail_count = self.db.query(EmailDelivery).count()
        report = self.post(f"/campaigns/{campaign.id}/selection/planning", dict(NOVEMBER_PLAN, final_results="2026-12-01"))
        self.db.refresh(campaign)
        self.assertEqual(campaign.final_published_at, published_at)
        repeated = self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "interview", "revision": report["revision"]})
        self.assertTrue(repeated["already_published"])
        self.assertEqual(self.db.query(EmailDelivery).count(), mail_count)
        tracking = self.post("/applications/track", {"application_id": application.tracking_code, "email": application.email})
        self.assertEqual(tracking["status"], "accepted")
        self.assertNotIn("final_results", tracking["selection_schedule"])
        self.assertEqual(self.report(campaign)["selection_schedule"]["final_results"], "2026-12-01")

    def test_candidates_cannot_read_internal_calendar_dates_from_public_endpoints(self):
        campaign, applications, _ = self.prepare()
        self.post(f"/campaigns/{campaign.id}/selection/planning", NOVEMBER_PLAN)
        self.assertEqual(self.report(campaign)["selection_schedule"], NOVEMBER_PLAN)
        with patch.object(recruitment_routes, "utc_now", return_value=datetime(2026, 11, 6, 12)):
            timeline = self.client.get("/api/recruitment/campaigns/timeline")
            public = self.client.get("/api/recruitment/campaigns/public")
            tracking = self.post("/applications/track", {
                "application_id": applications[0]["tracking_code"], "email": applications[0]["email"],
            })
        self.assertEqual(timeline.status_code, 200, timeline.text)
        self.assertEqual(public.status_code, 200, public.text)
        self.assertEqual(timeline.json()["campaigns"][0]["selection_schedule"], PUBLIC_PLAN)
        self.assertEqual(tracking["selection_schedule"], PUBLIC_PLAN)
        serialized = timeline.text + public.text + json.dumps(tracking)
        for key in set(NOVEMBER_PLAN) - set(PUBLIC_PLAN):
            self.assertNotIn(key, serialized)

    def test_new_campaign_uses_the_blind_policy(self):
        self.as_user("sg")
        result = self.post("/campaigns", {"title": "A new selection"})
        campaign = self.db.get(RecruitmentCampaign, UUID(result["id"]))
        self.assertEqual(campaign.selection_policy_version, POLICY_VERSION)
        self.assertTrue(result["eligibility_required"])

    def test_terminal_years_three_clubs_missing_count_and_forged_types_are_rejected(self):
        campaign, _, _ = self.prepare(count=0)
        original = self.application_payload(campaign)
        for level in ("DIC3", "DIC 3", "Master2", "Master 2", "DESCAF3", "DESCFAF3", "DIT2"):
            self.post("/applications", dict(original, study_level=level, other_clubs_count=0), 422)
        for count in (3, 9, -1, True, "2", 2.5):
            self.post("/applications", dict(original, other_clubs_count=count), 422)
        missing = dict(original)
        missing.pop("other_clubs_count", None)
        self.post("/applications", missing, 422)
        self.assertEqual(self.db.query(Application).count(), 0)
        self.post("/applications", dict(original, other_clubs_count=2))

    def test_identity_and_every_file_endpoint_are_blocked_for_managers_before_first_publication(self):
        campaign, _, _ = self.prepare(count=0)
        body = dict(self.application_payload(campaign), other_clubs_count=0)
        response = self.client.post("/api/recruitment/applications/with-files",
            data={"payload": json.dumps(body)},
            files={"cv": ("identite.pdf", fixture.PDF), "attachment": ("lettre.pdf", fixture.PDF)})
        self.assertEqual(response.status_code, 200, response.text)
        application = response.json()
        for actor in ("admin", "tl", "sg"):
            self.as_user(actor)
            result = self.client.get(f"/api/recruitment/applications/{application['id']}?anonymized=false")
            self.assertEqual(result.status_code, 200, result.text)
            data = result.json()
            self.assertTrue(data["is_anonymized"])
            self.assertIsNone(data["cv_url"])
            self.assertNotIn(body["email"], result.text)
            self.assertIsNone(data["gender"])
            self.assertIsNone(data["study_level"])
            for key in ("cv_url", "attachment_url"):
                url = application[key]
                for path in (url, url.removesuffix("/download"), url.replace("/download", "/preview")):
                    self.assertEqual(self.client.get(path).status_code, 403)
            self.post(f"/campaigns/{campaign.id}/selection/reveal", code=409)
        self.assertFalse(any(body["first_name"] in row.message or body["email"] in row.message
                             for row in self.db.query(Notification).filter_by(type="application_received")))

    def test_blind_submissions_require_private_uploads_instead_of_document_links(self):
        campaign, _, _ = self.prepare(count=0)
        body = self.application_payload(campaign)
        for field in ("cv_url", "motivation_letter_url", "attachment_url"):
            self.post("/applications", dict(body, **{field: "https://example.org/identite.pdf"}), 422)
        self.assertEqual(self.db.query(Application).count(), 0)

    def test_guessing_identity_in_search_or_export_does_not_identify_a_blind_dossier(self):
        campaign, applications, _ = self.prepare()
        app = applications[0]
        self.as_user("sg")
        found = self.client.get("/api/recruitment/applications", params={"search": app["first_name"]})
        self.assertEqual(found.status_code, 200, found.text)
        self.assertEqual(found.json(), [])
        exported = self.client.get("/api/recruitment/applications/export.csv")
        self.assertEqual(exported.status_code, 200)
        self.assertNotIn(app["email"], exported.text)
        self.assertNotIn(app["first_name"], exported.text)
        detail = self.client.get(f"/api/recruitment/applications/{app['id']}").json()
        results = self.client.get("/api/recruitment/applications", params={"search": detail["anonymous_code"]})
        self.assertEqual([row["id"] for row in results.json()], [app["id"]])

    def test_dashboard_recent_activity_also_hides_candidate_names_until_the_authorized_reveal(self):
        from app.api.routes import dashboard
        self.client.app.include_router(dashboard.router, prefix="/api")
        campaign, applications, _ = self.prepare()
        full_name = applications[0]["first_name"] + " " + applications[0]["last_name"]
        for actor in ("admin", "tl", "sg"):
            self.as_user(actor)
            response = self.client.get("/api/dashboard/summary")
            self.assertEqual(response.status_code, 200, response.text)
            self.assertNotIn(full_name, response.text)
            self.assertIn("Candidat #", response.text)
        self.db.refresh(campaign)
        campaign.screening_published_at = utc_now()
        self.db.commit()
        self.post(f"/campaigns/{campaign.id}/selection/reveal")
        self.assertIn(full_name, self.client.get("/api/dashboard/summary").text)

    def test_answers_are_masked_without_exposing_name_guesses_in_jury_observations(self):
        from app.services.recruitment_selection import redact_candidate_text
        campaign, applications, _ = self.prepare()
        application = self.db.get(Application, UUID(applications[0]["id"]))
        application.first_name = "Aïta Ndir"
        application.last_name = "DIOP"
        self.db.commit()
        cleaned = redact_candidate_text(
            "Aita, Ndir et Diop. Contact candidate-0@example.org, +221 77 123 45 67, https://example.org/profil",
            application,
        )
        for text in ("Aita", "Ndir", "Diop", "candidate-0@example.org", "77 123", "https://"):
            self.assertNotIn(text, cleaned)
        self.assign(campaign)
        assigned = self.db.query(ApplicationScreeningAssignment).first()
        self.acting = self.db.get(User, assigned.reviewer_id)
        note = assessment()
        note["ratings"][0]["evidence"] = "Aita ou Fatou propose de travailler en équipe."
        result = self.post("/reviews", {"application_id": applications[0]["id"], "criteria_assessment": note})
        # A private identifier must never be tested against text chosen by its author.
        self.assertEqual(result["criteria_assessment"]["ratings"][0]["evidence"], note["ratings"][0]["evidence"])
        own = self.client.get(f"/api/recruitment/applications/{application.id}/reviews").json()[0]
        self.assertEqual(own["criteria_assessment"]["ratings"][0]["evidence"], note["ratings"][0]["evidence"])
        self.as_user("sg")
        peer = self.client.get(f"/api/recruitment/applications/{application.id}/reviews").json()[0]
        self.assertNotIn("Aita", json.dumps(peer))
        self.assertNotIn("Fatou", json.dumps(peer))
        self.assertEqual(peer["criteria_assessment"]["ratings"][0]["evidence"], "")
        detail = self.client.get(f"/api/recruitment/applications/{application.id}")
        self.assertNotIn("Aita", detail.text)
        for field, value in (("motivation", "Aita ou Fatou"), ("public_comment", "Aita ou Fatou"), ("phone", "771234567")):
            response = self.client.patch(f"/api/recruitment/applications/{application.id}", json={field: value})
            self.assertEqual(response.status_code, 409, response.text)

    def test_admin_cannot_rewrite_another_juror_observations_during_anonymity(self):
        campaign, applications, members = self.prepare(jurors=1)
        self.db.add(RecruitmentJuryMember(campaign_id=campaign.id, user_id=self.users["admin"].id))
        self.db.commit()
        self.assign(campaign)
        note = self.rate(applications[0], reviewer=members[0].user_id)
        self.as_user("admin")
        response = self.client.patch(f"/api/recruitment/reviews/{note['id']}", json={"comment": "Aita ou Fatou"})
        self.assertEqual(response.status_code, 403, response.text)
        self.assertEqual(self.client.delete(f"/api/recruitment/reviews/{note['id']}").status_code, 403)

    def test_first_filter_then_authorized_reveal_unlocks_files_for_authorities_only(self):
        campaign, _, _ = self.prepare(count=0)
        body = dict(self.application_payload(campaign), other_clubs_count=0)
        response = self.client.post("/api/recruitment/applications/with-files",
            data={"payload": json.dumps(body)}, files={"cv": ("cv.pdf", fixture.PDF)})
        self.assertEqual(response.status_code, 200, response.text)
        application = response.json()
        self.as_user("sg")
        self.assertEqual(self.client.get(application["cv_url"]).status_code, 403)
        self.db.refresh(campaign)
        campaign.screening_published_at = utc_now()
        self.db.commit()
        self.assertEqual(self.client.get(application["cv_url"]).status_code, 403)
        self.post(f"/campaigns/{campaign.id}/selection/reveal")
        self.assertEqual(self.client.get(application["cv_url"]).content, fixture.PDF)
        self.as_user("veille")
        self.assertEqual(self.client.get(application["cv_url"]).status_code, 403)
        from app.models.pole import PoleMember
        membership = self.db.query(PoleMember).filter_by(user_id=self.users["veille"].id, pole_id=self.watch.id).one()
        for position in ("chef_pole", "adjoint_chef_pole"):
            membership.position = position
            self.db.commit()
            self.post(f"/campaigns/{campaign.id}/selection/reveal")
            self.assertEqual(self.client.get(application["cv_url"]).content, fixture.PDF)

    def test_revealed_identity_and_documents_are_available_to_the_whole_active_campaign_jury(self):
        campaign, _, _ = self.prepare(count=0)
        body = self.application_payload(campaign)
        response = self.client.post("/api/recruitment/applications/with-files",
            data={"payload": json.dumps(body)}, files={"cv": ("cv.pdf", fixture.PDF)})
        self.assertEqual(response.status_code, 200, response.text)
        application = response.json()
        self.as_user("sg")
        member = self.post(f"/campaigns/{campaign.id}/jury", {"user_id": str(self.users['b'].id)})
        self.db.refresh(campaign)
        campaign.screening_published_at = utc_now()
        self.db.commit()
        self.as_user("b")
        self.assertEqual(self.client.get(application['cv_url']).status_code, 403)
        self.as_user("sg")
        self.post(f"/campaigns/{campaign.id}/selection/reveal")
        self.as_user("b")
        detail = self.client.get(f"/api/recruitment/applications/{application['id']}")
        self.assertEqual(detail.status_code, 200, detail.text)
        self.assertFalse(detail.json()['is_anonymized'])
        self.assertEqual(detail.json()['email'], body['email'])
        self.assertEqual(detail.json()['study_level'], body['study_level'])
        self.assertNotEqual(detail.json()['tracking_code'], application['tracking_code'])
        self.assertNotIn(application['tracking_code'], detail.text)
        self.assertEqual(self.client.get(application['cv_url']).content, fixture.PDF)
        listing = self.client.get('/api/recruitment/applications').json()
        self.assertIn(application['id'], [item['id'] for item in listing])
        self.post('/reviews', {'application_id': application['id'], 'criteria_assessment': assessment()}, 403)
        self.as_user('sg')
        revoked = self.client.delete(f"/api/recruitment/campaigns/{campaign.id}/jury/{member['id']}")
        self.assertEqual(revoked.status_code, 200, revoked.text)
        self.as_user('b')
        self.assertEqual(self.client.get(application['cv_url']).status_code, 403)

    def test_unassigned_juror_cannot_read_or_evaluate_a_dossier(self):
        campaign, applications, members = self.prepare(jurors=4)
        self.assign(campaign)
        application = applications[0]
        selected = {row.reviewer_id for row in self.db.query(ApplicationScreeningAssignment)}
        outsider = next(member.user_id for member in members if member.user_id not in selected)
        self.acting = self.db.get(User, outsider)
        self.assertEqual(self.client.get(f"/api/recruitment/applications/{application['id']}").status_code, 403)
        self.post("/reviews", {"application_id": application["id"], "criteria_assessment": assessment()}, 403)

    def test_internal_id_and_guessed_email_cannot_unmask_a_blind_candidate(self):
        campaign, applications, _ = self.prepare()
        application = applications[0]
        self.as_user("sg")
        for reference in (application["id"], UUID(application["id"]).hex):
            self.post("/applications/track", {
                "application_id": reference, "email": application["email"],
            }, 404)
        tracked = self.post("/applications/track", {
            "application_id": application["tracking_code"], "email": application["email"],
        })
        self.assertEqual(tracked["application_id"], application["id"])

    def test_declining_a_dossier_reassigns_it_and_excludes_the_previous_grade(self):
        campaign, applications, _ = self.prepare()
        self.assign(campaign)
        application = applications[0]
        first = self.db.query(ApplicationScreeningAssignment).first()
        self.rate(application, reviewer=first.reviewer_id)
        self.post(f"/applications/{application['id']}/selection/decline", {
            "reason": "recognition",
        })
        self.assertEqual(self.client.get(f"/api/recruitment/applications/{application['id']}").status_code, 403)
        self.as_user("sg")
        report = self.report(campaign)
        self.assertEqual(report["rows"][0]["review_count"], 0)
        self.assertEqual(self.db.query(ApplicationReview).count(), 1)
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).filter_by(declined_at=None).count(), 2)

    def test_five_hundred_dossiers_are_balanced_without_duplicates_on_retry(self):
        campaign, _, members = self.prepare(count=0, jurors=20)
        for index in range(500):
            self.db.add(Application(
                campaign_id=campaign.id, first_name="Candidate", last_name="Synthetic",
                email=f"load-{index}@example.test", gender="non_precise", phone="770000000",
                department="GE", study_level="DIC1", other_clubs_count=0, status="submitted",
            ))
        self.db.commit()
        result = self.assign(campaign)
        self.assertEqual(result["created"], 1000)
        self.assertEqual(result["unfilled"], 0)
        self.assertEqual({row["assigned_count"] for row in result["loads"]}, {50})
        self.assertEqual(self.assign(campaign)["created"], 0)
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).count(), 1000)

    def test_disagreement_adds_a_third_independent_assignment(self):
        campaign, applications, _ = self.prepare()
        self.assign(campaign)
        application = applications[0]
        assigned = self.db.query(ApplicationScreeningAssignment).all()
        self.rate(application, 1, assigned[0].reviewer_id)
        self.rate(application, 4, assigned[1].reviewer_id)
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).count(), 3)
        self.as_user("sg")
        report = self.report(campaign)
        self.assertEqual(report["rows"][0]["required_reviews"], 3)
        self.assertFalse(report["rows"][0]["ready"])

    def test_publication_is_atomic_for_both_outcomes_and_retry_has_no_duplicate_emails(self):
        campaign, applications, _ = self.prepare(count=2)
        self.complete_screening(campaign, applications)
        for application, decision in zip(applications, ("shortlisted", "not_shortlisted")):
            self.post(f"/applications/{application['id']}/selection-decision", {"stage": "screening", "decision": decision})
            before = self.post("/applications/track", {"application_id": application["tracking_code"], "email": application["email"]})
            self.assertIsNone(before["screening_result"])
            self.assertNotEqual(before["status"], "rejected")
        report = self.report(campaign)
        payload = {"stage": "screening", "revision": report["revision"]}
        self.post(f"/campaigns/{campaign.id}/selection/publish", payload, 409)
        self.db.refresh(campaign)
        campaign.is_active = False
        self.db.commit()
        with patch.object(settings, "EMAIL_ENABLED", True), patch.object(settings, "SMTP_HOST", "smtp.example.test"):
            result = self.post(f"/campaigns/{campaign.id}/selection/publish", payload)
            again = self.post(f"/campaigns/{campaign.id}/selection/publish", payload)
        self.assertFalse(result["already_published"])
        self.assertTrue(again["already_published"])
        deliveries = self.db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like("recruitment-results:%")).all()
        self.assertEqual(len(deliveries), 2)
        from app.models.recruitment import ApplicationPersonality
        self.assertEqual(self.db.query(ApplicationPersonality).count(), 1)
        self.assertEqual(self.db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like("personality-invite:%")).count(), 1)
        self.assertEqual(len({delivery.next_attempt_at for delivery in deliveries}), 1)
        for application, outcome in zip(applications, ("shortlisted", "not_shortlisted")):
            tracking = self.post("/applications/track", {"application_id": application["tracking_code"], "email": application["email"]})
            self.assertEqual(tracking["screening_result"], outcome)
            if outcome == "shortlisted":
                self.assertIn("retenu", tracking["candidate_message"])
                self.assertNotIn("en cours d'étude", tracking["next_step"])
            else:
                self.assertIn("présélection", tracking["final_result"])
        self.assertEqual(self.db.query(Application).filter_by(status="rejected").count(), 1)

    def test_a_failure_preparing_the_second_mail_rolls_back_the_entire_publication(self):
        from app.services.email_delivery_service import enqueue_email_delivery
        campaign, applications, _ = self.prepare(count=2)
        self.complete_screening(campaign, applications)
        for application, decision in zip(applications, ("shortlisted", "not_shortlisted")):
            self.post(f"/applications/{application['id']}/selection-decision", {"stage": "screening", "decision": decision})
        self.db.refresh(campaign)
        campaign.is_active = False
        self.db.commit()
        report = self.report(campaign)
        calls = 0
        def fail_second_mail(*args, **kwargs):
            nonlocal calls
            calls += 1
            return enqueue_email_delivery(*args, **kwargs) if calls == 1 else None
        with patch.object(settings, "EMAIL_ENABLED", True), patch.object(settings, "SMTP_HOST", "smtp.example.test"), patch(
            "app.services.email_delivery_service.enqueue_email_delivery", side_effect=fail_second_mail,
        ):
            self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "screening", "revision": report["revision"]}, 409)
        self.db.expire_all()
        self.assertIsNone(self.db.get(RecruitmentCampaign, campaign.id).screening_published_at)
        self.assertEqual({row.status for row in self.db.query(Application)}, {"under_review"})
        self.assertEqual(self.db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like("recruitment-results:%")).count(), 0)

    def test_manual_status_changes_cannot_announce_a_result_or_close_a_blind_dossier_early(self):
        _, applications, _ = self.prepare()
        application = applications[0]
        self.as_user("sg")
        self.post(f"/applications/{application['id']}/status", {"status": "under_review"})
        with patch.object(settings, "EMAIL_ENABLED", True), patch.object(settings, "SMTP_HOST", "smtp.example.test"):
            for status in ("accepted", "rejected", "waiting_list", "cancelled"):
                self.post(f"/applications/{application['id']}/status", {"status": status}, 409)
                result = self.client.patch(f"/api/recruitment/applications/{application['id']}", json={"status": status})
                self.assertEqual(result.status_code, 409, result.text)
        self.db.expire_all()
        self.assertEqual(self.db.get(Application, UUID(application["id"])).status, "under_review")
        self.assertEqual(self.db.query(EmailDelivery).count(), 0)

    def test_result_publication_refuses_to_redirect_the_cohort_mail_to_a_test_address(self):
        campaign, applications, _ = self.prepare()
        self.complete_screening(campaign, applications)
        self.post(f"/applications/{applications[0]['id']}/selection-decision", {"stage": "screening", "decision": "not_shortlisted"})
        self.db.refresh(campaign)
        campaign.is_active = False
        self.db.commit()
        report = self.report(campaign)
        with patch.object(settings, "EMAIL_ENABLED", True), patch.object(settings, "SMTP_HOST", "smtp.example.test"), patch.object(
            settings, "EMAIL_RESTRICT_TO_TEST_RECIPIENT", True
        ), patch.object(settings, "EMAIL_TEST_RECIPIENT", "test-recipient@example.org"):
            result = self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "screening", "revision": report["revision"]}, 409)
            self.assertIn("redirection", result["detail"])
        self.db.expire_all()
        self.assertIsNone(self.db.get(RecruitmentCampaign, campaign.id).screening_published_at)
        self.assertEqual(self.db.query(EmailDelivery).count(), 0)

    def test_incomplete_reviews_missing_decisions_and_stale_report_block_publication(self):
        campaign, applications, _ = self.prepare()
        campaign.is_active = False
        self.db.commit()
        report = self.report(campaign)
        self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "screening", "revision": report["revision"]}, 409)
        self.complete_screening(campaign, applications)
        self.post(f"/applications/{applications[0]['id']}/selection-decision", {"stage": "screening", "decision": "shortlisted"})
        self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "screening", "revision": report["revision"]}, 409)
        self.assertEqual(self.db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like("recruitment-results:%")).count(), 0)

    def test_reveal_requires_first_publication_and_a_privileged_role(self):
        campaign, applications, members = self.prepare()
        self.complete_screening(campaign, applications)
        self.post(f"/campaigns/{campaign.id}/selection/reveal", code=409)
        self.db.refresh(campaign)
        campaign.screening_published_at = utc_now()
        self.db.commit()
        self.acting = self.db.get(User, members[0].user_id)
        self.post(f"/campaigns/{campaign.id}/selection/reveal", code=403)
        self.as_user("veille")
        self.post(f"/campaigns/{campaign.id}/selection/reveal", code=403)
        for role in ("sg", "tl", "admin"):
            self.as_user(role)
            self.post(f"/campaigns/{campaign.id}/selection/reveal")
            result = self.client.get(f"/api/recruitment/applications/{applications[0]['id']}").json()
            self.assertFalse(result["is_anonymized"])

    def test_interview_reviews_are_separate_and_final_decisions_stay_hidden_until_the_lot(self):
        campaign, applications, members = self.prepare()
        self.complete_screening(campaign, applications)
        application = self.db.get(Application, UUID(applications[0]["id"]))
        self.db.refresh(campaign)
        campaign.screening_published_at = utc_now()
        application.screening_decision = "shortlisted"
        application.status = "interview_scheduled"
        application.interview_at = utc_now() - timedelta(hours=1)
        for member in members[:2]:
            self.db.add(ApplicationInterviewJuror(application_id=application.id, jury_member_id=member.id))
        self.db.commit()
        for member in members[:2]:
            self.rate(applications[0], reviewer=member.user_id)
        self.assertEqual(self.db.query(ApplicationReview).filter_by(application_id=application.id).count(), 4)
        self.as_user("sg")
        self.post(f"/applications/{application.id}/selection-decision", {"stage": "interview", "decision": "accepted"}, 409)
        self.complete_personality(application)
        self.post(f"/applications/{application.id}/selection-decision", {"stage": "interview", "decision": "accepted"})
        tracked = self.post("/applications/track", {"application_id": applications[0]["tracking_code"], "email": applications[0]["email"]})
        self.assertEqual(tracked["status"], "interview_scheduled")
        campaign.is_active = False
        self.db.commit()
        report = self.report(campaign)
        with patch.object(settings, "EMAIL_ENABLED", True), patch.object(settings, "SMTP_HOST", "smtp.example.test"):
            self.db.refresh(application)
            application.interview_at = utc_now() + timedelta(days=1)
            self.db.commit()
            self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "interview", "revision": report["revision"]}, 409)
            self.assertEqual(self.db.query(EmailDelivery).filter(EmailDelivery.dedupe_key.like("recruitment-results:%")).count(), 0)
            application.interview_at = utc_now() - timedelta(hours=1)
            self.db.commit()
            self.post(f"/campaigns/{campaign.id}/selection/publish", {"stage": "interview", "revision": report["revision"]})
        tracked = self.post("/applications/track", {"application_id": applications[0]["tracking_code"], "email": applications[0]["email"]})
        self.assertEqual(tracked["status"], "accepted")
