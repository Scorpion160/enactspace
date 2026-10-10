"""Run attachment and alumni HTTP journeys on isolated PostgreSQL schemas."""
import os
import uuid
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from sqlalchemy import create_engine, event, text
import test_veille as fixture
import test_attachments_lifecycle as attachments


@unittest.skipUnless(os.getenv('VEILLE_TEST_POSTGRESQL_URL'), 'Dedicated PostgreSQL test database required')
class AttachmentsPostgreSQLTests(attachments.AttachmentLifecycleTests):
    def setUp(self):
        self.pg_admin = create_engine(os.environ['VEILLE_TEST_POSTGRESQL_URL'])
        self.schema = 'attachments_test_' + uuid.uuid4().hex
        with self.pg_admin.begin() as connection:
            connection.execute(text('CREATE SCHEMA ' + self.schema))
        pg_engine = create_engine(os.environ['VEILLE_TEST_POSTGRESQL_URL'])

        @event.listens_for(pg_engine, 'connect')
        def select_schema(connection, _):
            with connection.cursor() as cursor:
                cursor.execute('SET search_path TO ' + self.schema)
            connection.commit()

        with patch.object(fixture, 'create_engine', return_value=pg_engine), patch.object(
            fixture, 'event', SimpleNamespace(listens_for=lambda *_: lambda function: function)
        ):
            super().setUp()

    def tearDown(self):
        try:
            super().tearDown()
        finally:
            with self.pg_admin.begin() as connection:
                connection.execute(text('DROP SCHEMA ' + self.schema + ' CASCADE'))
            self.pg_admin.dispose()
