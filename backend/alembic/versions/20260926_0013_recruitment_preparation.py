"""Add structured recruitment preparation fields.

Revision ID: 20260926_0013
Revises: 20260926_0012
"""

from alembic import op
import sqlalchemy as sa

revision = "20260926_0013"
down_revision = "20260926_0012"
branch_labels = None
depends_on = None

FIELDS = {
    "target_headcount": sa.Integer(),
    "positions": sa.JSON(),
    "target_profiles": sa.JSON(),
    "communication_actions": sa.JSON(),
    "interview_questions": sa.JSON(),
}


def _columns() -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_columns("recruitment_campaigns")
    }


def upgrade() -> None:
    columns = _columns()
    for name, column_type in FIELDS.items():
        if name not in columns:
            op.add_column(
                "recruitment_campaigns",
                sa.Column(name, column_type, nullable=True),
            )


def downgrade() -> None:
    columns = _columns()
    for name in reversed(tuple(FIELDS)):
        if name in columns:
            with op.batch_alter_table("recruitment_campaigns") as batch:
                batch.drop_column(name)
