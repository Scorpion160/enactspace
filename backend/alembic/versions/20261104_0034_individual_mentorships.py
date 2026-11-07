"""Add private individual mentorship requests."""
from alembic import op
import sqlalchemy as sa

from app.db.types import GUID

revision = "20261104_0034"
down_revision = "20261031_0033"
branch_labels = None
depends_on = None

TABLE = "individual_mentorships"
OPEN = sa.text("status IN ('pending', 'active')")


def upgrade():
    # Revision 0001 may already have created the table from current metadata.
    inspector = sa.inspect(op.get_bind())
    if inspector.has_table(TABLE):
        columns = {column["name"] for column in inspector.get_columns(TABLE)}
        indexes = {index["name"] for index in inspector.get_indexes(TABLE) if index["unique"]}
        if columns != {"id", "mentor_id", "mentee_id", "objective", "status", "created_at", "updated_at"} or "ux_individual_mentorship_open" not in indexes:
            raise RuntimeError("Incompatible individual mentorship table.")
        return
    op.create_table(
        TABLE,
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("mentor_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("mentee_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("objective", sa.String(2000), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("mentor_id <> mentee_id", name="ck_individual_distinct_people"),
        sa.CheckConstraint(
            "status IN ('pending', 'active', 'completed', 'cancelled')",
            name="ck_individual_mentorship_status",
        ),
    )
    op.create_index("ix_individual_mentorships_mentor_id", TABLE, ["mentor_id"])
    op.create_index("ix_individual_mentorships_mentee_id", TABLE, ["mentee_id"])
    op.create_index(
        "ux_individual_mentorship_open", TABLE, ["mentor_id", "mentee_id"],
        unique=True, sqlite_where=OPEN, postgresql_where=OPEN,
    )


def downgrade():
    if op.get_bind().execute(sa.text(f"SELECT 1 FROM {TABLE} LIMIT 1")).first():
        raise RuntimeError("Keep schema 0034 when rolling back code with existing individual mentorships.")
    op.drop_table(TABLE)
