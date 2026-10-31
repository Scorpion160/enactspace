"""Reusable jury teams and immutable appointment composition references."""
import importlib.util
from pathlib import Path
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision = "20261031_0033"
down_revision = "20261031_0032"
branch_labels = None
depends_on = None


def _tables():
    return [
        ("recruitment_jury_teams", [
            sa.Column("id", GUID(), primary_key=True),
            sa.Column("campaign_id", GUID(), sa.ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), nullable=False),
            sa.Column("name", sa.String(120), nullable=False),
            sa.Column("name_key", sa.String(240), nullable=False),
            sa.Column("is_active", sa.Boolean(), nullable=False),
            sa.Column("revision", sa.Integer(), nullable=False),
            sa.Column("created_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
            sa.Column("created_at", sa.DateTime(), nullable=False),
            sa.Column("updated_at", sa.DateTime(), nullable=False),
        ], [("campaign_id", "name_key")]),
        ("recruitment_jury_team_members", [
            sa.Column("team_id", GUID(), sa.ForeignKey("recruitment_jury_teams.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("jury_member_id", GUID(), sa.ForeignKey("recruitment_jury_members.id", ondelete="CASCADE"), primary_key=True),
        ], []),
        ("application_interview_teams", [
            sa.Column("application_id", GUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("team_id", GUID(), sa.ForeignKey("recruitment_jury_teams.id", ondelete="CASCADE"), nullable=False),
            sa.Column("revision", sa.Integer(), nullable=False),
            sa.Column("name", sa.String(120), nullable=False),
        ], []),
    ]


def upgrade():
    # Reuse only the frozen structural validator of the previous revision.
    # 0001 can bootstrap current metadata; both that path and genuine 0032
    # databases must be checked before creating missing objects.
    path = Path(__file__).with_name("20261031_0032_recruitment_jury_personality.py")
    spec = importlib.util.spec_from_file_location("jury_0032_validation", path)
    previous = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(previous)
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    for name, columns, unique_keys in _tables():
        if inspector.has_table(name):
            previous._validate_table(bind, name, columns, unique_keys)
    indices = inspector.get_indexes("application_interview_teams") if inspector.has_table("application_interview_teams") else []
    index = next((item for item in indices if item["name"] == "ix_application_interview_team"), None)
    if index and (index["column_names"] != ["team_id"] or index["unique"]):
        raise RuntimeError("Incompatible_recruitment_team_index")
    for name, columns, unique_keys in _tables():
        if not inspector.has_table(name):
            constraints = [sa.UniqueConstraint(*key, name="uq_recruitment_team_name") for key in unique_keys]
            op.create_table(name, *columns, *constraints)
    if not index:
        op.create_index("ix_application_interview_team", "application_interview_teams", ["team_id"])


def downgrade():
    bind = op.get_bind()
    for name, _, _ in _tables():
        if bind.execute(sa.text("SELECT COUNT(*) FROM " + name)).scalar():
            raise RuntimeError("Jury team history exists; keep schema 0033 when rolling back application code.")
    for name, _, _ in reversed(_tables()):
        op.drop_table(name)
