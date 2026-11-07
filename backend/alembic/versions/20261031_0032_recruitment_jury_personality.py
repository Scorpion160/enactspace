"""Campaign juries, interview logistics and versioned self-report drafts."""
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision = "20261031_0032"
down_revision = "20261007_0031"
branch_labels = None
depends_on = None


def _application_columns():
    return (
        sa.Column("campus_resident", sa.Boolean(), nullable=True),
        sa.Column("interview_preferences", sa.JSON(), nullable=True),
        sa.Column("interview_availability", sa.Text(), nullable=True),
        sa.Column("interview_end_at", sa.DateTime(), nullable=True),
        sa.Column("interview_mode", sa.String(20), nullable=True),
    )


def _tables():
    return [
      ("recruitment_jury_members", [
        sa.Column("id", GUID(), primary_key=True),
        sa.Column("campaign_id", GUID(), sa.ForeignKey("recruitment_campaigns.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("appointed_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("revoked_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("revoked_at", sa.DateTime()),
      ], [("campaign_id", "user_id")]),
      ("application_interview_jurors", [
        sa.Column("application_id", GUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("jury_member_id", GUID(), sa.ForeignKey("recruitment_jury_members.id", ondelete="CASCADE"), primary_key=True),
      ], []),
      ("application_personality", [
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
        sa.Column("updated_at", sa.DateTime(), nullable=False),
      ], []),
    ]


def _validate_columns(bind, table, columns, *, require_all):
    existing = {item["name"]: item for item in sa.inspect(bind).get_columns(table)}
    for column in columns:
        actual = existing.get(column.name)
        if actual is None:
            if require_all:
                raise RuntimeError("Incompatible_recruitment_schema:" + table + "." + column.name)
            continue
        actual_type = str(actual["type"].compile(dialect=bind.dialect)).upper()
        expected_type = str(column.type.compile(dialect=bind.dialect)).upper()
        if actual_type != expected_type or actual["nullable"] != column.nullable:
            raise RuntimeError("Incompatible_recruitment_schema:" + table + "." + column.name)
    return existing


def _validate_table(bind, name, columns, unique_keys):
    _validate_columns(bind, name, columns, require_all=True)
    inspector = sa.inspect(bind)
    primary = inspector.get_pk_constraint(name).get("constrained_columns") or []
    if set(primary) != {column.name for column in columns if column.primary_key}:
        raise RuntimeError("Incompatible_recruitment_primary_key:" + name)
    existing_unique = {tuple(item["column_names"]) for item in inspector.get_unique_constraints(name)}
    if any(key not in existing_unique for key in unique_keys):
        raise RuntimeError("Incompatible_recruitment_unique_key:" + name)
    foreign_keys = inspector.get_foreign_keys(name)
    for column in columns:
        for foreign in column.foreign_keys:
            table, key = foreign.target_fullname.rsplit(".", 1)
            matches = [item for item in foreign_keys
                if item["constrained_columns"] == [column.name]
                and item["referred_table"] == table
                and item["referred_columns"] == [key]]
            if not any((item.get("options", {}).get("ondelete") or "").upper()
                       == (foreign.ondelete or "").upper() for item in matches):
                raise RuntimeError("Incompatible_recruitment_foreign_key:" + name + "." + column.name)


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    # Revision 0001 uses current Base.metadata.create_all on a fresh database.
    # It may already have created these exact objects. A genuine 0031 database
    # does not contain them. Validate existing structures before changing either.
    application_columns = _application_columns()
    existing_columns = _validate_columns(bind, "applications", application_columns, require_all=False)
    tables = _tables()
    for name, columns, unique_keys in tables:
        if inspector.has_table(name):
            _validate_table(bind, name, columns, unique_keys)
    indices = inspector.get_indexes("recruitment_jury_members") if inspector.has_table("recruitment_jury_members") else []
    existing_index = next((item for item in indices if item["name"] == "ix_recruitment_jury_active_user"), None)
    if existing_index and (existing_index["column_names"] != ["user_id", "is_active"] or existing_index["unique"]):
        raise RuntimeError("Incompatible_recruitment_jury_index")

    for column in application_columns:
        if column.name not in existing_columns:
            op.add_column("applications", column)
    for name, columns, unique_keys in tables:
        if not inspector.has_table(name):
            constraints = ([sa.UniqueConstraint("campaign_id", "user_id", name="uq_recruitment_jury_campaign_user")]
                           if unique_keys else [])
            op.create_table(name, *columns, *constraints)
    if not existing_index:
        op.create_index("ix_recruitment_jury_active_user", "recruitment_jury_members", ["user_id", "is_active"])


def downgrade():
    # A rollback must not silently erase jury history or candidate responses.
    bind = op.get_bind()
    for table in ("recruitment_jury_members", "application_interview_jurors", "application_personality"):
        if bind.execute(sa.text("SELECT COUNT(*) FROM " + table)).scalar():
            raise RuntimeError("Recruitment history exists; keep schema 0032 when rolling back application code.")
    if bind.execute(sa.text("""SELECT COUNT(*) FROM applications WHERE
        campus_resident IS NOT NULL OR interview_preferences IS NOT NULL OR
        interview_availability IS NOT NULL OR interview_end_at IS NOT NULL OR interview_mode IS NOT NULL""")).scalar():
        raise RuntimeError("Recruitment history exists; keep schema 0032 when rolling back application code.")
    for table in ("application_personality", "application_interview_jurors", "recruitment_jury_members"):
        op.drop_table(table)
    with op.batch_alter_table("applications") as batch:
        for name in ("campus_resident", "interview_preferences", "interview_availability", "interview_end_at", "interview_mode"):
            batch.drop_column(name)
