"""Add EnactMeet rooms and membership tracking.

Revision ID: 20260928_0018
Revises: 20260928_0017
"""
from alembic import op
import sqlalchemy as sa

from app.db.types import GUID

revision = "20260928_0018"
down_revision = "20260928_0017"
branch_labels = None
depends_on = None


def _tables() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def upgrade():
    existing = _tables()
    if "meetings" not in existing:
        op.create_table(
            "meetings",
            sa.Column("id", GUID(), nullable=False),
            sa.Column("room_key", sa.String(120), nullable=False),
            sa.Column("title", sa.String(200), nullable=False),
            sa.Column("description", sa.Text(), nullable=True),
            sa.Column("status", sa.String(30), nullable=False, server_default="scheduled"),
            sa.Column("scope_type", sa.String(30), nullable=False, server_default="club"),
            sa.Column("scope_id", GUID(), nullable=True),
            sa.Column("provider", sa.String(40), nullable=False, server_default="jitsi"),
            sa.Column("server_url", sa.String(300), nullable=False),
            sa.Column("scheduled_start", sa.DateTime(), nullable=True),
            sa.Column("scheduled_end", sa.DateTime(), nullable=True),
            sa.Column("started_at", sa.DateTime(), nullable=True),
            sa.Column("ended_at", sa.DateTime(), nullable=True),
            sa.Column("created_by", GUID(), nullable=False),
            sa.Column("start_with_audio_muted", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("start_with_video_muted", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("lobby_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("recording_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("room_key", name="uq_meetings_room_key"),
            sa.CheckConstraint(
                "status IN ('scheduled','live','ended','cancelled')",
                name="ck_meetings_status",
            ),
            sa.CheckConstraint(
                "scope_type IN ('club','pole','project','custom')",
                name="ck_meetings_scope_type",
            ),
            sa.CheckConstraint(
                "scheduled_end IS NULL OR scheduled_start IS NULL OR scheduled_end > scheduled_start",
                name="ck_meetings_schedule_order",
            ),
        )

    existing = _tables()
    if "meeting_members" not in existing:
        op.create_table(
            "meeting_members",
            sa.Column("id", GUID(), nullable=False),
            sa.Column("meeting_id", GUID(), nullable=False),
            sa.Column("user_id", GUID(), nullable=False),
            sa.Column("role", sa.String(30), nullable=False, server_default="participant"),
            sa.Column("invited_at", sa.DateTime(), nullable=False),
            sa.Column("joined_at", sa.DateTime(), nullable=True),
            sa.Column("left_at", sa.DateTime(), nullable=True),
            sa.Column("last_seen_at", sa.DateTime(), nullable=True),
            sa.ForeignKeyConstraint(["meeting_id"], ["meetings.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("meeting_id", "user_id", name="uq_meeting_member"),
            sa.CheckConstraint(
                "role IN ('host','cohost','participant')",
                name="ck_meeting_members_role",
            ),
        )


def downgrade():
    existing = _tables()
    if "meeting_members" in existing:
        op.drop_table("meeting_members")
    existing = _tables()
    if "meetings" in existing:
        op.drop_table("meetings")
