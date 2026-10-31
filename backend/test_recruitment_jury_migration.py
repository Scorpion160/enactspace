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
                    self.assertIn('application_personality', inspect(connection).get_table_names())
                    self.assertIn('campus_resident', {row['name'] for row in inspect(connection).get_columns('applications')})
                    self.assertEqual(connection.execute(text('SELECT cv_url FROM applications')).scalar_one(), 'private-cv-reference')
                    migration.downgrade()
                    self.assertNotIn('application_personality', inspect(connection).get_table_names())
                    self.assertEqual(connection.execute(text('SELECT cv_url FROM applications')).scalar_one(), 'private-cv-reference')
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
