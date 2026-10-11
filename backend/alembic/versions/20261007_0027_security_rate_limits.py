"""Persistent shared quotas for public sensitive requests."""
from alembic import op
import sqlalchemy as sa
revision="20261007_0027"
down_revision="20261007_0026"
branch_labels=None
depends_on=None

def upgrade():
    inspector = sa.inspect(op.get_bind())
    if inspector.has_table("security_rate_limits"):
        columns = {item["name"]: item for item in inspector.get_columns("security_rate_limits")}
        checks = {item["name"] for item in inspector.get_check_constraints("security_rate_limits")}
        indexes = {item["name"] for item in inspector.get_indexes("security_rate_limits")}
        if (set(columns) != {"key", "count", "expires_at"}
                or any(item["nullable"] for item in columns.values())
                or not isinstance(columns["count"]["type"], sa.Integer)
                or "ck_security_rate_limit_count" not in checks
                or "ix_security_rate_limits_expires_at" not in indexes):
            raise RuntimeError("Partial or incompatible security-quota schema")
        return
    op.create_table("security_rate_limits",
        sa.Column("key",sa.String(64),primary_key=True),
        sa.Column("count",sa.Integer(),nullable=False),
        sa.Column("expires_at",sa.DateTime(),nullable=False),
        sa.CheckConstraint("count > 0",name="ck_security_rate_limit_count"))
    op.create_index("ix_security_rate_limits_expires_at","security_rate_limits",["expires_at"])

def downgrade():
    op.drop_index("ix_security_rate_limits_expires_at",table_name="security_rate_limits")
    op.drop_table("security_rate_limits")
