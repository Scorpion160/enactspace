"""Link each candidate interview to its own private EnactMeet room."""
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision = "20261106_0037"
down_revision = "20261105_0036"
branch_labels = None
depends_on = None


def upgrade():
    columns = {column["name"] for column in sa.inspect(op.get_bind()).get_columns("applications")}
    if "interview_meeting_id" not in columns:
        with op.batch_alter_table("applications") as batch:
            batch.add_column(sa.Column("interview_meeting_id", GUID(), nullable=True))
            batch.create_foreign_key("fk_application_interview_meeting", "meetings", ["interview_meeting_id"], ["id"], ondelete="SET NULL")
    indexes = {index['name'] for index in sa.inspect(op.get_bind()).get_indexes('applications')}
    if 'ix_applications_interview_meeting_id' not in indexes:
        op.create_index('ix_applications_interview_meeting_id', 'applications', ['interview_meeting_id'])


def downgrade():
    op.drop_index('ix_applications_interview_meeting_id', table_name='applications')
    # Fresh bootstraps use the model's unnamed FK. Name it during reflection
    # so the constraint is removed together with its column on SQLite as well.
    convention = {"fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s"}
    foreign_keys = sa.inspect(op.get_bind()).get_foreign_keys("applications")
    with op.batch_alter_table("applications", naming_convention=convention) as batch:
        for constraint in foreign_keys:
            if constraint.get("constrained_columns") == ["interview_meeting_id"]:
                batch.drop_constraint(constraint.get("name") or "fk_applications_interview_meeting_id_meetings", type_="foreignkey")
        batch.drop_column("interview_meeting_id")
