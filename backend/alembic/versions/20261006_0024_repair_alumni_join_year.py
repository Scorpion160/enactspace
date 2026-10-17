"""Repair the Alumni field missing in databases stamped past revision 0011.

The field belongs to revision 0011. This repair is additive and idempotent;
downgrading this repair must retain the field and any year entered afterwards.
"""
from alembic import op
import sqlalchemy as sa

revision = "20261006_0024"
down_revision = "20261006_0023"
branch_labels = None
depends_on = None


def upgrade():
    columns = {item["name"] for item in sa.inspect(op.get_bind()).get_columns("alumni_profiles")}
    if "enactus_join_year" not in columns:
        op.add_column("alumni_profiles", sa.Column("enactus_join_year", sa.Integer(), nullable=True))


def downgrade():
    # Revision 0011 still requires this column; never remove existing Alumni data.
    pass
