"""Add unique usernames for authentication.

Revision ID: 20260924_0010
Revises: 20260913_0009
"""

from alembic import op
import sqlalchemy as sa

revision = "20260924_0010"
down_revision = "20260913_0009"
branch_labels = None
depends_on = None


def _columns(table: str) -> set[str]:
    return {item["name"] for item in sa.inspect(op.get_bind()).get_columns(table)}


def _indexes(table: str) -> set[str]:
    bind = op.get_bind()
    names = {
        item["name"]
        for item in sa.inspect(bind).get_indexes(table)
        if item.get("name")
    }
    if bind.dialect.name == "sqlite":
        names.update(
            bind.execute(
                sa.text(
                    "SELECT name FROM sqlite_master "
                    "WHERE type = 'index' AND tbl_name = :table"
                ),
                {"table": table},
            ).scalars()
        )
    return names


def upgrade() -> None:
    if "username" not in _columns("users"):
        op.add_column("users", sa.Column("username", sa.String(80), nullable=True))
    if "ux_users_lower_username" not in _indexes("users"):
        op.execute(
            "CREATE UNIQUE INDEX ux_users_lower_username "
            "ON users (lower(username))"
        )


def downgrade() -> None:
    if "ux_users_lower_username" in _indexes("users"):
        op.drop_index("ux_users_lower_username", table_name="users")
    if "username" in _columns("users"):
        with op.batch_alter_table("users") as batch:
            batch.drop_column("username")
