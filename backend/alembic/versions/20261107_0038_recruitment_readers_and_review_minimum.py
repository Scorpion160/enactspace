"""Track campaign-scoped reader permissions and enforce three screening reviews.

Production had an operationally applied viewer table already.  The
Existence checks reconcile the Alembic history without dropping data.
"""
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision = "20261107_0038"
down_revision = "20261106_0037"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    if not inspector.has_table("recruitment_viewer_access"):
        utc_default = sa.text(
            "(now() AT TIME ZONE 'UTC')"
            if bind.dialect.name == "postgresql"
            else "CURRENT_TIMESTAMP"
        )
        op.create_table(
            "recruitment_viewer_access",
            sa.Column("id", GUID(), primary_key=True),
            sa.Column("campaign_id", GUID(), sa.ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), nullable=False),
            sa.Column("user_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("granted_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
            sa.Column("revoked_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
            sa.Column("granted_at", sa.DateTime(), nullable=False, server_default=utc_default),
            sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=utc_default),
            sa.Column("revoked_at", sa.DateTime()),
            sa.UniqueConstraint("campaign_id", "user_id", name="uq_recruitment_viewer_campaign_user"),
        )
    if not any(
        index["name"] == "ix_recruitment_viewer_active_user"
        for index in inspector.get_indexes("recruitment_viewer_access")
    ):
        op.create_index(
            "ix_recruitment_viewer_active_user", "recruitment_viewer_access", ["user_id", "is_active"]
        )
    with op.batch_alter_table("recruitment_campaigns") as batch:
        batch.alter_column(
            "screening_min_reviews", existing_type=sa.Integer(), server_default=sa.text("3")
        )
    op.execute("""
        UPDATE recruitment_campaigns
        SET screening_min_reviews = 3
        WHERE is_active IS TRUE
          AND selection_policy_version = 'blind-selection-v1'
          AND screening_min_reviews < 3
    """)


def downgrade():
    bind = op.get_bind()
    active = bind.execute(sa.text("""
        SELECT COUNT(*) FROM recruitment_viewer_access
    """)).scalar_one()
    if active:
        raise RuntimeError(
            "Cannot downgrade while any campaign access grants exist; "
            "the rollback must preserve the history of active and revoked grants."
        )
    op.drop_table("recruitment_viewer_access")
    with op.batch_alter_table("recruitment_campaigns") as batch:
        batch.alter_column(
            "screening_min_reviews", existing_type=sa.Integer(), server_default=sa.text("2")
        )
