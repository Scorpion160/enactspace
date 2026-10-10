"""Add durable transactional email outbox.

Revision ID: 20260926_0014
Revises: 20260926_0013
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID

revision = "20260926_0014"
down_revision = "20260926_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if "email_deliveries" in inspector.get_table_names():
        return

    op.create_table(
        "email_deliveries",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("notification_id", GUID(), nullable=True),
        sa.Column("user_id", GUID(), nullable=True),
        sa.Column("recipient_email", sa.String(320), nullable=False),
        sa.Column("subject", sa.String(255), nullable=False),
        sa.Column("text_body", sa.Text(), nullable=False),
        sa.Column("html_body", sa.Text(), nullable=True),
        sa.Column("dedupe_key", sa.String(255), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("next_attempt_at", sa.DateTime(), nullable=False),
        sa.Column("processing_started_at", sa.DateTime(), nullable=True),
        sa.Column("provider_message_id", sa.String(255), nullable=True),
        sa.Column("last_error_code", sa.String(120), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("sent_at", sa.DateTime(), nullable=True),
        sa.CheckConstraint(
            "status IN ('pending', 'processing', 'sent', 'retry', 'cancelled', 'dead')",
            name="ck_email_delivery_status",
        ),
        sa.CheckConstraint(
            "attempt_count >= 0",
            name="ck_email_delivery_attempt_count",
        ),
        sa.CheckConstraint(
            "((status = 'processing' AND processing_started_at IS NOT NULL) OR "
            "(status != 'processing' AND processing_started_at IS NULL))",
            name="ck_email_delivery_processing_lease",
        ),
        sa.ForeignKeyConstraint(
            ["notification_id"], ["notifications.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("dedupe_key", name="uq_email_deliveries_dedupe_key"),
    )
    op.create_index(
        "ix_email_deliveries_notification_id",
        "email_deliveries",
        ["notification_id"],
    )
    op.create_index("ix_email_deliveries_user_id", "email_deliveries", ["user_id"])
    op.create_index(
        "ix_email_delivery_claim",
        "email_deliveries",
        ["status", "next_attempt_at", "processing_started_at", "created_at"],
    )


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    if "email_deliveries" not in inspector.get_table_names():
        return
    op.drop_index("ix_email_delivery_claim", table_name="email_deliveries")
    op.drop_index("ix_email_deliveries_user_id", table_name="email_deliveries")
    op.drop_index("ix_email_deliveries_notification_id", table_name="email_deliveries")
    op.drop_table("email_deliveries")
