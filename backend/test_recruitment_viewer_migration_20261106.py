"""Regression checks for campaign-scoped temporary recruitment access migration."""
import importlib.util
from pathlib import Path

import sqlalchemy as sa
from alembic.operations import Operations
from alembic.runtime.migration import MigrationContext

from app.db.database import Base
import app.models.base  # noqa: F401  Register all mapped tables.


_MIGRATION = (
    Path(__file__).parent
    / "alembic"
    / "versions"
    / "20261106_0034_recruitment_viewer_access.py"
)


def _apply_upgrade(connection):
    spec = importlib.util.spec_from_file_location("recruitment_viewer_0034", _MIGRATION)
    revision = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(revision)
    context = MigrationContext.configure(connection)
    with Operations.context(context):
        revision.upgrade()


def test_recruitment_viewer_upgrade_reuses_an_existing_table():
    """A deployed SQL hotfix must not be erased when Alembic catches up."""
    engine = sa.create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    with engine.begin() as connection:
        _apply_upgrade(connection)
        inspector = sa.inspect(connection)
        assert inspector.has_table("recruitment_viewer_access")
        assert "ix_recruitment_viewer_active_user" in {
            row["name"] for row in inspector.get_indexes("recruitment_viewer_access")
        }


def test_recruitment_viewer_upgrade_builds_a_new_table():
    """New installations obtain the same table and unique campaign/user key."""
    engine = sa.create_engine("sqlite+pysqlite:///:memory:")
    other_tables = [
        table for table in Base.metadata.sorted_tables
        if table.name != "recruitment_viewer_access"
    ]
    Base.metadata.create_all(engine, tables=other_tables)
    with engine.begin() as connection:
        assert not sa.inspect(connection).has_table("recruitment_viewer_access")
        _apply_upgrade(connection)
        inspector = sa.inspect(connection)
        assert inspector.has_table("recruitment_viewer_access")
        uniques = {
            tuple(row.get("column_names", []))
            for row in inspector.get_unique_constraints("recruitment_viewer_access")
        }
        assert ("campaign_id", "user_id") in uniques
