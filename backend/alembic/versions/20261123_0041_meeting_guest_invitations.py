"""Revocable EnactMeet invitations for external email guests.

Revision ID: 20261123_0041
Revises: 20261115_0040
"""
from alembic import op
import sqlalchemy as sa

from app.db.types import GUID

revision = "20261123_0041"
down_revision = "20261115_0040"
branch_labels = None
depends_on = None


def upgrade():
    inspector = sa.inspect(op.get_bind())
    if inspector.has_table("meeting_guest_invitations"):
        return
    op.create_table(
        "meeting_guest_invitations",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("meeting_id", GUID(), nullable=False),
        sa.Column("invited_by", GUID(), nullable=True),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("display_name", sa.String(length=160), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("email_delivery_id", GUID(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["meeting_id"], ["meetings.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["invited_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["email_delivery_id"], ["email_deliveries.id"], ondelete="SET NULL"
        ),
        sa.UniqueConstraint("token_hash", name="uq_meeting_guest_token_hash"),
    )
    op.create_index(
        "ix_meeting_guest_invites_meeting_email",
        "meeting_guest_invitations", ["meeting_id", "email"],
    )


def downgrade():
    bind = op.get_bind()
    if bind.execute(sa.text("SELECT COUNT(*) FROM meeting_guest_invitations")).scalar():
        raise RuntimeError("External invitation audit history must be preserved.")
    op.drop_index("ix_meeting_guest_invites_meeting_email", table_name="meeting_guest_invitations")
    op.drop_table("meeting_guest_invitations")
