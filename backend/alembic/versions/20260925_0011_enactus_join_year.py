"""Store the year an Alumni joined Enactus ESP.

Revision ID: 20260925_0011
Revises: 20260924_0010
"""

from alembic import op
import sqlalchemy as sa

revision = "20260925_0011"
down_revision = "20260924_0010"
branch_labels = None
depends_on = None


def _columns(table: str) -> set[str]:
    return {item["name"] for item in sa.inspect(op.get_bind()).get_columns(table)}


def upgrade() -> None:
    if "enactus_join_year" not in _columns("alumni_profiles"):
        op.add_column(
            "alumni_profiles",
            sa.Column("enactus_join_year", sa.Integer(), nullable=True),
        )


def downgrade() -> None:
    if "enactus_join_year" in _columns("alumni_profiles"):
        with op.batch_alter_table("alumni_profiles") as batch:
            batch.drop_column("enactus_join_year")
