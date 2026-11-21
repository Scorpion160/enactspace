"""Bound reset-code attempts across API workers.

Revision ID: 20261007_0026
Revises: 20261006_0025
"""
from alembic import op
import sqlalchemy as sa
revision = "20261007_0026"
down_revision = "20261006_0025"
branch_labels = None
depends_on = None

def upgrade():
    inspector = sa.inspect(op.get_bind())
    columns = {column["name"]: column for column in inspector.get_columns("password_reset_otps")}
    if "failed_attempts" not in columns:
        op.add_column("password_reset_otps", sa.Column("failed_attempts", sa.Integer(), nullable=False, server_default="0"))
    elif columns["failed_attempts"]["nullable"] or not isinstance(columns["failed_attempts"]["type"], sa.Integer):
        raise RuntimeError("Incompatible reset-attempt column")
    checks = {item["name"] for item in sa.inspect(op.get_bind()).get_check_constraints("password_reset_otps")}
    if "ck_password_reset_failed_attempts" not in checks:
        with op.batch_alter_table("password_reset_otps") as batch:
            batch.create_check_constraint("ck_password_reset_failed_attempts", "failed_attempts >= 0 AND failed_attempts <= 5")

def downgrade():
    with op.batch_alter_table("password_reset_otps") as batch:
        batch.drop_constraint("ck_password_reset_failed_attempts", type_="check")
        batch.drop_column("failed_attempts")
