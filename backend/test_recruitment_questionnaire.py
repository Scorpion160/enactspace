import os
os.environ.setdefault('DATABASE_URL','sqlite://')
os.environ.setdefault('SECRET_KEY','questionnaire-test-secret')
os.environ.setdefault('APP_ENV','test')
import unittest
from unittest.mock import patch
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from fastapi import HTTPException
from pydantic import ValidationError
import app.models.base
from app.db.database import Base
from app.models.recruitment import RecruitmentCampaign,Application
from app.schemas.recruitment import ApplicationCreate,RecruitmentCampaignCreate,RecruitmentCampaignPublicRead
from app.api.routes import recruitment
from app.services.recruitment_questionnaire import questionnaire_version

class RecruitmentQuestionnaireTests(unittest.TestCase):
 def setUp(self):
  self.engine=create_engine('sqlite://');Base.metadata.create_all(self.engine);self.db=Session(self.engine)
  self.campaign=RecruitmentCampaign(title='Synthetic campaign',is_active=True,application_questions=[{'id':'why','label':'Why this cause?','hint':'','section':'motivation','required':True,'legacy_field':'motivation'}])
  self.db.add(self.campaign);self.db.commit()
 def tearDown(self):self.db.close();self.engine.dispose()
 def payload(self,**extra):
  return ApplicationCreate(campaign_id=self.campaign.id,first_name='Test',last_name='Candidate',email='candidate@example.com',gender='non_precise',phone='+221770000000',department='Génie Informatique',study_level='Master1',**extra)
 def submit(self,payload):
  with patch.object(recruitment,'notify_recruitment_responsibles'),patch.object(recruitment,'enqueue_email_delivery'):
   return recruitment.submit_application(payload,db=self.db)
 def test_required_unknown_and_stale_questionnaire(self):
  for extra,expected in [({'questionnaire_answers':{}},422),({'questionnaire_answers':{'why':'A','unknown':'B'}},422),({'questionnaire_answers':{'why':'A'},'questionnaire_version':'stale'},409)]:
   with self.assertRaises(HTTPException) as result:self.submit(self.payload(**extra))
   self.assertEqual(result.exception.status_code,expected)
  self.assertEqual(self.db.query(Application).count(),0)
 def test_snapshot_survives_campaign_edit_and_anonymization(self):
  data=self.submit(self.payload(questionnaire_answers={'why':'  A real motivation  '},questionnaire_version=questionnaire_version(self.campaign.application_questions)))
  application=self.db.query(Application).one()
  self.assertEqual(application.motivation,'A real motivation')
  self.campaign.application_questions=[];self.db.commit()
  self.assertEqual(application.questionnaire_answers,[{'id':'why','question':'Why this cause?','answer':'A real motivation'}])
  self.assertIsNone(recruitment.application_payload(self.db,None,application,anonymized=True)['questionnaire_answers'])
  self.assertTrue(data['tracking_code'])
 def test_defaults_empty_list_and_public_schema(self):
  self.campaign.application_questions=None;self.db.commit()
  public=RecruitmentCampaignPublicRead.model_validate(self.campaign)
  self.assertEqual(len(public.application_questions),12)
  self.assertNotIn('interview_questions',public.model_dump())
  self.campaign.application_questions=[];self.db.commit()
  self.assertEqual(RecruitmentCampaignPublicRead.model_validate(self.campaign).application_questions,[])
 def test_repeated_ids_and_mappings_rejected(self):
  q={'id':'one','label':'Question','legacy_field':'motivation'}
  for other in [q,dict(q,id='two')]:
   with self.assertRaises(ValidationError):RecruitmentCampaignCreate(title='Test',application_questions=[q,other])
 def test_old_clients_remain_compatible(self):
  result=self.submit(self.payload(motivation='Legacy answer'))
  self.assertEqual(result['motivation'],'Legacy answer')
  self.assertIsNone(result['questionnaire_answers'])
