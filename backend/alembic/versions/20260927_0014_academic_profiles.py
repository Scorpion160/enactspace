"""Add confirmed academic profiles and seasonal history.

Revision ID: 20260927_0014
Revises: 20260926_0015
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260927_0014"
down_revision = "20260926_0015"
branch_labels = None
depends_on = None


def _columns(table: str) -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_columns(table)
    }


def _restore_sqlite_user_indexes() -> None:
    # SQLite batch table rebuilds cannot reflect expression indexes.
    if op.get_bind().dialect.name != "sqlite":
        return
    op.execute("CREATE UNIQUE INDEX IF NOT EXISTS ux_users_lower_email ON users (lower(email))")
    op.execute("CREATE UNIQUE INDEX IF NOT EXISTS ux_users_lower_username ON users (lower(username))")


def upgrade() -> None:
    columns = _columns("users")
    with op.batch_alter_table("users") as batch:
        if "cursus" not in columns:
            batch.add_column(sa.Column("cursus", sa.String(80), nullable=True))
        if "specialty" not in columns:
            batch.add_column(sa.Column("specialty", sa.String(150), nullable=True))
        if "academic_confirmed_season_id" not in columns:
            batch.add_column(sa.Column("academic_confirmed_season_id", GUID(), nullable=True))
        if "academic_confirmed_at" not in columns:
            batch.add_column(sa.Column("academic_confirmed_at", sa.DateTime(), nullable=True))
        batch.create_foreign_key(
            "fk_users_academic_confirmed_season",
            "seasons",
            ["academic_confirmed_season_id"],
            ["id"],
            ondelete="SET NULL",
        )
    _restore_sqlite_user_indexes()

    if "user_academic_history" in sa.inspect(op.get_bind()).get_table_names():
        return

    op.create_table(
        "user_academic_history",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("season_id", GUID(), sa.ForeignKey("seasons.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("department", sa.String(150), nullable=False),
        sa.Column("cursus", sa.String(80), nullable=False),
        sa.Column("study_level", sa.String(80), nullable=False),
        sa.Column("specialty", sa.String(150)),
        sa.Column("promotion", sa.String(100)),
        sa.Column("progression_action", sa.String(30), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.UniqueConstraint("user_id", "season_id", name="uq_user_academic_history_user_season"),
    )
    op.create_index("ix_user_academic_history_user_id", "user_academic_history", ["user_id"])
    op.create_index("ix_user_academic_history_season_id", "user_academic_history", ["season_id"])


def downgrade() -> None:
    op.drop_index("ix_user_academic_history_season_id", "user_academic_history")
    op.drop_index("ix_user_academic_history_user_id", "user_academic_history")
    op.drop_table("user_academic_history")
    with op.batch_alter_table("users") as batch:
        batch.drop_constraint("fk_users_academic_confirmed_season", type_="foreignkey")
        batch.drop_column("academic_confirmed_at")
        batch.drop_column("academic_confirmed_season_id")
        batch.drop_column("specialty")
        batch.drop_column("cursus")
    _restore_sqlite_user_indexes()
