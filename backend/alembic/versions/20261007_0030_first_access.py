"""Persist activation and first-login state, including existing accounts."""
from alembic import op
import sqlalchemy as sa
revision="20261007_0030"
down_revision="20261007_0029"
branch_labels=None
depends_on=None

def upgrade():
    bind=op.get_bind()
    columns={x["name"] for x in sa.inspect(bind).get_columns("users")}
    for column in (
        sa.Column("credential_setup_required",sa.Boolean(),nullable=False,server_default=sa.false()),
        sa.Column("credential_activated_at",sa.DateTime(),nullable=True),
        sa.Column("onboarding_required",sa.Boolean(),nullable=False,server_default=sa.false()),
        sa.Column("onboarding_completed_at",sa.DateTime(),nullable=True),
    ):
        if column.name not in columns:op.add_column("users",column)
    from app.models.first_access import ActivationChallenge
    ActivationChallenge.__table__.create(bind,checkfirst=True)
    # Existing administrator access remains available for the deployment bootstrap.
    op.execute(sa.text("""UPDATE users SET onboarding_required=true WHERE status IN ('active','alumni')
        AND NOT EXISTS (SELECT 1 FROM user_roles JOIN roles ON roles.id=user_roles.role_id
                        WHERE user_roles.user_id=users.id AND roles.name='administrateur')
        AND onboarding_completed_at IS NULL"""))
    op.execute(sa.text("""UPDATE users SET credential_setup_required=true WHERE status IN ('active','alumni')
        AND credential_activated_at IS NULL AND onboarding_completed_at IS NULL
        AND NOT EXISTS (SELECT 1 FROM auth_sessions WHERE auth_sessions.user_id=users.id)
        AND NOT EXISTS (SELECT 1 FROM user_roles JOIN roles ON roles.id=user_roles.role_id
                        WHERE user_roles.user_id=users.id AND roles.name='administrateur')"""))

def downgrade():
    # Preserve first-access history; the preceding release ignores these extra fields.
    pass
