"""Selection schema supports both a fresh bootstrap and a deployed previous revision."""
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.email_delivery import EmailDelivery
from app.models.notification import Notification
from app.models.recruitment import Application, ApplicationReview, RecruitmentCampaign
from app.models.user import User


class RecruitmentSelectionMigrationTests(TestCase):
    def test_fresh_head_and_repeated_upgrade_preserve_the_selection_schema(self):
        with TemporaryDirectory() as directory:
            url = f"sqlite:///{Path(directory) / 'selection.sqlite3'}"
            config = Config("alembic.ini")
            engine = create_engine(url)
            self.addCleanup(engine.dispose)
            with patch.object(settings, "DATABASE_URL", url):
                command.upgrade(config, "head")
                command.upgrade(config, "head")
            inspector = inspect(engine)
            self.assertTrue(inspector.has_table("application_screening_assignments"))
            self.assertIn("selection_policy_version", {column["name"] for column in inspector.get_columns("recruitment_campaigns")})
            self.assertIn("stage", {column["name"] for column in inspector.get_columns("application_reviews")})
            with engine.connect() as connection:
                self.assertEqual(connection.execute(text("SELECT version_num FROM alembic_version")).scalar_one(), "20261106_0037")

    def test_previous_revision_upgrade_and_downgrade_are_reversible_without_reviews(self):
        with TemporaryDirectory() as directory:
            url = f"sqlite:///{Path(directory) / 'previous.sqlite3'}"
            config = Config("alembic.ini")
            engine = create_engine(url)
            self.addCleanup(engine.dispose)
            with patch.object(settings, "DATABASE_URL", url):
                command.upgrade(config, "head")
                command.downgrade(config, "20261104_0034")
                self.assertNotIn("selection_policy_version", {
                    column["name"] for column in inspect(engine).get_columns("recruitment_campaigns")
                })
                command.upgrade(config, "head")
                self.assertTrue(inspect(engine).has_table("application_screening_assignments"))

    def test_upgrade_preserves_announced_results_and_interviews_in_mixed_campaigns(self):
        with TemporaryDirectory() as directory:
            url = f"sqlite:///{Path(directory) / 'legacy.sqlite3'}"
            config = Config("alembic.ini")
            engine = create_engine(url)
            self.addCleanup(engine.dispose)
            with patch.object(settings, "DATABASE_URL", url):
                command.upgrade(config, "head")
                with Session(engine) as db:
                    actor = User(first_name="Synthetic", last_name="Juror", email="juror@example.org", password_hash="unused")
                    mixed = RecruitmentCampaign(title="Mixed campaign", is_active=True)
                    interviews = RecruitmentCampaign(title="Interviews started", is_active=True)
                    historical = RecruitmentCampaign(title="Completed campaign", is_active=False)
                    db.add_all([actor, mixed, interviews, historical])
                    db.flush()
                    def candidate(campaign, status, index):
                        row = Application(campaign_id=campaign.id, first_name="Candidate", last_name="Synthetic",
                                          email=f"candidate-{index}@example.org", status=status)
                        db.add(row)
                        db.flush()
                        return row
                    pending = candidate(mixed, "submitted", 1)
                    accepted = candidate(mixed, "accepted", 2)
                    interviewing = candidate(mixed, "interview_scheduled", 3)
                    only_interview = candidate(interviews, "interview_scheduled", 4)
                    archived = candidate(historical, "rejected", 5)
                    db.add(ApplicationReview(application_id=interviewing.id, reviewer_id=actor.id, score=75))
                    notice = Notification(user_id=actor.id, title="Candidature", message="Candidate Synthetic received",
                                          type="application_received", related_type="application", related_id=pending.id)
                    db.add(notice)
                    db.flush()
                    db.add(EmailDelivery(notification_id=notice.id, recipient_email=actor.email,
                                         subject="Candidature", text_body="Candidate Synthetic", html_body="<p>Candidate Synthetic</p>"))
                    db.commit()
                    ids = [row.id for row in (mixed, interviews, historical, pending, accepted, interviewing, only_interview, archived)]
                command.downgrade(config, "20261104_0034")
                command.upgrade(config, "head")
                with Session(engine) as db:
                    mixed, interviews, historical = [db.get(RecruitmentCampaign, value) for value in ids[:3]]
                    pending, accepted, interviewing, only_interview, archived = [db.get(Application, value) for value in ids[3:]]
                    self.assertEqual(mixed.selection_policy_version, "blind-selection-v1")
                    self.assertIsNone(mixed.screening_published_at)
                    self.assertIsNotNone(interviews.screening_published_at)
                    self.assertIsNone(historical.selection_policy_version)
                    self.assertEqual((accepted.status, archived.status), ("accepted", "rejected"))
                    self.assertTrue(accepted.legacy_result_published)
                    self.assertTrue(archived.legacy_result_published)
                    self.assertFalse(pending.legacy_result_published)
                    self.assertIsNone(pending.other_clubs_count)
                    self.assertEqual(interviewing.screening_decision, "shortlisted")
                    self.assertEqual(only_interview.screening_decision, "shortlisted")
                    self.assertEqual(db.query(ApplicationReview).one().stage, "interview")
                    self.assertNotIn("Synthetic", db.query(Notification).one().message)
                    self.assertNotIn("Synthetic", db.query(EmailDelivery).one().text_body)
                    self.assertIsNone(db.query(EmailDelivery).one().html_body)
