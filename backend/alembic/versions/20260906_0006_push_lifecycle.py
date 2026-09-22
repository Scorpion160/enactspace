"""Add encrypted push tokens and the transactional push outbox.

Revision ID: 20260906_0006
Revises: 20260906_0005
Create Date: 2026-09-06
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260906_0006"
down_revision = "20260906_0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    installation_columns = {
        column["name"] for column in inspector.get_columns("app_installations")
    }
    push_columns = {
        "push_provider", "push_token_ciphertext", "push_token_hash",
        "push_token_updated_at",
    }
    has_outbox = "push_deliveries" in inspector.get_table_names()
    if push_columns.issubset(installation_columns) and has_outbox:
        return
    if push_columns.intersection(installation_columns) or has_outbox:
        raise RuntimeError("Partial PR-5 schema detected; manual migration review required")

    with op.batch_alter_table("app_installations") as batch_op:
        batch_op.add_column(sa.Column("push_provider", sa.String(20), nullable=True))
        batch_op.add_column(sa.Column("push_token_ciphertext", sa.Text(), nullable=True))
        batch_op.add_column(sa.Column("push_token_hash", sa.String(64), nullable=True))
        batch_op.add_column(sa.Column("push_token_updated_at", sa.DateTime(), nullable=True))
        batch_op.create_check_constraint(
            "ck_app_installation_push_provider",
            "push_provider IS NULL OR push_provider = 'fcm'",
        )
        batch_op.create_check_constraint(
            "ck_app_installation_push_material",
            "((push_provider IS NULL AND push_token_ciphertext IS NULL AND "
            "push_token_hash IS NULL AND push_token_updated_at IS NULL) OR "
            "(push_provider = 'fcm' AND push_token_ciphertext IS NOT NULL AND "
            "push_token_hash IS NOT NULL AND push_token_updated_at IS NOT NULL))",
        )
        batch_op.create_unique_constraint(
            "uq_app_installations_push_token_hash", ["push_token_hash"]
        )

    op.create_table(
        "push_deliveries",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("notification_id", GUID(), nullable=False),
        sa.Column("installation_id", GUID(), nullable=False),
        sa.Column("token_hash_snapshot", sa.String(64), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("next_attempt_at", sa.DateTime(), nullable=False),
        sa.Column("processing_started_at", sa.DateTime(), nullable=True),
        sa.Column("provider_message_id", sa.String(255), nullable=True),
        sa.Column("last_error_code", sa.String(80), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("sent_at", sa.DateTime(), nullable=True),
        sa.CheckConstraint(
            "status IN ('pending', 'processing', 'sent', 'retry', 'cancelled', 'dead')",
            name="ck_push_delivery_status",
        ),
        sa.CheckConstraint("attempt_count >= 0", name="ck_push_delivery_attempt_count"),
        sa.CheckConstraint(
            "((status = 'processing' AND processing_started_at IS NOT NULL) OR "
            "(status != 'processing' AND processing_started_at IS NULL))",
            name="ck_push_delivery_processing_lease",
        ),
        sa.ForeignKeyConstraint(["notification_id"], ["notifications.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["installation_id"], ["app_installations.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "notification_id", "installation_id", "token_hash_snapshot",
            name="uq_push_delivery_notification_installation_token",
        ),
    )
    op.create_index("ix_push_deliveries_notification_id", "push_deliveries", ["notification_id"])
    op.create_index("ix_push_deliveries_installation_id", "push_deliveries", ["installation_id"])
    op.create_index(
        "ix_push_delivery_claim", "push_deliveries",
        ["status", "next_attempt_at", "processing_started_at", "created_at"],
    )


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    installation_columns = {
        column["name"] for column in inspector.get_columns("app_installations")
    }
    push_columns = {
        "push_provider", "push_token_ciphertext", "push_token_hash",
        "push_token_updated_at",
    }
    has_outbox = "push_deliveries" in inspector.get_table_names()
    if not push_columns.intersection(installation_columns) and not has_outbox:
        return
    if not push_columns.issubset(installation_columns) or not has_outbox:
        raise RuntimeError("Partial PR-5 schema detected; manual migration review required")
    op.drop_index("ix_push_delivery_claim", table_name="push_deliveries")
    op.drop_index("ix_push_deliveries_installation_id", table_name="push_deliveries")
    op.drop_index("ix_push_deliveries_notification_id", table_name="push_deliveries")
    op.drop_table("push_deliveries")
    with op.batch_alter_table("app_installations") as batch_op:
        batch_op.drop_constraint("uq_app_installations_push_token_hash", type_="unique")
        batch_op.drop_constraint("ck_app_installation_push_material", type_="check")
        batch_op.drop_constraint("ck_app_installation_push_provider", type_="check")
        batch_op.drop_column("push_token_updated_at")
        batch_op.drop_column("push_token_hash")
        batch_op.drop_column("push_token_ciphertext")
        batch_op.drop_column("push_provider")
