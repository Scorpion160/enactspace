"""Store the selection calendar without modifying historical campaign dates.

Revision ID: 20261105_0036
Revises: 20261105_0035
"""
from alembic import op
import sqlalchemy as sa

revision = "20261105_0036"
down_revision = "20261105_0035"
branch_labels = None
depends_on = None


def upgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("recruitment_campaigns")}
    if "selection_schedule" not in columns:
        op.add_column("recruitment_campaigns", sa.Column("selection_schedule", sa.JSON(), nullable=True))


def downgrade():
    with op.batch_alter_table("recruitment_campaigns") as batch:
        batch.drop_column("selection_schedule")
