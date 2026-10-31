"""Campaign juries, interview logistics and versioned self-report drafts."""
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision = "20261031_0032"
down_revision = "20261007_0031"
branch_labels = None
depends_on = None


def upgrade():
    for column in (
        sa.Column("campus_resident", sa.Boolean(), nullable=True),
        sa.Column("interview_preferences", sa.JSON(), nullable=True),
        sa.Column("interview_availability", sa.Text(), nullable=True),
        sa.Column("interview_end_at", sa.DateTime(), nullable=True),
        sa.Column("interview_mode", sa.String(20), nullable=True),
    ):
        op.add_column("applications", column)
    op.create_table("recruitment_jury_members",
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("campaign_id", GUID(), sa.ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("appointed_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("revoked_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime()),
        sa.UniqueConstraint("campaign_id", "user_id", name="uq_recruitment_jury_campaign_user"))
    op.create_index("ix_recruitment_jury_active_user", "recruitment_jury_members", ["user_id", "is_active"])
    op.create_table("application_interview_jurors",
        sa.Column("application_id", GUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("jury_member_id", GUID(), sa.ForeignKey("recruitment_jury_members.id", ondelete="CASCADE"), primary_key=True))
    op.create_table("application_personality",
        sa.Column("application_id", GUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("instrument_version", sa.String(64), nullable=False),
        sa.Column("instrument_snapshot", sa.JSON(), nullable=False),
        sa.Column("answers", sa.JSON(), nullable=False),
        sa.Column("scenario_answers", sa.JSON(), nullable=False),
        sa.Column("results", sa.JSON()),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("invited_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("invited_at", sa.DateTime(), nullable=False),
        sa.Column("due_at", sa.DateTime()),
        sa.Column("consent_at", sa.DateTime()),
        sa.Column("submitted_at", sa.DateTime()),
        sa.Column("declined_at", sa.DateTime()),
        sa.Column("updated_at", sa.DateTime(), nullable=False))


def downgrade():
    # A rollback must not silently erase jury history or candidate responses.
    bind = op.get_bind()
    for table in ("recruitment_jury_members", "application_interview_jurors", "application_personality"):
        if bind.execute(sa.text("SELECT COUNT(*) FROM " + table)).scalar():
            raise RuntimeError("Recruitment history exists; keep schema 0032 when rolling back application code.")
    for table in ("application_personality", "application_interview_jurors", "recruitment_jury_members"):
        op.drop_table(table)
    with op.batch_alter_table("applications") as batch:
        for name in ("campus_resident", "interview_preferences", "interview_availability", "interview_end_at", "interview_mode"):
            batch.drop_column(name)
