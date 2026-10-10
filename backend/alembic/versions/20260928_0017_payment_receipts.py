"""Add receipt intelligence and allocation metadata to payments.

Revision ID: 20260928_0017
Revises: 20260928_0016
"""
from alembic import op
import sqlalchemy as sa

revision = "20260928_0017"
down_revision = "20260928_0016"
branch_labels = None
depends_on = None


def _payment_columns() -> set[str]:
    return {
        column["name"]
        for column in sa.inspect(op.get_bind()).get_columns("payments")
    }


def upgrade():
    existing = _payment_columns()
    if "allocation_plan" not in existing:
        op.add_column("payments", sa.Column("allocation_plan", sa.JSON(), nullable=True))
    if "receipt_details" not in existing:
        op.add_column("payments", sa.Column("receipt_details", sa.JSON(), nullable=True))
    if "unallocated_amount" not in existing:
        op.add_column(
            "payments",
            sa.Column(
                "unallocated_amount",
                sa.Numeric(12, 2),
                nullable=False,
                server_default="0",
            ),
        )


def downgrade():
    existing = _payment_columns()
    if "unallocated_amount" in existing:
        op.drop_column("payments", "unallocated_amount")
    if "receipt_details" in existing:
        op.drop_column("payments", "receipt_details")
    if "allocation_plan" in existing:
        op.drop_column("payments", "allocation_plan")
