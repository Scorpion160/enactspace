"""Migration 0032 preserves existing dossiers and guards destructive rollback."""
import importlib.util
from pathlib import Path
from unittest import TestCase
from sqlalchemy import create_engine, inspect, text
from alembic.migration import MigrationContext
from alembic.operations import Operations


class RecruitmentJuryMigrationTests(TestCase):
    def test_upgrade_and_empty_downgrade_preserve_original_candidate(self):
        file = Path(__file__).parent / 'alembic/versions/20261031_0032_recruitment_jury_personality.py'
        spec = importlib.util.spec_from_file_location('recruitment_0032', file)
        migration = importlib.util.module_from_spec(spec); spec.loader.exec_module(migration)
        engine = create_engine('sqlite://')
        try:
            with engine.begin() as connection:
                connection.execute(text('CREATE TABLE users (id CHAR(36) PRIMARY KEY)'))
                connection.execute(text('CREATE TABLE recruitment_campaigns (id CHAR(36) PRIMARY KEY)'))
                connection.execute(text('CREATE TABLE applications (id CHAR(36) PRIMARY KEY, email VARCHAR(150), cv_url TEXT)'))
                connection.execute(text("INSERT INTO applications VALUES ('candidate', 'fiction@example.org', 'private-cv-reference')"))
                with Operations.context(MigrationContext.configure(connection)):
                    migration.upgrade()
                    migration.upgrade()  # Already-created compatible objects are not recreated.
                    self.assertIn('application_personality', inspect(connection).get_table_names())
                    self.assertIn('campus_resident', {row['name'] for row in inspect(connection).get_columns('applications')})
                    self.assertEqual(connection.execute(text('SELECT cv_url FROM applications')).scalar_one(), 'private-cv-reference')
                    migration.downgrade()
                    self.assertNotIn('application_personality', inspect(connection).get_table_names())
                    self.assertEqual(connection.execute(text('SELECT cv_url FROM applications')).scalar_one(), 'private-cv-reference')
        finally:
            engine.dispose()

    def test_current_metadata_bootstrap_preserves_existing_jury_and_draft(self):
        import app.models.base
        from app.db.database import Base
        from app.models.user import User
        from app.models.recruitment import RecruitmentCampaign, Application, RecruitmentJuryMember, ApplicationPersonality
        from sqlalchemy.orm import Session
        file = Path(__file__).parent / 'alembic/versions/20261031_0032_recruitment_jury_personality.py'
        spec = importlib.util.spec_from_file_location('recruitment_0032', file)
        migration = importlib.util.module_from_spec(spec); spec.loader.exec_module(migration)
        engine = create_engine('sqlite://')
        try:
            Base.metadata.create_all(engine)  # Same source of schema as revision 0001.
            with Session(engine) as db:
                user = User(first_name='Synthetic', last_name='Juror', email='juror@example.org', password_hash='unused', status='alumni')
                campaign = RecruitmentCampaign(title='Synthetic migration fixture')
                db.add_all([user, campaign]); db.flush()
                app = Application(campaign_id=campaign.id, first_name='Synthetic', last_name='Candidate',
                    email='candidate@example.org', campus_resident=False, cv_url='private-fixture-reference')
                db.add(app); db.flush()
                db.add_all([RecruitmentJuryMember(campaign_id=campaign.id, user_id=user.id),
                    ApplicationPersonality(application_id=app.id, instrument_version='fixture-v1',
                        instrument_snapshot={'version': 'fixture-v1'}, answers={'p01': 4}, scenario_answers={})])
                app_id = app.id
                db.commit()
            with engine.begin() as connection, Operations.context(MigrationContext.configure(connection)):
                migration.upgrade()
                migration.upgrade()
            with Session(engine) as db:
                self.assertEqual(db.query(RecruitmentJuryMember).count(), 1)
                self.assertEqual(db.get(ApplicationPersonality, app_id).answers, {'p01': 4})
                self.assertIs(db.get(Application, app_id).campus_resident, False)
                self.assertEqual(db.get(Application, app_id).cv_url, 'private-fixture-reference')
        finally:
            engine.dispose()

    def test_incompatible_existing_column_blocks_before_any_schema_change(self):
        file = Path(__file__).parent / 'alembic/versions/20261031_0032_recruitment_jury_personality.py'
        spec = importlib.util.spec_from_file_location('recruitment_0032', file)
        migration = importlib.util.module_from_spec(spec); spec.loader.exec_module(migration)
        engine = create_engine('sqlite://')
        try:
            with engine.begin() as connection:
                connection.execute(text('CREATE TABLE applications (id CHAR(36) PRIMARY KEY, campus_resident TEXT)'))
                with Operations.context(MigrationContext.configure(connection)):
                    with self.assertRaisesRegex(RuntimeError, 'Incompatible_recruitment_schema'):
                        migration.upgrade()
                self.assertEqual(inspect(connection).get_table_names(), ['applications'])
                self.assertEqual({row['name'] for row in inspect(connection).get_columns('applications')}, {'id', 'campus_resident'})
        finally:
            engine.dispose()

    def test_downgrade_preserves_campus_information_even_without_jury_or_questionnaire(self):
        file = Path(__file__).parent / 'alembic/versions/20261031_0032_recruitment_jury_personality.py'
        spec = importlib.util.spec_from_file_location('recruitment_0032', file)
        migration = importlib.util.module_from_spec(spec); spec.loader.exec_module(migration)
        engine = create_engine('sqlite://')
        try:
            with engine.begin() as connection:
                connection.execute(text('CREATE TABLE users (id CHAR(36) PRIMARY KEY)'))
                connection.execute(text('CREATE TABLE recruitment_campaigns (id CHAR(36) PRIMARY KEY)'))
                connection.execute(text('CREATE TABLE applications (id CHAR(36) PRIMARY KEY)'))
                with Operations.context(MigrationContext.configure(connection)):
                    migration.upgrade()
                    connection.execute(text("INSERT INTO applications (id, campus_resident) VALUES ('candidate', false)"))
                    with self.assertRaisesRegex(RuntimeError, 'history exists'):
                        migration.downgrade()
                    self.assertEqual(connection.execute(text('SELECT campus_resident FROM applications')).scalar_one(), 0)
        finally:
            engine.dispose()

    def test_downgrade_refuses_to_erase_a_saved_candidate_questionnaire(self):
        file = Path(__file__).parent / 'alembic/versions/20261031_0032_recruitment_jury_personality.py'
        spec = importlib.util.spec_from_file_location('recruitment_0032', file)
        migration = importlib.util.module_from_spec(spec); spec.loader.exec_module(migration)
        engine = create_engine('sqlite://')
        try:
            with engine.begin() as connection:
                connection.execute(text('CREATE TABLE users (id CHAR(36) PRIMARY KEY)'))
                connection.execute(text('CREATE TABLE recruitment_campaigns (id CHAR(36) PRIMARY KEY)'))
                connection.execute(text('CREATE TABLE applications (id CHAR(36) PRIMARY KEY)'))
                with Operations.context(MigrationContext.configure(connection)):
                    migration.upgrade()
                    connection.execute(text("INSERT INTO application_personality (application_id, instrument_version, instrument_snapshot, answers, scenario_answers, revision, invited_at, updated_at) VALUES ('candidate', 'v1', '{}', '{}', '{}', 0, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"))
                    with self.assertRaisesRegex(RuntimeError, 'history exists'):
                        migration.downgrade()
                    self.assertEqual(connection.execute(text('SELECT COUNT(*) FROM application_personality')).scalar_one(), 1)
        finally:
            engine.dispose()
