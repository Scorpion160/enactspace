"""Human assessments on independent PostgreSQL schemas, never production data."""
import os
import unittest
import uuid
from types import SimpleNamespace
from unittest.mock import patch
from sqlalchemy import create_engine, event, text
import test_veille as fixture
import test_recruitment_rubric as rubric

@unittest.skipUnless(os.getenv("VEILLE_TEST_POSTGRESQL_URL"), "Dedicated PostgreSQL test database required")
class RecruitmentRubricPostgreSQLTests(rubric.RecruitmentRubricHttpTests):
    def setUp(self):
        self.admin = create_engine(os.environ["VEILLE_TEST_POSTGRESQL_URL"])
        self.schema = "recruitment_rubric_" + uuid.uuid4().hex
        with self.admin.begin() as connection:
            connection.execute(text("CREATE SCHEMA " + self.schema))
        engine = create_engine(os.environ["VEILLE_TEST_POSTGRESQL_URL"])
        @event.listens_for(engine, "connect")
        def select_schema(connection, _):
            with connection.cursor() as cursor:
                cursor.execute("SET search_path TO " + self.schema)
            connection.commit()
        with patch.object(fixture, "create_engine", return_value=engine), patch.object(fixture, "event", SimpleNamespace(listens_for=lambda *_: lambda fn: fn)):
            super().setUp()

    def tearDown(self):
        try:
            super().tearDown()
        finally:
            with self.admin.begin() as connection:
                connection.execute(text("DROP SCHEMA " + self.schema + " CASCADE"))
            self.admin.dispose()
