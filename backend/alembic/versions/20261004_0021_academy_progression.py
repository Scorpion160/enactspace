"""Persistent and editable Academy prerequisite courses."""
from alembic import op
import sqlalchemy as sa

revision = "20261004_0021"
down_revision = "20261004_0020"
branch_labels = None
depends_on = None


def upgrade():
    columns = {item["name"] for item in sa.inspect(op.get_bind()).get_columns("academy_courses")}
    if "prerequisite_course_ids" not in columns:
        op.add_column("academy_courses", sa.Column("prerequisite_course_ids", sa.JSON(), nullable=True))


def downgrade():
    columns = {item["name"] for item in sa.inspect(op.get_bind()).get_columns("academy_courses")}
    if "prerequisite_course_ids" in columns:
        op.drop_column("academy_courses", "prerequisite_course_ids")
