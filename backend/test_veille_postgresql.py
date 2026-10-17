"""Exercise Veille HTTP flows and competing writes in an isolated PostgreSQL schema."""
import os
import threading
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from types import SimpleNamespace
from unittest.mock import patch

from sqlalchemy import create_engine, event, text
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

import test_veille as fixture
from app.core.time import utc_now
from app.models.veille import VeilleBlocker, VeilleReview
from app.services.veille_scheduler import run_cycle


@unittest.skipUnless(os.getenv('VEILLE_TEST_POSTGRESQL_URL'), 'Dedicated PostgreSQL test database required')
class VeillePostgreSQLTests(fixture.VeilleFlowTests):
    @classmethod
    def setUpClass(cls):
        url = make_url(os.environ['VEILLE_TEST_POSTGRESQL_URL'])
        if url.get_backend_name() != 'postgresql' or url.host not in {'localhost','127.0.0.1','::1'} or not (url.database or '').startswith('enactspace_pr2b_test_'):
            raise RuntimeError('Only explicitly disposable local PostgreSQL databases are allowed')
        cls.pg_admin = create_engine(url)
        cls.schema = 'veille_test_' + uuid.uuid4().hex
        with cls.pg_admin.begin() as connection:
            connection.execute(text('CREATE SCHEMA ' + cls.schema))
        cls.pg_engine = create_engine(url)

        @event.listens_for(cls.pg_engine, 'connect')
        def select_schema(connection, _):
            with connection.cursor() as cursor:
                cursor.execute('SET search_path TO ' + cls.schema)
            connection.commit()

        try:
            fixture.Base.metadata.create_all(cls.pg_engine)
        except Exception:
            cls.pg_engine.dispose()
            with cls.pg_admin.begin() as connection:
                connection.execute(text('DROP SCHEMA ' + cls.schema + ' CASCADE'))
            cls.pg_admin.dispose()
            raise

    def setUp(self):
        # Reset every table in this owned schema; public/production tables are never targeted.
        quote = self.pg_engine.dialect.identifier_preparer.quote
        tables = [quote(self.schema) + '.' + quote(table.name)
                  for table in fixture.Base.metadata.sorted_tables]
        with self.pg_engine.begin() as connection:
            connection.execute(text('TRUNCATE TABLE ' + ','.join(tables) + ' RESTART IDENTITY CASCADE'))
        # Reuse the same fixture and all inherited flows without repeating expensive DDL.
        with patch.object(fixture, 'create_engine', return_value=self.pg_engine), patch.object(
            fixture, 'event', SimpleNamespace(listens_for=lambda *_: lambda function: function)
        ), patch.object(fixture.Base.metadata, 'create_all'):
            super().setUp()

    def tearDown(self):
        with patch.object(self.pg_engine, 'dispose'):
            super().tearDown()

    @classmethod
    def tearDownClass(cls):
        cls.pg_engine.dispose()
        if not cls.schema.startswith('veille_test_') or len(cls.schema) != 44:
            raise RuntimeError('Refusing to drop an unowned schema')
        with cls.pg_admin.begin() as connection:
            connection.execute(text('DROP SCHEMA ' + cls.schema + ' CASCADE'))
        cls.pg_admin.dispose()

    def race(self, method, path, payload):
        barrier = threading.Barrier(2)
        def request(_):
            barrier.wait(timeout=10)
            return self.client.request(method, '/api/veille' + path, json=payload)
        with ThreadPoolExecutor(max_workers=2) as workers:
            return list(workers.map(request, range(2)))

    def test_concurrent_review_accepts_once(self):
        self.task.status = 'termine'
        self.task.completed_at = utc_now()
        self.db.commit()
        detail = self.call('GET', f'/tasks/{self.task.id}')
        self.as_user('lead')
        responses = self.race('POST', f'/tasks/{self.task.id}/reviews', {
            'verdict': 'accepted', 'feedback': 'Le livrable répond aux attentes convenues.',
            'expected_updated_at': detail['updated_at'],
        })
        self.assertEqual(sorted(r.status_code for r in responses), [200, 409], [r.text for r in responses])
        self.assertEqual(self.db.query(VeilleReview).count(), 1)

    def test_concurrent_blocker_creates_once(self):
        self.as_user('a')
        responses = self.race('POST', '/blockers', {
            'task_id': str(self.task.id), 'owner_id': str(self.users['a'].id),
            'title': 'Contact terrain à confirmer', 'cause': 'dependance',
            'description': 'Une confirmation du partenaire reste nécessaire.',
            'requested_help': 'Joindre le partenaire avant le déplacement.',
            'next_action': 'Confirmer la disponibilité du partenaire.',
            'review_at': (utc_now() + timedelta(days=1)).isoformat() + 'Z',
        })
        self.assertEqual(sorted(r.status_code for r in responses), [200, 409], [r.text for r in responses])
        self.assertEqual(self.db.query(VeilleBlocker).filter_by(status='open').count(), 1)

    def test_concurrent_settings_keeps_one_version(self):
        self.as_user('tl')
        config = self.call('GET', '/context')['settings']
        body = {k: config[k] for k in ('version', 'reminders_enabled', 'quiet_start_hour',
            'quiet_end_hour', 'escalation_days', 'response_days', 'appeal_days',
            'weekly_day', 'report_hour', 'auto_reports')}
        body['response_days'] = 9
        responses = self.race('PUT', '/settings', body)
        self.assertEqual(sorted(r.status_code for r in responses), [200, 409], [r.text for r in responses])
        self.assertEqual(self.call('GET', '/context')['settings']['version'], 2)

    def test_scheduler_replica_respects_advisory_lock(self):
        with Session(self.engine) as first, Session(self.engine) as second:
            self.assertTrue(first.execute(text('SELECT pg_try_advisory_xact_lock(24400222026)')).scalar())
            self.assertEqual(run_cycle(second), {'reminders': 0, 'reports': 0, 'busy': True})
            first.rollback()


if __name__ == '__main__':
    unittest.main()
