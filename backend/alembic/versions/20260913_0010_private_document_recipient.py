"""Add a targeted recipient to private documents.

Revision ID: 20260913_0010
Revises: 20260913_0009
Create Date: 2026-09-13
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260913_0010"
down_revision = "20260913_0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    with op.batch_alter_table("documents") as batch_op:
        batch_op.add_column(
            sa.Column("recipient_user_id", GUID(), nullable=True)
        )
        batch_op.create_foreign_key(
            "fk_documents_recipient_user_id_users",
            "users",
            ["recipient_user_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch_op.create_index(
            "ix_documents_recipient_user_id",
            ["recipient_user_id"],
            unique=False,
        )


def downgrade() -> None:
    with op.batch_alter_table("documents") as batch_op:
        batch_op.drop_index("ix_documents_recipient_user_id")
        batch_op.drop_constraint(
            "fk_documents_recipient_user_id_users",
            type_="foreignkey",
        )
        batch_op.drop_column("recipient_user_id")
