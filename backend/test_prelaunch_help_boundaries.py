"""Synthetic HTTP regressions for onboarding help, private support and triage."""
import unittest
import uuid
from datetime import timedelta
from unittest.mock import patch
from app.api.routes import product_services as product
from app.models.product_services import SupportTicket, SupportTicketMessage, ProductFeedback
from app.models.audit import AuditLog
from app.models.notification import Notification
from app.models.email_delivery import EmailDelivery
from app.models.role import UserRole
from app.core.time import utc_now
from app.core.config import settings
import test_prelaunch_first_access as fixture

class HelpBoundariesTests(unittest.TestCase):
    make_engine=fixture.FirstAccessTests.make_engine
    tearDown=fixture.FirstAccessTests.tearDown
    call=fixture.FirstAccessTests.call
    def setUp(self):
        fixture.FirstAccessTests.setUp(self)
        self.user.credential_setup_required=False
        self.user.email_verified=True
        self.user.onboarding_required=False
        self.db.commit()
        for router in (product.support_router,product.support_admin_router,product.feedback_router,product.feedback_admin_router):
            self.client.app.include_router(router,prefix="/api")
    def ticket(self,**changes):
        data=dict(subject="Academy ne répond pas",category="technical",priority="normal",
                  message="En ouvrant un cours, le quiz reste indisponible.",client_request_id=str(uuid.uuid4()))
        data.update(changes)
        return self.call("POST","support/tickets",data,201,actor=self.user).json()
    def feedback(self,**changes):
        data=dict(category="idea",message="Ajouter un repère pour retrouver les prochains cours.",client_request_id=str(uuid.uuid4()))
        data.update(changes)
        return self.call("POST","feedback",data,201,actor=self.user).json()
    def test_ticket_create_and_personal_conversation(self):
        item=self.ticket()
        self.assertNotIn("submission_hash",item)
        detail=self.call("GET","support/tickets/"+item["id"],actor=self.user).json()
        self.assertEqual(len(detail["messages"]),1)
        self.assertEqual(detail["requester_name"],"Synthetic Member")
        self.call("POST","support/tickets/"+item["id"]+"/messages",{"message":"Le problème apparaît sur mon téléphone."},201,actor=self.user)
        self.assertEqual(len(self.call("GET","support/tickets/"+item["id"],actor=self.user).json()["messages"]),2)
    def test_other_member_cannot_read_reply_or_manage(self):
        item=self.ticket();feedback=self.feedback()
        self.call("GET","support/tickets/"+item["id"],code=404,actor=self.other)
        self.call("POST","support/tickets/"+item["id"]+"/messages",{"message":"Intrusion"},404,actor=self.other)
        self.call("GET","feedback/"+feedback["id"],code=404,actor=self.other)
        for path in ("admin/support/tickets","admin/support/tickets/"+item["id"],"admin/feedback","admin/feedback/"+feedback["id"]):
            self.call("GET",path,code=403,actor=self.other)
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":"closed"},403,actor=self.other)
        self.call("PATCH","admin/feedback/"+feedback["id"],{"status":"closed"},403,actor=self.other)
    def test_legacy_alumni_staff_role_has_no_management_access(self):
        self.sg.status="alumni";self.sg.profile_type="alumni";self.db.commit()
        self.call("GET","admin/support/tickets",code=403,actor=self.sg)
        self.call("GET","admin/feedback",code=403,actor=self.sg)
    def test_alumni_can_use_own_support_and_feedback(self):
        self.user.status="alumni";self.user.profile_type="alumni";self.db.commit()
        item=self.ticket();feedback=self.feedback()
        self.call("GET","support/tickets/"+item["id"],actor=self.user)
        self.call("GET","feedback/"+feedback["id"],actor=self.user)
    def test_unavailable_or_inconsistent_accounts_are_rejected(self):
        for status,kind,active,verified in [
            ("suspended","enacteur",True,True),("pending","enacteur",True,True),
            ("active","alumni",True,True),("active","enacteur",False,True),
            ("active","enacteur",True,False)]:
            self.user.status=status;self.user.profile_type=kind;self.user.is_active=active;self.user.email_verified=verified;self.db.commit()
            self.call("POST","feedback",{"category":"bug","message":"Erreur"},403,actor=self.user)
    def test_malformed_ids_are_human_errors_not_server_errors(self):
        self.call("GET","support/tickets/bad",code=404,actor=self.user)
        self.call("GET","feedback/bad",code=404,actor=self.user)
        self.call("GET","admin/support/tickets/bad",code=404,actor=self.sg)
    def test_blank_overlong_and_malformed_submissions_rejected(self):
        for data in ({"subject":" ","message":"texte"},{"subject":"x"*201,"message":"texte"},{"subject":"Sujet","message":"x"*10001},{"subject":"Sujet","message":"texte","client_request_id":"bad"}):
            self.call("POST","support/tickets",data,422,actor=self.user)
        for data in ({"category":"bug","message":" "},{"category":"bad","message":"texte"},{"category":"bug","message":"texte","rating":6}):
            self.call("POST","feedback",data,422,actor=self.user)
        self.assertEqual(self.db.query(SupportTicket).count(),0)
    def test_ticket_retry_is_single_submission_and_collision_is_rejected(self):
        key=str(uuid.uuid4());first=self.ticket(client_request_id=key)
        notices=self.db.query(Notification).count()
        second=self.ticket(client_request_id=key)
        self.assertEqual(first["id"],second["id"]);self.assertEqual(self.db.query(SupportTicket).count(),1)
        self.assertEqual(self.db.query(Notification).count(),notices)
        self.assertEqual(self.db.query(AuditLog).filter_by(action="support_ticket_created").count(),1)
        self.call("POST","support/tickets",{"subject":"Autre","message":"Autre contenu","client_request_id":key},409,actor=self.user)
    def test_feedback_retry_is_single_submission(self):
        key=str(uuid.uuid4());first=self.feedback(client_request_id=key);second=self.feedback(client_request_id=key)
        self.assertEqual(first["id"],second["id"]);self.assertEqual(self.db.query(ProductFeedback).count(),1)
        self.assertEqual(self.db.query(AuditLog).filter_by(action="product_feedback_created").count(),1)
    def test_reply_retry_is_single_message_and_preserves_ownership(self):
        item=self.ticket();key=str(uuid.uuid4())
        data={"message":"Une précision importante.","client_request_id":key}
        first=self.call("POST","support/tickets/"+item["id"]+"/messages",data,201,actor=self.user).json()
        second=self.call("POST","support/tickets/"+item["id"]+"/messages",data,201,actor=self.user).json()
        self.assertEqual(first["id"],second["id"]);self.assertEqual(self.db.query(SupportTicketMessage).count(),2)
        self.call("POST","support/tickets/"+item["id"]+"/messages",dict(data,message="Autre contenu"),409,actor=self.user)
    def test_manager_response_and_status_are_visible_to_author(self):
        item=self.ticket()
        self.call("POST","admin/support/tickets/"+item["id"]+"/messages",{"message":"Nous avons pris votre demande en charge."},201,actor=self.sg)
        updated=self.call("PATCH","admin/support/tickets/"+item["id"],
            {"status":"in_progress","assigned_to_id":str(self.sg.id),"expected_updated_at":self.call("GET","support/tickets/"+item["id"],actor=self.user).json()["updated_at"]},actor=self.sg).json()
        self.assertEqual(updated["status"],"in_progress")
        detail=self.call("GET","support/tickets/"+item["id"],actor=self.user).json()
        self.assertIn("pris votre demande",detail["messages"][-1]["message"])
        notices=self.db.query(Notification).filter_by(user_id=self.user.id,related_type="support_ticket").all()
        self.assertGreaterEqual(len(notices),2)
    def test_closed_ticket_rejects_member_reply_and_can_be_reopened(self):
        item=self.ticket()
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":"closed"},actor=self.sg)
        self.call("POST","support/tickets/"+item["id"]+"/messages",{"message":"Encore un problème"},409,actor=self.user)
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":"resolved"},409,actor=self.sg)
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":"open"},actor=self.sg)
        self.call("POST","support/tickets/"+item["id"]+"/messages",{"message":"Merci pour la réouverture."},201,actor=self.user)
    def test_reply_to_resolved_ticket_returns_it_to_progress(self):
        item=self.ticket()
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":"resolved"},actor=self.sg)
        self.call("POST","support/tickets/"+item["id"]+"/messages",{"message":"La difficulté persiste."},201,actor=self.user)
        detail=self.call("GET","support/tickets/"+item["id"],actor=self.user).json()
        self.assertEqual(detail["status"],"in_progress");self.assertIsNone(detail["resolved_at"])
    def test_assignment_requires_active_authorized_responsible(self):
        item=self.ticket()
        self.call("PATCH","admin/support/tickets/"+item["id"],{"assigned_to_id":str(self.other.id)},422,actor=self.sg)
        self.call("PATCH","admin/support/tickets/"+item["id"],{"assigned_to_id":str(uuid.uuid4())},422,actor=self.sg)
        self.db.expire_all();self.assertIsNone(self.db.get(SupportTicket,uuid.UUID(item["id"])).assigned_to_id)
    def test_stale_ticket_change_does_not_overwrite_new_state(self):
        item=self.ticket()
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":"in_progress","expected_updated_at":item["updated_at"]},actor=self.sg)
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":"closed","expected_updated_at":item["updated_at"]},409,actor=self.sg)
        self.assertEqual(self.call("GET","support/tickets/"+item["id"],actor=self.user).json()["status"],"in_progress")
    def test_public_reply_visible_but_internal_note_private_everywhere(self):
        item=self.feedback()
        self.call("PATCH","admin/feedback/"+item["id"],{"status":"planned","admin_note":"Private internal diagnosis","public_reply":"Cette amélioration est prévue.","expected_updated_at":item["updated_at"]},actor=self.sg)
        for path in ("feedback","feedback/"+item["id"]):
            response=self.call("GET",path,actor=self.user)
            self.assertNotIn("Private internal",response.text);self.assertNotIn("admin_note",response.text)
            self.assertIn("Cette amélioration",response.text)
        admin=self.call("GET","admin/feedback/"+item["id"],actor=self.sg).json()
        self.assertEqual(admin["admin_note"],"Private internal diagnosis")
        from app.services.account_service import build_user_data_export
        exported=build_user_data_export(self.db,self.user,"synthetic-test")
        encoded=__import__("json").dumps(exported,default=str,ensure_ascii=False)
        self.assertNotIn("Private internal diagnosis",encoded)
        self.assertNotIn("admin_note",encoded)
        self.assertIn("Cette amélioration est prévue.",encoded)
    def test_internal_note_only_does_not_notify_or_leak_into_notifications(self):
        item=self.feedback();before=self.db.query(Notification).count()
        self.call("PATCH","admin/feedback/"+item["id"],{"admin_note":"Private internal diagnosis"},actor=self.sg)
        self.assertEqual(self.db.query(Notification).count(),before)
        self.assertTrue(all("Private internal" not in (n.message or "") for n in self.db.query(Notification).all()))
    def test_feedback_transitions_and_stale_changes_are_guarded(self):
        item=self.feedback()
        update=self.call("PATCH","admin/feedback/"+item["id"],{"status":"closed","expected_updated_at":item["updated_at"]},actor=self.sg).json()
        self.call("PATCH","admin/feedback/"+item["id"],{"status":"planned"},409,actor=self.sg)
        self.call("PATCH","admin/feedback/"+item["id"],{"status":"reviewed","expected_updated_at":item["updated_at"]},409,actor=self.sg)
        self.call("PATCH","admin/feedback/"+item["id"],{"status":"reviewed","expected_updated_at":update["updated_at"]},actor=self.sg)
    def test_onboarding_member_can_get_help_without_access_to_activities(self):
        self.user.onboarding_required=True;self.db.commit()
        item=self.ticket();feedback=self.feedback()
        self.call("GET","support/tickets/"+item["id"],actor=self.user)
        self.call("POST","support/tickets/"+item["id"]+"/messages",{"message":"Je complète mon profil."},201,actor=self.user)
        self.call("GET","feedback/"+feedback["id"],actor=self.user)
        self.call("GET","activities",code=403,actor=self.user)
        self.call("GET","admin/support/tickets",code=403,actor=self.user)
    def test_creation_limits_reject_floods_without_discarding_saved_items(self):
        for _ in range(10):self.ticket()
        self.call("POST","support/tickets",{"subject":"Trop de demandes","message":"Une autre demande"},429,actor=self.user)
        self.assertEqual(self.db.query(SupportTicket).count(),10)
    def test_feedback_rate_limit_and_idempotent_retry_at_limit(self):
        first=self.feedback()
        for _ in range(19):self.feedback()
        self.call("POST","feedback",{"category":"bug","message":"Trop de remarques"},429,actor=self.user)
        self.assertEqual(self.db.query(ProductFeedback).count(),20)
    def test_message_rate_limit_preserves_conversation(self):
        item=self.ticket()
        for index in range(59):
            self.call("POST","support/tickets/"+item["id"]+"/messages",{"message":"Précision "+str(index)},201,actor=self.user)
        self.call("POST","support/tickets/"+item["id"]+"/messages",{"message":"Autre message"},429,actor=self.user)
        self.assertEqual(self.db.query(SupportTicketMessage).count(),60)
    def test_invalid_assignment_cannot_partially_change_status(self):
        item=self.ticket()
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":"closed","assigned_to_id":str(self.other.id)},422,actor=self.sg)
        detail=self.call("GET","support/tickets/"+item["id"],actor=self.user).json()
        self.assertEqual(detail["status"],"open")
    def test_changed_actor_state_is_checked_despite_stale_object(self):
        self.sg.status="alumni";self.sg.profile_type="alumni";self.db.commit()
        with self.assertRaises(Exception) as error:product.list_all_support_tickets(db=self.db,current_user=self.sg)
        self.assertEqual(error.exception.status_code,403)
    def test_queued_notifications_are_contained_in_test_mode(self):
        with patch.object(settings,"EMAIL_ENABLED",True),patch.object(settings,"SMTP_HOST","smtp.example.test"), \
             patch.object(settings,"EMAIL_RESTRICT_TO_TEST_RECIPIENT",True),patch.object(settings,"EMAIL_TEST_RECIPIENT","dioppylsci@gmail.com"):
            self.feedback()
        rows=self.db.query(EmailDelivery).all();self.assertTrue(rows)
        self.assertTrue(all(row.recipient_email=="dioppylsci@gmail.com" for row in rows))
    def test_no_authentication_no_help_submission(self):
        self.call("POST","feedback",{"category":"bug","message":"Sans connexion"},401)
    def test_null_management_fields_refused_without_mutation(self):
        item=self.ticket();feedback=self.feedback()
        self.call("PATCH","admin/support/tickets/"+item["id"],{"status":None},422,actor=self.sg)
        self.call("PATCH","admin/feedback/"+feedback["id"],{"status":None},400,actor=self.sg)
        self.assertEqual(self.call("GET","support/tickets/"+item["id"],actor=self.user).json()["status"],"open")

if __name__=="__main__":unittest.main()
