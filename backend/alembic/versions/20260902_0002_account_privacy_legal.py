"""Account, privacy, legal documents and auth sessions.

Revision ID: 20260902_0002
Revises: 20260713_0001
Create Date: 2026-09-02
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260902_0002"
down_revision = "20260713_0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # The historical baseline builds from live metadata. On a brand-new database
    # it can therefore create every PR-2A table before this explicit revision.
    # Existing installations have none of them. Accept only those two complete
    # states; a partial state requires operator review instead of guessing.
    target_tables = {
        "user_preferences",
        "legal_documents",
        "legal_acceptances",
        "account_deletion_requests",
        "auth_sessions",
    }
    present = target_tables.intersection(sa.inspect(op.get_bind()).get_table_names())
    if present == target_tables:
        return
    if present:
        raise RuntimeError(
            "Partial PR-2A schema detected; manual migration review required: "
            + ", ".join(sorted(present))
        )

    op.create_table(
        "user_preferences",
        sa.Column("user_id", GUID(), nullable=False),
        sa.Column("locale", sa.String(10), nullable=False, server_default="fr"),
        sa.Column("theme", sa.String(10), nullable=False, server_default="system"),
        sa.Column("notification_in_app_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("notification_email_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("locale IN ('fr', 'en')", name="ck_user_preferences_locale"),
        sa.CheckConstraint("theme IN ('system', 'light', 'dark')", name="ck_user_preferences_theme"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("user_id"),
    )

    op.create_table(
        "legal_documents",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("document_type", sa.String(40), nullable=False),
        sa.Column("version", sa.String(40), nullable=False),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("effective_at", sa.DateTime(), nullable=True),
        sa.Column("published_at", sa.DateTime(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("requires_acceptance", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("document_type IN ('privacy_policy', 'terms_of_use')", name="ck_legal_document_type"),
        sa.CheckConstraint("is_active = false OR published_at IS NOT NULL", name="ck_legal_active_is_published"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("document_type", "version", name="uq_legal_document_type_version"),
    )
    op.create_index("ix_legal_document_type_published", "legal_documents", ["document_type", "published_at"])
    op.create_index(
        "uq_legal_document_active_type",
        "legal_documents",
        ["document_type"],
        unique=True,
        postgresql_where=sa.text("is_active = true"),
        sqlite_where=sa.text("is_active = 1"),
    )

    op.create_table(
        "legal_acceptances",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("user_id", GUID(), nullable=False),
        sa.Column("legal_document_id", GUID(), nullable=False),
        sa.Column("document_version", sa.String(40), nullable=False),
        sa.Column("source", sa.String(40), nullable=True),
        sa.Column("accepted_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("source IS NULL OR source IN ('web', 'android', 'ios', 'api')", name="ck_legal_acceptance_source"),
        sa.ForeignKeyConstraint(["legal_document_id"], ["legal_documents.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "legal_document_id", name="uq_legal_acceptance_user_document"),
    )
    op.create_index("ix_legal_acceptances_user_id", "legal_acceptances", ["user_id"])

    op.create_table(
        "account_deletion_requests",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("user_id", GUID(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("requested_at", sa.DateTime(), nullable=False),
        sa.Column("processed_at", sa.DateTime(), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(), nullable=True),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("admin_note", sa.Text(), nullable=True),
        sa.CheckConstraint("status IN ('pending', 'cancelled', 'approved', 'completed', 'rejected')", name="ck_account_deletion_status"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_account_deletion_requests_user_id", "account_deletion_requests", ["user_id"])
    op.create_index("ix_account_deletion_user_status", "account_deletion_requests", ["user_id", "status"])
    op.create_index(
        "uq_account_deletion_pending_user",
        "account_deletion_requests",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("status = 'pending'"),
        sqlite_where=sa.text("status = 'pending'"),
    )

    op.create_table(
        "auth_sessions",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("user_id", GUID(), nullable=False),
        sa.Column("refresh_token_hash", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("expires_at", sa.DateTime(), nullable=False),
        sa.Column("last_used_at", sa.DateTime(), nullable=True),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("user_agent", sa.String(255), nullable=True),
        sa.Column("platform", sa.String(40), nullable=True),
        sa.CheckConstraint("platform IS NULL OR platform IN ('web', 'android', 'ios', 'api', 'unknown')", name="ck_auth_session_platform"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("refresh_token_hash"),
    )
    op.create_index("ix_auth_sessions_user_id", "auth_sessions", ["user_id"])
    op.create_index("ix_auth_sessions_expires_at", "auth_sessions", ["expires_at"])
    op.create_index("ix_auth_sessions_revoked_at", "auth_sessions", ["revoked_at"])


def downgrade() -> None:
    target_tables = {
        "user_preferences",
        "legal_documents",
        "legal_acceptances",
        "account_deletion_requests",
        "auth_sessions",
    }
    present = target_tables.intersection(sa.inspect(op.get_bind()).get_table_names())
    if not present:
        return
    if present != target_tables:
        raise RuntimeError(
            "Partial PR-2A schema detected; manual migration review required: "
            + ", ".join(sorted(present))
        )
    op.drop_index("ix_auth_sessions_revoked_at", table_name="auth_sessions")
    op.drop_index("ix_auth_sessions_expires_at", table_name="auth_sessions")
    op.drop_index("ix_auth_sessions_user_id", table_name="auth_sessions")
    op.drop_table("auth_sessions")
    op.drop_index("uq_account_deletion_pending_user", table_name="account_deletion_requests")
    op.drop_index("ix_account_deletion_user_status", table_name="account_deletion_requests")
    op.drop_index("ix_account_deletion_requests_user_id", table_name="account_deletion_requests")
    op.drop_table("account_deletion_requests")
    op.drop_index("ix_legal_acceptances_user_id", table_name="legal_acceptances")
    op.drop_table("legal_acceptances")
    op.drop_index("uq_legal_document_active_type", table_name="legal_documents")
    op.drop_index("ix_legal_document_type_published", table_name="legal_documents")
    op.drop_table("legal_documents")
    op.drop_table("user_preferences")
