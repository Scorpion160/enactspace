"""Preserve historical reviews and freeze a version for structured recruitment."""
from alembic import op
import sqlalchemy as sa

revision = "20261006_0023"
down_revision = "20261004_0022"
branch_labels = None
depends_on = None

def upgrade():
    bind = op.get_bind()
    for table, column in [
        ("recruitment_campaigns", sa.Column("screening_rubric_version", sa.String(64), nullable=True)),
        ("application_reviews", sa.Column("criteria_assessment", sa.JSON, nullable=True)),
    ]:
        names = {row["name"] for row in sa.inspect(bind).get_columns(table)}
        if column.name not in names:
            op.add_column(table, column)

def downgrade():
    for table, name in [
        ("application_reviews", "criteria_assessment"),
        ("recruitment_campaigns", "screening_rubric_version"),
    ]:
        with op.batch_alter_table(table) as batch:
            batch.drop_column(name)
