"""Add durable chat polls and votes.

Revision ID: 20260926_0015
Revises: 20260926_0014
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID

revision = "20260926_0015"
down_revision = "20260926_0014"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    existing = set(inspector.get_table_names())
    wanted = {"chat_polls", "chat_poll_options", "chat_poll_votes"}
    if wanted.issubset(existing):
        return
    if wanted.intersection(existing):
        raise RuntimeError("Partial chat poll schema detected; manual review required")

    op.create_table(
        "chat_polls",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("message_id", GUID(), nullable=False),
        sa.Column("question", sa.Text(), nullable=False),
        sa.Column("allows_multiple", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("closes_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["message_id"], ["chat_messages.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("message_id", name="uq_chat_polls_message_id"),
    )

    op.create_table(
        "chat_poll_options",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("poll_id", GUID(), nullable=False),
        sa.Column("label", sa.String(240), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "position >= 0",
            name="ck_chat_poll_option_position",
        ),
        sa.ForeignKeyConstraint(
            ["poll_id"], ["chat_polls.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "poll_id", "position",
            name="uq_chat_poll_option_position",
        ),
    )

    op.create_table(
        "chat_poll_votes",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("poll_id", GUID(), nullable=False),
        sa.Column("option_id", GUID(), nullable=False),
        sa.Column("user_id", GUID(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["poll_id"], ["chat_polls.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["option_id"], ["chat_poll_options.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "poll_id", "option_id", "user_id",
            name="uq_chat_poll_vote_option_user",
        ),
    )
    op.create_index("ix_chat_poll_options_poll_id", "chat_poll_options", ["poll_id"])
    op.create_index("ix_chat_poll_votes_poll_id", "chat_poll_votes", ["poll_id"])
    op.create_index("ix_chat_poll_votes_option_id", "chat_poll_votes", ["option_id"])
    op.create_index("ix_chat_poll_votes_user_id", "chat_poll_votes", ["user_id"])


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    existing = set(inspector.get_table_names())
    if "chat_poll_votes" in existing:
        op.drop_table("chat_poll_votes")
    if "chat_poll_options" in existing:
        op.drop_table("chat_poll_options")
    if "chat_polls" in existing:
        op.drop_table("chat_polls")
