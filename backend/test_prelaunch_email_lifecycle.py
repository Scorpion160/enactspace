"""Prelaunch containment and candidate lifecycle regressions, without SMTP."""
import os
os.environ.setdefault("DATABASE_URL","sqlite://")
os.environ.setdefault("SECRET_KEY","prelaunch-isolated-tests")
os.environ.setdefault("APP_ENV","test")
os.environ.setdefault("AUTO_CREATE_TABLES","false")
import unittest
from unittest.mock import patch
from datetime import datetime,timedelta
from types import SimpleNamespace
from fastapi import Request
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
import app.models.base
from app.db.database import Base
from app.core.config import settings
from app.models.email_delivery import EmailDelivery
from app.models.recruitment import Application,RecruitmentCampaign
from app.models.user import User
from app.models.notification import Notification
from app.services.email_provider import OutgoingEmail, SmtpEmailProvider, EmailProviderError, enforce_test_recipient
from app.services.email_delivery_service import claim_email_deliveries,process_email_delivery
from app.api.routes import recruitment
from app.schemas.recruitment import ApplicationStatusChange,ApplicationInterviewSchedule

class CaptureProvider:
    def __init__(self):self.messages=[]
    def send(self,message):self.messages.append(message);return message.message_id

class PrelaunchEmailTests(unittest.TestCase):
    def setUp(self):
        self.engine=create_engine("sqlite://")
        Base.metadata.create_all(self.engine)
        self.db=Session(self.engine)
        self.saved={name:getattr(settings,name) for name in
                    ("EMAIL_ENABLED","EMAIL_RESTRICT_TO_TEST_RECIPIENT","EMAIL_TEST_RECIPIENT","SMTP_HOST","PUSH_ENABLED")}
        settings.EMAIL_ENABLED=True
        settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT=True
        settings.EMAIL_TEST_RECIPIENT="dioppylsci@gmail.com"
        settings.SMTP_HOST="smtp.example.test"
        settings.PUSH_ENABLED=False
        self.actor=User(first_name="Synthetic",last_name="Responsible",email="actor@example.test",
                        password_hash="unused",status="active",is_active=True,email_verified=True)
        self.db.add(self.actor);self.db.flush()
        self.campaign=RecruitmentCampaign(title="ISOLATED QA",is_active=True)
        self.db.add(self.campaign);self.db.flush()
        self.request=Request({"type":"http","client":("127.0.0.1",1),"headers":[]})
    def tearDown(self):
        for name,value in self.saved.items():setattr(settings,name,value)
        self.db.close();self.engine.dispose()
    def application(self,status="under_review"):
        n=self.db.query(Application).count()
        app=Application(campaign_id=self.campaign.id,first_name="Candidate",last_name="Synthetic",
                        email=f"candidate-{n}@example.org",status=status,
                        tracking_code=f"QA-{n}-CODE",updated_at=datetime.now())
        self.db.add(app);self.db.commit()
        return app
    def process(self):
        provider=CaptureProvider()
        for delivery_id in claim_email_deliveries(self.db):process_email_delivery(self.db,delivery_id,provider)
        return provider.messages
    def test_old_queue_is_contained_at_send_time(self):
        row=EmailDelivery(recipient_email="outsider@example.test",subject="Legacy event",text_body="<script>bad</script>")
        self.db.add(row);self.db.commit()
        sent=self.process()
        self.assertEqual(sent[0].recipient,"dioppylsci@gmail.com")
        self.assertTrue(sent[0].subject.startswith("[TEST] "))
        self.assertNotIn("<script>",sent[0].html_body)
        self.db.refresh(row)
        self.assertEqual(row.recipient_email,sent[0].recipient)
    def test_missing_test_recipient_blocks_before_provider(self):
        row=EmailDelivery(recipient_email="outsider@example.test",subject="Legacy",text_body="Body")
        self.db.add(row);self.db.commit();settings.EMAIL_TEST_RECIPIENT=None
        provider=CaptureProvider()
        for delivery_id in claim_email_deliveries(self.db):process_email_delivery(self.db,delivery_id,provider)
        self.assertEqual(provider.messages,[])
        self.db.refresh(row);self.assertEqual(row.status,"dead")
        self.assertEqual(row.last_error_code,"test_recipient_invalid")
    def test_invalid_test_header_blocks_direct_smtp(self):
        settings.EMAIL_TEST_RECIPIENT="qa@example.org\nBcc:other@example.org"
        message=OutgoingEmail("outside@example.test","Subject","Body",None,"<qa@test>")
        with patch("app.services.email_provider.smtplib.SMTP") as smtp:
            with self.assertRaises(EmailProviderError):SmtpEmailProvider().send(message)
            smtp.assert_not_called()
    def test_guard_is_idempotent(self):
        message=OutgoingEmail("outside@example.test","Subject","Body",None,"<qa@test>")
        once=enforce_test_recipient(message);twice=enforce_test_recipient(once)
        self.assertEqual(once,twice)
        self.assertEqual(twice.subject.count("[TEST]"),1)
        self.assertEqual(twice.text_body.count("MODE DE TEST ENACTSPACE"),1)
    def test_real_mode_does_not_redirect(self):
        settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT=False
        message=OutgoingEmail("outside@example.test","Subject","Body",None,"<qa@test>")
        self.assertEqual(enforce_test_recipient(message),message)
    def test_each_candidate_transition_queues_a_message_without_account(self):
        for target in ["interview_scheduled","accepted","rejected","waiting_list","cancelled"]:
            with self.subTest(status=target):
                app=self.application()
                before=self.db.query(EmailDelivery).count()
                recruitment.change_application_status(str(app.id),ApplicationStatusChange(status=target),
                                                      self.request,self.db,self.actor)
                self.assertEqual(self.db.query(EmailDelivery).count(),before+1)
                row=self.db.query(EmailDelivery).order_by(EmailDelivery.created_at.desc()).first()
                self.assertEqual(row.recipient_email,"dioppylsci@gmail.com")
                self.assertIn(app.tracking_code,row.text_body)
                self.assertIn("/application-tracking",row.text_body)
    def test_repeated_status_does_not_duplicate_email(self):
        app=self.application()
        for i in range(2):
            recruitment.change_application_status(str(app.id),ApplicationStatusChange(status="accepted"),
                                                  self.request,self.db,self.actor)
        self.assertEqual(self.db.query(EmailDelivery).count(),1)
    def test_under_review_from_submission_notifies_candidate(self):
        app=self.application("submitted")
        recruitment.change_application_status(str(app.id),ApplicationStatusChange(status="under_review"),
                                              self.request,self.db,self.actor)
        self.assertEqual(self.db.query(EmailDelivery).count(),1)
    def test_interview_is_public_and_rescheduling_does_not_leak_notes(self):
        app=self.application()
        when=datetime.now()+timedelta(days=3)
        def schedule(location,note):
            recruitment.schedule_application_interview(str(app.id),ApplicationInterviewSchedule(
                interview_at=when,interview_location=location,interview_link="https://example.org/interview",
                interview_note=note,interview_jury="PRIVATE_JURY_SECRET"),
                self.request,self.db,self.actor)
        schedule("Salle A","PRIVATE_REVIEW_SECRET")
        first=self.db.query(EmailDelivery).first()
        self.assertIn("Salle A",first.text_body)
        self.assertIn("UTC",first.text_body)
        self.assertNotIn("PRIVATE_REVIEW_SECRET",first.text_body+first.html_body)
        self.assertNotIn("PRIVATE_JURY_SECRET",first.text_body+first.html_body)
        schedule("Salle A","UPDATED_PRIVATE_SECRET")
        self.assertEqual(self.db.query(EmailDelivery).count(),1)
        schedule("Salle B","UPDATED_PRIVATE_SECRET")
        self.assertEqual(self.db.query(EmailDelivery).count(),2)
        self.assertTrue(all("PRIVATE" not in row.text_body for row in self.db.query(EmailDelivery)))
    def test_linked_candidate_has_one_transactional_email_and_in_app_notification(self):
        app=self.application();app.converted_user_id=self.actor.id;self.db.commit()
        recruitment.notify_application_status(self.db,app);self.db.commit()
        self.assertEqual(self.db.query(EmailDelivery).count(),1)
        self.assertEqual(self.db.query(Notification).count(),1)
        self.assertIsNone(self.db.query(EmailDelivery).first().notification_id)

if __name__=="__main__":unittest.main()
