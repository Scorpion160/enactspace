"""Validate the migration itself against an existing club database."""
import os
os.environ.setdefault('DATABASE_URL','sqlite://')
os.environ.setdefault('SECRET_KEY','veille-migration-test')
os.environ.setdefault('APP_ENV','test')
import importlib.util
import unittest
import uuid
from datetime import datetime
from pathlib import Path
from alembic.migration import MigrationContext
from alembic.operations import Operations
from sqlalchemy import create_engine,inspect,text,select
import app.models.base
from app.db.database import Base

class VeilleMigrationTests(unittest.TestCase):
    def test_upgrade_preserves_tasks_and_records_baseline_then_downgrade_preserves_originals(self):
        engine=create_engine('sqlite://')
        path=Path(__file__).parent/'alembic/versions/20261004_0022_veille.py'
        spec=importlib.util.spec_from_file_location('veille_migration',path)
        migration=importlib.util.module_from_spec(spec);spec.loader.exec_module(migration)
        member=str(uuid.uuid4());task=str(uuid.uuid4());now=datetime(2026,10,4,12)
        with engine.begin() as connection:
            Base.metadata.create_all(connection)
            for table in reversed(Base.metadata.sorted_tables):
                if table.name.startswith('veille_'):table.drop(connection)
            connection.execute(text('ALTER TABLE tasks DROP COLUMN veille_plan_id'))
            connection.execute(text('ALTER TABLE tasks DROP COLUMN veille_season_id'))
            connection.execute(Base.metadata.tables['users'].insert().values(id=uuid.UUID(member),first_name='Aïta',last_name='Dia',email='migration@example.test',password_hash='unused',status='active',is_active=True,email_verified=True,created_at=now,updated_at=now))
            connection.execute(Base.metadata.tables['tasks'].insert().values(id=uuid.UUID(task),title='Une immersion préparée',status='en_cours',priority='normale',creator_id=uuid.UUID(member),due_date=now,proof_required=False,is_late_alert_sent=False,created_at=now,updated_at=now))
            original=dict(connection.execute(text('SELECT * FROM tasks')).mappings().one())
            with Operations.context(MigrationContext.configure(connection)):
                migration.upgrade()
            self.assertEqual(len([t for t in inspect(connection).get_table_names() if t.startswith('veille_')]),10)
            current=dict(connection.execute(text('SELECT * FROM tasks')).mappings().one())
            self.assertEqual({k:v for k,v in current.items() if k not in {'veille_plan_id','veille_season_id'}},original)
            self.assertIsNone(current['veille_plan_id'])
            event=connection.execute(select(Base.metadata.tables['veille_events'])).mappings().one()
            self.assertEqual(event['action'],'baseline');self.assertEqual(str(event['entity_id']),task)
            self.assertEqual(event['details']['after']['due_date'],'2026-10-04T12:00:00Z')
            settings=connection.execute(text('SELECT reminders_enabled,version FROM veille_settings')).one()
            self.assertEqual(tuple(settings),(1,1))
            self.assertEqual(connection.execute(text('SELECT COUNT(*) FROM veille_rules')).scalar(),0)
            self.assertEqual(connection.execute(text('SELECT COUNT(*) FROM notifications')).scalar(),0)
            # Columns remain compatible with the ORM used by API/worker.
            for table in Base.metadata.tables.values():
                if table.name.startswith('veille_'):
                    self.assertEqual({c.name for c in table.columns},{c['name'] for c in inspect(connection).get_columns(table.name)},table.name)
            with Operations.context(MigrationContext.configure(connection)):
                migration.upgrade()  # retry leaves one baseline and one configuration
            self.assertEqual(connection.execute(text('SELECT COUNT(*) FROM veille_events')).scalar(),1)
            with Operations.context(MigrationContext.configure(connection)):
                migration.downgrade()
            self.assertFalse(any(t.startswith('veille_') for t in inspect(connection).get_table_names()))
            self.assertEqual(dict(connection.execute(text('SELECT * FROM tasks')).mappings().one()),original)
            self.assertEqual(connection.execute(text('SELECT COUNT(*) FROM users')).scalar(),1)
        engine.dispose()

    def test_settings_lock_preserves_integer_primary_key_for_postgresql(self):
        from unittest.mock import patch
        from types import SimpleNamespace
        from app.models.veille import VeilleSettings
        from app.services.veille_service import get_record
        db=SimpleNamespace();row=SimpleNamespace(id=1)
        with patch('app.services.veille_service.lock_row',return_value=row) as lock:
            self.assertIs(get_record(db,VeilleSettings,1,locked=True),row)
            self.assertIsInstance(lock.call_args.args[2],int)

if __name__=='__main__':unittest.main()
