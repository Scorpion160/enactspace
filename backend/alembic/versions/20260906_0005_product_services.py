"""Add privacy-first product services.

Revision ID: 20260906_0005
Revises: 20260905_0004
Create Date: 2026-09-06
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260906_0005"
down_revision = "20260905_0004"
branch_labels = None
depends_on = None


PRODUCT_TABLES = {
    "app_installations",
    "support_tickets",
    "support_ticket_messages",
    "product_feedback",
    "app_releases",
    "app_version_policies",
}


def _schema_state() -> tuple[set[str], bool, bool]:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    preference_columns = {
        column["name"] for column in inspector.get_columns("user_preferences")
    }
    notification_columns = {
        column["name"] for column in inspector.get_columns("notifications")
    }
    return (
        PRODUCT_TABLES.intersection(tables),
        "notification_push_enabled" in preference_columns,
        "in_app_suppressed" in notification_columns,
    )


def upgrade() -> None:
    present, has_push_preference, has_suppression = _schema_state()
    if present == PRODUCT_TABLES and has_push_preference and has_suppression:
        return
    if present or has_push_preference or has_suppression:
        raise RuntimeError(
            "Partial PR-3 schema detected; manual migration review required"
        )

    op.add_column(
        "user_preferences",
        sa.Column(
            "notification_push_enabled",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "notifications",
        sa.Column(
            "in_app_suppressed",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )

    op.create_table(
        "app_installations",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("user_id", GUID(), nullable=False),
        sa.Column("installation_key", GUID(), nullable=False),
        sa.Column("platform", sa.String(20), nullable=False),
        sa.Column("app_version", sa.String(40), nullable=True),
        sa.Column("build_number", sa.Integer(), nullable=True),
        sa.Column("os_version", sa.String(80), nullable=True),
        sa.Column("device_model", sa.String(120), nullable=True),
        sa.Column("locale", sa.String(20), nullable=True),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "platform IN ('ios', 'android', 'web')",
            name="ck_app_installation_platform",
        ),
        sa.CheckConstraint(
            "build_number IS NULL OR build_number > 0",
            name="ck_app_installation_build_positive",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("installation_key", name="uq_app_installations_installation_key"),
    )
    op.create_index("ix_app_installations_user_id", "app_installations", ["user_id"])
    op.create_index(
        "ix_app_installation_user_last_seen",
        "app_installations",
        ["user_id", "last_seen_at"],
    )

    op.create_table(
        "support_tickets",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("user_id", GUID(), nullable=False),
        sa.Column("subject", sa.String(200), nullable=False),
        sa.Column("category", sa.String(30), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="open"),
        sa.Column("priority", sa.String(20), nullable=False, server_default="normal"),
        sa.Column("assigned_to_id", GUID(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
        sa.Column("closed_at", sa.DateTime(), nullable=True),
        sa.CheckConstraint(
            "category IN ('general', 'account', 'access', 'technical', 'billing', 'other')",
            name="ck_support_ticket_category",
        ),
        sa.CheckConstraint(
            "status IN ('open', 'in_progress', 'resolved', 'closed')",
            name="ck_support_ticket_status",
        ),
        sa.CheckConstraint(
            "priority IN ('low', 'normal', 'high', 'urgent')",
            name="ck_support_ticket_priority",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["assigned_to_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_support_tickets_user_id", "support_tickets", ["user_id"])
    op.create_index(
        "ix_support_tickets_assigned_to_id", "support_tickets", ["assigned_to_id"]
    )
    op.create_index(
        "ix_support_ticket_status_created", "support_tickets", ["status", "created_at"]
    )

    op.create_table(
        "support_ticket_messages",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("ticket_id", GUID(), nullable=False),
        sa.Column("author_id", GUID(), nullable=True),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["ticket_id"], ["support_tickets.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["author_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_support_ticket_messages_ticket_id", "support_ticket_messages", ["ticket_id"]
    )
    op.create_index(
        "ix_support_ticket_messages_author_id", "support_ticket_messages", ["author_id"]
    )

    op.create_table(
        "product_feedback",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("user_id", GUID(), nullable=False),
        sa.Column("category", sa.String(20), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("platform", sa.String(20), nullable=True),
        sa.Column("app_version", sa.String(40), nullable=True),
        sa.Column("build_number", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="new"),
        sa.Column("admin_note", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "category IN ('bug', 'idea', 'usability', 'other')",
            name="ck_product_feedback_category",
        ),
        sa.CheckConstraint(
            "rating IS NULL OR (rating >= 1 AND rating <= 5)",
            name="ck_product_feedback_rating",
        ),
        sa.CheckConstraint(
            "platform IS NULL OR platform IN ('ios', 'android', 'web')",
            name="ck_product_feedback_platform",
        ),
        sa.CheckConstraint(
            "build_number IS NULL OR build_number > 0",
            name="ck_product_feedback_build_positive",
        ),
        sa.CheckConstraint(
            "status IN ('new', 'reviewed', 'planned', 'closed')",
            name="ck_product_feedback_status",
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_product_feedback_user_id", "product_feedback", ["user_id"])
    op.create_index(
        "ix_product_feedback_status_created", "product_feedback", ["status", "created_at"]
    )

    op.create_table(
        "app_releases",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("platform", sa.String(20), nullable=False),
        sa.Column("version", sa.String(40), nullable=False),
        sa.Column("build_number", sa.Integer(), nullable=False),
        sa.Column("release_notes", sa.Text(), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="draft"),
        sa.Column("store_url", sa.Text(), nullable=True),
        sa.Column("published_at", sa.DateTime(), nullable=True),
        sa.Column("created_by_id", GUID(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "platform IN ('ios', 'android', 'web')", name="ck_app_release_platform"
        ),
        sa.CheckConstraint("build_number > 0", name="ck_app_release_build_positive"),
        sa.CheckConstraint(
            "status IN ('draft', 'published', 'withdrawn')",
            name="ck_app_release_status",
        ),
        sa.CheckConstraint(
            "status != 'published' OR published_at IS NOT NULL",
            name="ck_app_release_published_at",
        ),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "platform", "build_number", name="uq_app_release_platform_build"
        ),
        sa.UniqueConstraint("id", "platform", name="uq_app_release_id_platform"),
    )
    op.create_index(
        "ix_app_release_platform_build", "app_releases", ["platform", "build_number"]
    )

    op.create_table(
        "app_version_policies",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("platform", sa.String(20), nullable=False),
        sa.Column("current_release_id", GUID(), nullable=True),
        sa.Column("minimum_supported_release_id", GUID(), nullable=True),
        sa.Column("force_update_to_current", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("maintenance_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("maintenance_message", sa.Text(), nullable=True),
        sa.Column("maintenance_starts_at", sa.DateTime(), nullable=True),
        sa.Column("maintenance_ends_at", sa.DateTime(), nullable=True),
        sa.Column("updated_by_id", GUID(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "platform IN ('ios', 'android', 'web')",
            name="ck_app_version_policy_platform",
        ),
        sa.CheckConstraint(
            "((maintenance_starts_at IS NULL AND maintenance_ends_at IS NULL) OR "
            "(maintenance_starts_at IS NOT NULL AND maintenance_ends_at IS NOT NULL "
            "AND maintenance_starts_at < maintenance_ends_at))",
            name="ck_app_version_policy_maintenance_window",
        ),
        sa.ForeignKeyConstraint(
            ["current_release_id", "platform"],
            ["app_releases.id", "app_releases.platform"],
            name="fk_app_version_policy_current_release_platform",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["minimum_supported_release_id", "platform"],
            ["app_releases.id", "app_releases.platform"],
            name="fk_app_version_policy_minimum_release_platform",
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(["updated_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("platform", name="uq_app_version_policies_platform"),
    )


def downgrade() -> None:
    present, has_push_preference, has_suppression = _schema_state()
    if not present and not has_push_preference and not has_suppression:
        return
    if present != PRODUCT_TABLES or not has_push_preference or not has_suppression:
        raise RuntimeError(
            "Partial PR-3 schema detected; manual migration review required"
        )

    op.drop_table("app_version_policies")
    op.drop_index("ix_app_release_platform_build", table_name="app_releases")
    op.drop_table("app_releases")
    op.drop_index("ix_product_feedback_status_created", table_name="product_feedback")
    op.drop_index("ix_product_feedback_user_id", table_name="product_feedback")
    op.drop_table("product_feedback")
    op.drop_index("ix_support_ticket_messages_author_id", table_name="support_ticket_messages")
    op.drop_index("ix_support_ticket_messages_ticket_id", table_name="support_ticket_messages")
    op.drop_table("support_ticket_messages")
    op.drop_index("ix_support_ticket_status_created", table_name="support_tickets")
    op.drop_index("ix_support_tickets_assigned_to_id", table_name="support_tickets")
    op.drop_index("ix_support_tickets_user_id", table_name="support_tickets")
    op.drop_table("support_tickets")
    op.drop_index("ix_app_installation_user_last_seen", table_name="app_installations")
    op.drop_index("ix_app_installations_user_id", table_name="app_installations")
    op.drop_table("app_installations")
    with op.batch_alter_table("notifications") as batch_op:
        batch_op.drop_column("in_app_suppressed")
    with op.batch_alter_table("user_preferences") as batch_op:
        batch_op.drop_column("notification_push_enabled")
