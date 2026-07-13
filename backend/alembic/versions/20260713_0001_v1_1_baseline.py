"""V1.1 baseline schema.

Revision ID: 20260713_0001
Revises:
Create Date: 2026-07-13
"""

from alembic import op

from app.db.database import Base
import app.models.base  # noqa: F401


revision = "20260713_0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Baseline migration for a fresh production database. Future schema changes
    # must be explicit Alembic revisions rather than application startup create_all.
    Base.metadata.create_all(bind=op.get_bind())


def downgrade() -> None:
    raise RuntimeError("V1.1 baseline downgrade is intentionally unsupported")
