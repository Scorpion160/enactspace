"""Concurrent shared quotas in a guarded disposable PostgreSQL database."""
import unittest,secrets,importlib.util
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from unittest.mock import patch
from fastapi import HTTPException
from sqlalchemy import select,text,inspect
from alembic.migration import MigrationContext
from alembic.operations import Operations
from app.services.request_rate_limit import consume_limits,counter_key
from app.models.security_rate_limit import SecurityRateLimit
import test_password_reset_guard_postgresql as pg_fixture

class PostgreSQLQuotaTests(unittest.TestCase):
    setUpClass=classmethod(pg_fixture.PostgreSQLResetGuardTests.setUpClass.__func__)
    tearDownClass=classmethod(pg_fixture.PostgreSQLResetGuardTests.tearDownClass.__func__)

    def test_parallel_workers_share_exact_quota(self):
        key=counter_key("concurrency","identity",secrets.token_hex(12))
        def attempt(_):
            with self.Session() as db:
                try:consume_limits(db,[(key,5,900)]);return 200
                except HTTPException as error:db.rollback();return error.status_code
        with ThreadPoolExecutor(max_workers=8) as workers:outcomes=list(workers.map(attempt,range(20)))
        self.assertEqual(outcomes.count(200),5)
        self.assertEqual(outcomes.count(429),15)
        with self.Session() as db:
            self.assertEqual(db.execute(select(SecurityRateLimit.count).where(SecurityRateLimit.key==key)).scalar_one(),5)

    def test_migration_roundtrip_does_not_change_member_rows(self):
        spec=importlib.util.spec_from_file_location("quota_migration",Path("alembic/versions/20261007_0027_security_rate_limits.py"))
        migration=importlib.util.module_from_spec(spec);spec.loader.exec_module(migration)
        with self.engine.begin() as connection:
            before=connection.execute(text("SELECT count(*) FROM users")).scalar_one()
            with patch.object(migration,"op",Operations(MigrationContext.configure(connection))):
                migration.downgrade();migration.upgrade()
            self.assertEqual(connection.execute(text("SELECT count(*) FROM users")).scalar_one(),before)
            self.assertIn("security_rate_limits",inspect(connection).get_table_names())
            self.assertIn("ix_security_rate_limits_expires_at",{i["name"] for i in inspect(connection).get_indexes("security_rate_limits")})

if __name__=="__main__":unittest.main()
