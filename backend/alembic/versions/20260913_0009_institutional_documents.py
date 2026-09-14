"""Add institutional document request workflow.

Revision ID: 20260913_0009
Revises: 20260910_0008
Create Date: 2026-09-13
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260913_0009"
down_revision = "20260910_0008"
branch_labels = None
depends_on = None


REQUEST_STATUSES = (
    "draft",
    "pending_sg_validation",
    "pending_approval",
    "validated",
    "generated",
    "rejected",
    "cancelled",
)


def _status_check_sql() -> str:
    return "status IN (" + ",".join(f"'{value}'" for value in REQUEST_STATUSES) + ")"


def upgrade() -> None:
    # The historical baseline builds from live metadata. On a brand-new
    # database it can therefore create these tables before this explicit
    # revision. Existing installations at 0008 have neither table.
    # Accept only those two complete states; reject partial schemas.
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    target_tables = {
        "institutional_document_requests",
        "institutional_document_sequences",
    }
    present = target_tables.intersection(inspector.get_table_names())

    if present == target_tables:
        # The ORM metadata that the historical baseline consumes does not carry
        # this named status CHECK. Add it when the tables came from the baseline
        # so fresh databases and incremental 0008 -> 0009 upgrades enforce the
        # same workflow-state invariant.
        check_names = {
            item.get("name")
            for item in inspector.get_check_constraints(
                "institutional_document_requests"
            )
        }
        if "ck_institutional_document_request_status" not in check_names:
            op.create_check_constraint(
                "ck_institutional_document_request_status",
                "institutional_document_requests",
                _status_check_sql(),
            )
        return

    if present:
        raise RuntimeError(
            "Partial institutional document schema detected; manual migration "
            "review required: " + ", ".join(sorted(present))
        )

    op.create_table(
        "institutional_document_requests",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("template_code", sa.String(length=80), nullable=False),
        sa.Column("template_version", sa.String(length=20), nullable=False, server_default="2.0"),
        sa.Column("status", sa.String(length=40), nullable=False, server_default="draft"),
        sa.Column("payload_json", sa.JSON(), nullable=False),
        sa.Column("requested_by", GUID(), nullable=False),
        sa.Column("submitted_by", GUID(), nullable=True),
        sa.Column("submitted_at", sa.DateTime(), nullable=True),
        sa.Column("sg_validated_by", GUID(), nullable=True),
        sa.Column("sg_validated_at", sa.DateTime(), nullable=True),
        sa.Column("approved_by", GUID(), nullable=True),
        sa.Column("approved_at", sa.DateTime(), nullable=True),
        sa.Column("rejected_by", GUID(), nullable=True),
        sa.Column("rejected_at", sa.DateTime(), nullable=True),
        sa.Column("rejection_reason", sa.Text(), nullable=True),
        sa.Column("cancelled_by", GUID(), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(), nullable=True),
        sa.Column("cancellation_reason", sa.Text(), nullable=True),
        sa.Column("pole_id", GUID(), nullable=True),
        sa.Column("project_id", GUID(), nullable=True),
        sa.Column("event_id", GUID(), nullable=True),
        sa.Column("season_id", GUID(), nullable=True),
        sa.Column("sequence_number", sa.Integer(), nullable=True),
        sa.Column("official_reference", sa.String(length=160), nullable=True),
        sa.Column("generated_document_id", GUID(), nullable=True),
        sa.Column("generated_at", sa.DateTime(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.CheckConstraint(
            _status_check_sql(),
            name="ck_institutional_document_request_status",
        ),
        sa.ForeignKeyConstraint(["requested_by"], ["users.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["submitted_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["sg_validated_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["approved_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["rejected_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["cancelled_by"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["pole_id"], ["poles.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["project_id"], ["projects.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["event_id"], ["events.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["season_id"], ["seasons.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["generated_document_id"], ["documents.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "official_reference",
            name="uq_institutional_document_official_reference",
        ),
        sa.UniqueConstraint(
            "generated_document_id",
            name="uq_institutional_document_generated_document",
        ),
    )
    op.create_index(
        "ix_institutional_document_requests_template_code",
        "institutional_document_requests",
        ["template_code"],
    )
    op.create_index(
        "ix_institutional_document_requests_status",
        "institutional_document_requests",
        ["status"],
    )
    op.create_index(
        "ix_institutional_document_requests_requested_by",
        "institutional_document_requests",
        ["requested_by"],
    )
    op.create_index(
        "ix_institutional_document_requests_pole_id",
        "institutional_document_requests",
        ["pole_id"],
    )
    op.create_index(
        "ix_institutional_document_requests_project_id",
        "institutional_document_requests",
        ["project_id"],
    )
    op.create_index(
        "ix_institutional_document_requests_season_id",
        "institutional_document_requests",
        ["season_id"],
    )

    op.create_table(
        "institutional_document_sequences",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("season_id", GUID(), nullable=False),
        sa.Column("template_code", sa.String(length=80), nullable=False),
        sa.Column("last_number", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.ForeignKeyConstraint(["season_id"], ["seasons.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "season_id",
            "template_code",
            name="uq_institutional_document_sequence_season_template",
        ),
    )


def downgrade() -> None:
    op.drop_table("institutional_document_sequences")
    op.drop_index(
        "ix_institutional_document_requests_season_id",
        table_name="institutional_document_requests",
    )
    op.drop_index(
        "ix_institutional_document_requests_project_id",
        table_name="institutional_document_requests",
    )
    op.drop_index(
        "ix_institutional_document_requests_pole_id",
        table_name="institutional_document_requests",
    )
    op.drop_index(
        "ix_institutional_document_requests_requested_by",
        table_name="institutional_document_requests",
    )
    op.drop_index(
        "ix_institutional_document_requests_status",
        table_name="institutional_document_requests",
    )
    op.drop_index(
        "ix_institutional_document_requests_template_code",
        table_name="institutional_document_requests",
    )
    op.drop_table("institutional_document_requests")
