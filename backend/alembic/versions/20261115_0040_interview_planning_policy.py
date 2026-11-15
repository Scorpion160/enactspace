"""Reusable interview planning policy, availability and internal interview mode."""
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID
revision = "20261115_0040"
down_revision = "20261115_0039"
branch_labels = None
depends_on = None

def upgrade():
    bind = op.get_bind()
    inspect = sa.inspect(bind)
    if not inspect.has_table("recruitment_interview_policies"):
        op.create_table("recruitment_interview_policies",
            sa.Column("campaign_id", GUID(), sa.ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("duration_minutes",sa.Integer(),nullable=False),
            sa.Column("daily_windows",sa.JSON(),nullable=False),
            sa.Column("default_mode",sa.String(20),nullable=False),
            sa.Column("default_location",sa.String(180)),
            sa.Column("respect_candidate_availability",sa.Boolean(),nullable=False),
            sa.Column("updated_at",sa.DateTime(),nullable=False))
    if not inspect.has_table("recruitment_jury_availability"):
        op.create_table("recruitment_jury_availability",
            sa.Column("campaign_id",GUID(),sa.ForeignKey("recruitment_campaigns.id",ondelete="CASCADE"),primary_key=True),
            sa.Column("user_id",GUID(),sa.ForeignKey("users.id",ondelete="CASCADE"),primary_key=True),
            sa.Column("windows",sa.JSON(),nullable=False),
            sa.Column("updated_at",sa.DateTime(),nullable=False))
    if "mode" not in {c["name"] for c in inspect.get_columns("recruitment_interview_drafts")}:
        op.add_column("recruitment_interview_drafts",sa.Column("mode",sa.String(20),nullable=False,server_default="in_person"))
    if "location" not in {c["name"] for c in inspect.get_columns("recruitment_interview_drafts")}:
        op.add_column("recruitment_interview_drafts",sa.Column("location",sa.String(180)))

def downgrade():
    bind=op.get_bind()
    for table in ("recruitment_jury_availability","recruitment_interview_policies"):
        if bind.execute(sa.text(f"select count(*) from {table}")).scalar():
            raise RuntimeError("Planning settings and availability must be preserved.")
    op.drop_table("recruitment_jury_availability")
    op.drop_table("recruitment_interview_policies")
    op.drop_column("recruitment_interview_drafts","location")
    op.drop_column("recruitment_interview_drafts","mode")
