"""Campaign-scoped, revocable read-only recruitment access.

Revision ID: 20261106_0034
Revises: 20261031_0033

The table may already exist in an installation where the November
hotfix was applied. Validate its shape rather than deleting or rebuilding it.
"""
from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20261106_0034"
down_revision = "20261031_0033"
branch_labels = None
depends_on = None

_TABLE = "recruitment_viewer_access"
_INDEX = "ix_recruitment_viewer_active_user"
_REQUIRED = {
    "id", "campaign_id", "user_id", "is_active",
    "granted_by", "revoked_by", "granted_at", "updated_at", "revoked_at",
}


def _existing_table_is_compatible(bind):
    inspector = sa.inspect(bind)
    cols = {column["name"]: column for column in inspector.get_columns(_TABLE)}
    if _REQUIRED - set(cols):
        raise RuntimeError("Recruitment viewer table lacks required columns")
    for name in ("id", "campaign_id", "user_id", "is_active", "granted_at", "updated_at"):
        if cols[name]["nullable"]:
            raise RuntimeError(f"Recruitment viewer table nullable unexpectedly: {name}")
    unique_keys = {tuple(row.get("column_names", [])) for row in inspector.get_unique_constraints(_TABLE)}
    if ("campaign_id", "user_id") not in unique_keys:
        raise RuntimeError("Recruitment viewer campaign/user uniqueness is absent")
    return inspector


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table(_TABLE):
        op.create_table(
            _TABLE,
            sa.Column("id", GUID(), primary_key=True),
            sa.Column("campaign_id", GUID(), sa.ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), nullable=False),
            sa.Column("user_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
            sa.Column("granted_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
            sa.Column("revoked_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
            sa.Column("granted_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
            sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.text("CURRENT_TIMESTAMP")),
            sa.Column("revoked_at", sa.DateTime()),
            sa.UniqueConstraint("campaign_id", "user_id", name="uq_recruitment_viewer_campaign_user"),
        )
    inspector = _existing_table_is_compatible(bind)
    indexes = {item["name"]: item for item in inspector.get_indexes(_TABLE)}
    if _INDEX in indexes:
        entry = indexes[_INDEX]
        if entry["column_names"] != ["user_id", "is_active"] or entry["unique"]:
            raise RuntimeError("Recruitment viewer access index incompatible")
    else:
        op.create_index(_INDEX, _TABLE, ["user_id", "is_active"])


def downgrade():
    bind = op.get_bind()
    if not sa.inspect(bind).has_table(_TABLE):
        return
    if bind.execute(sa.text("SELECT COUNT(*) FROM recruitment_viewer_access")).scalar():
        raise RuntimeError(
            "Revocable campaign access history exists; keep recruitment migration 0034."
        )
    op.drop_table(_TABLE)
