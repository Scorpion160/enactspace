"""Store interview draft assignments privately without candidate notifications."""
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision = "20261115_0039"
down_revision = "20261107_0038"
branch_labels = None
depends_on = None


def upgrade():
    inspector = sa.inspect(op.get_bind())
    if not inspector.has_table("recruitment_interview_drafts"):
        op.create_table(
            "recruitment_interview_drafts",
            sa.Column("application_id", GUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("campaign_id", GUID(), sa.ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), nullable=False),
            sa.Column("starts_at", sa.DateTime(), nullable=False),
            sa.Column("ends_at", sa.DateTime(), nullable=False),
            sa.Column("jury_member_ids", sa.JSON(), nullable=False),
            sa.Column("revision", sa.Integer(), nullable=False, server_default="1"),
            sa.Column("updated_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )
    inspector = sa.inspect(op.get_bind())
    if "ix_recruitment_draft_campaign_start" not in {
        row["name"] for row in inspector.get_indexes("recruitment_interview_drafts")
    }:
        op.create_index("ix_recruitment_draft_campaign_start",
                        "recruitment_interview_drafts", ["campaign_id", "starts_at"])
    if not inspector.has_table("recruitment_interview_prep_notes"):
        op.create_table(
            "recruitment_interview_prep_notes",
            sa.Column("application_id", GUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("user_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("body", sa.Text(), nullable=False, server_default=""),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        )


def downgrade():
    bind = op.get_bind()
    for name in ("recruitment_interview_prep_notes", "recruitment_interview_drafts"):
        if bind.execute(sa.text(f"SELECT count(*) FROM {name}")).scalar():
            raise RuntimeError("Draft and personal juror notes contain data; do not downgrade destructively.")
    op.drop_table("recruitment_interview_prep_notes")
    op.drop_index("ix_recruitment_draft_campaign_start", table_name="recruitment_interview_drafts")
    op.drop_table("recruitment_interview_drafts")
