"""Add idempotent client identifiers to chat messages.

Revision ID: 20260926_0012
Revises: 20260925_0011
"""

from alembic import op
import sqlalchemy as sa

revision = "20260926_0012"
down_revision = "20260925_0011"
branch_labels = None
depends_on = None

CONSTRAINT = "uq_chat_message_author_client_id"


def _columns() -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_columns("chat_messages")
    }


def _constraints() -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_unique_constraints("chat_messages")
        if item.get("name")
    }


def upgrade() -> None:
    if "client_message_id" not in _columns():
        op.add_column(
            "chat_messages",
            sa.Column("client_message_id", sa.String(120), nullable=True),
        )
    if CONSTRAINT not in _constraints():
        with op.batch_alter_table("chat_messages") as batch:
            batch.create_unique_constraint(
                CONSTRAINT,
                ["author_id", "client_message_id"],
            )


def downgrade() -> None:
    if CONSTRAINT in _constraints():
        with op.batch_alter_table("chat_messages") as batch:
            batch.drop_constraint(CONSTRAINT, type_="unique")
    if "client_message_id" in _columns():
        with op.batch_alter_table("chat_messages") as batch:
            batch.drop_column("client_message_id")
