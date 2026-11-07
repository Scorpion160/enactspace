"""Create cross-device club game rooms.

Revision ID: 20260928_0016
Revises: 20260927_0014
"""
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision = "20260928_0016"
down_revision = "20260927_0014"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    names = set(sa.inspect(bind).get_table_names())
    expected = {"game_rooms", "game_players", "game_responses"}
    if expected.issubset(names):
        return
    if names.intersection(expected):
        raise RuntimeError("Partial club games schema")
    op.create_table("game_rooms",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("code", sa.String(8), nullable=False, unique=True),
        sa.Column("host_id", GUID(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("game", sa.String(30), nullable=False),
        sa.Column("mode", sa.String(20), nullable=False),
        sa.Column("theme", sa.String(40), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("round_number", sa.Integer(), nullable=False),
        sa.Column("max_rounds", sa.Integer(), nullable=False),
        sa.Column("state", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False))
    op.create_table("game_players",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("room_id", GUID(), sa.ForeignKey("game_rooms.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("team", sa.String(30)),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("role", sa.String(30)),
        sa.Column("secret", sa.Text()),
        sa.Column("eliminated", sa.Boolean(), nullable=False),
        sa.Column("won", sa.Boolean(), nullable=False),
        sa.UniqueConstraint("room_id", "user_id", name="uq_game_player_room_user"))
    op.create_table("game_responses",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("room_id", GUID(), sa.ForeignKey("game_rooms.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("round_number", sa.Integer(), nullable=False),
        sa.Column("answer", sa.String(150), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("room_id", "user_id", "round_number", name="uq_game_response_round"))


def downgrade():
    op.drop_table("game_responses")
    op.drop_table("game_players")
    op.drop_table("game_rooms")
