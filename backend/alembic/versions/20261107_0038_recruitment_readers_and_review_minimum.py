"""Track campaign-scoped reader permissions and enforce three screening reviews.

Production had an operationally applied viewer table already.  The
IF NOT EXISTS DDL reconciles the Alembic history without dropping data.
"""
from alembic import op
import sqlalchemy as sa

revision = "20261107_0038"
down_revision = "20261106_0037"
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        CREATE TABLE IF NOT EXISTS recruitment_viewer_access (
            id uuid PRIMARY KEY,
            campaign_id uuid NOT NULL
                REFERENCES recruitment_campaigns(id) ON DELETE CASCADE,
            user_id uuid NOT NULL
                REFERENCES users(id) ON DELETE CASCADE,
            is_active boolean NOT NULL DEFAULT TRUE,
            granted_by uuid NULL REFERENCES users(id) ON DELETE SET NULL,
            revoked_by uuid NULL REFERENCES users(id) ON DELETE SET NULL,
            granted_at timestamp without time zone NOT NULL
                DEFAULT (now() AT TIME ZONE 'UTC'),
            updated_at timestamp without time zone NOT NULL
                DEFAULT (now() AT TIME ZONE 'UTC'),
            revoked_at timestamp without time zone NULL,
            CONSTRAINT uq_recruitment_viewer_campaign_user
                UNIQUE (campaign_id, user_id)
        )
    """)
    op.execute("""
        CREATE INDEX IF NOT EXISTS ix_recruitment_viewer_active_user
        ON recruitment_viewer_access (user_id, is_active)
    """)
    op.execute("""
        ALTER TABLE recruitment_campaigns
        ALTER COLUMN screening_min_reviews SET DEFAULT 3
    """)
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
            "revoke authorizations through the app first."
        )
    op.execute("DROP TABLE IF EXISTS recruitment_viewer_access")
    op.execute("""
        ALTER TABLE recruitment_campaigns
        ALTER COLUMN screening_min_reviews SET DEFAULT 2
    """)
