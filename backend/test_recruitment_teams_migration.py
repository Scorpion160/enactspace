"""0033 handles both legacy schemas and current-metadata bootstrap safely."""
import importlib.util
from pathlib import Path
from unittest import TestCase
from sqlalchemy import create_engine, inspect, text
from alembic.migration import MigrationContext
from alembic.operations import Operations


def migration():
    path = Path(__file__).parent/'alembic/versions/20261031_0033_recruitment_jury_teams.py'
    spec = importlib.util.spec_from_file_location('jury_0033', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class RecruitmentTeamsMigrationTests(TestCase):
    def test_legacy_upgrade_repeat_and_empty_rollback_keep_original_dossier(self):
        engine=create_engine('sqlite://')
        try:
            with engine.begin() as connection:
                for table in ('users','recruitment_campaigns','recruitment_jury_members'):
                    connection.execute(text('CREATE TABLE '+table+' (id CHAR(36) PRIMARY KEY)'))
                connection.execute(text('CREATE TABLE applications (id CHAR(36) PRIMARY KEY, cv_url TEXT)'))
                connection.execute(text("INSERT INTO applications VALUES ('synthetic', 'private-reference')"))
                with Operations.context(MigrationContext.configure(connection)):
                    module=migration()
                    module.upgrade(); module.upgrade()
                    self.assertIn('recruitment_jury_teams',inspect(connection).get_table_names())
                    module.downgrade()
                    self.assertNotIn('recruitment_jury_teams',inspect(connection).get_table_names())
                self.assertEqual(connection.execute(text('SELECT cv_url FROM applications')).scalar_one(),'private-reference')
        finally:
            engine.dispose()

    def test_current_metadata_and_existing_team_survive_upgrade_and_block_destructive_rollback(self):
        import app.models.base
        from app.db.database import Base
        from app.models.recruitment import RecruitmentCampaign, RecruitmentJuryTeam
        from sqlalchemy.orm import Session
        engine=create_engine('sqlite://')
        try:
            Base.metadata.create_all(engine)
            with Session(engine) as db:
                campaign=RecruitmentCampaign(title='Synthetic migration')
                db.add(campaign); db.flush()
                team=RecruitmentJuryTeam(campaign_id=campaign.id,name='Synthetic',name_key='synthetic')
                db.add(team); db.commit()
            with engine.begin() as connection, Operations.context(MigrationContext.configure(connection)):
                module=migration()
                module.upgrade(); module.upgrade()
                self.assertEqual(connection.execute(text('SELECT name FROM recruitment_jury_teams')).scalar_one(),'Synthetic')
                with self.assertRaisesRegex(RuntimeError,'history exists'):
                    module.downgrade()
        finally:
            engine.dispose()

    def test_incompatible_table_blocks_before_creating_other_tables(self):
        engine=create_engine('sqlite://')
        try:
            with engine.begin() as connection:
                connection.execute(text('CREATE TABLE recruitment_jury_teams (id CHAR(36) PRIMARY KEY, name TEXT)'))
                with Operations.context(MigrationContext.configure(connection)), self.assertRaisesRegex(RuntimeError,'Incompatible_recruitment_schema'):
                    migration().upgrade()
                self.assertEqual(inspect(connection).get_table_names(),['recruitment_jury_teams'])
        finally:
            engine.dispose()
