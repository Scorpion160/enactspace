"""Veille follow-up, human decisions, and reminder ledger."""
from datetime import datetime, timezone
import uuid
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision = "20261004_0022"
down_revision = "20261004_0021"
branch_labels = None
depends_on = None

def upgrade():
    bind = op.get_bind()
    known = set(sa.inspect(bind).get_table_names())
    if "veille_settings" not in known:
        op.create_table("veille_settings",
            sa.Column('id', sa.Integer, primary_key=True, nullable=False),
            sa.Column('version', sa.Integer, nullable=False),
            sa.Column('reminders_enabled', sa.Boolean, nullable=False),
            sa.Column('effective_at', sa.DateTime, nullable=False),
            sa.Column('quiet_start_hour', sa.Integer, nullable=False),
            sa.Column('quiet_end_hour', sa.Integer, nullable=False),
            sa.Column('escalation_days', sa.Integer, nullable=False),
            sa.Column('response_days', sa.Integer, nullable=False),
            sa.Column('appeal_days', sa.Integer, nullable=False),
            sa.Column('weekly_day', sa.Integer, nullable=False),
            sa.Column('report_hour', sa.Integer, nullable=False),
            sa.Column('auto_reports', sa.Boolean, nullable=False),
            sa.Column('updated_at', sa.DateTime, nullable=False),
        )
    if "veille_rules" not in known:
        op.create_table("veille_rules",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('content', sa.Text, nullable=False),
            sa.Column('effective_from', sa.Date, nullable=False),
            sa.Column('allowed_actions', sa.JSON, nullable=False),
            sa.Column('maximum_amount', sa.Numeric(12, 2), nullable=False),
            sa.Column('retired', sa.Boolean, nullable=False),
        )
    if "veille_plans" not in known:
        op.create_table("veille_plans",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('season_id', GUID(), sa.ForeignKey('seasons.id'), nullable=True),
            sa.Column('pole_id', GUID(), sa.ForeignKey('poles.id'), nullable=True),
            sa.Column('project_id', GUID(), sa.ForeignKey('projects.id'), nullable=True),
            sa.Column('owner_id', GUID(), sa.ForeignKey('users.id'), nullable=False),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('expected_result', sa.Text, nullable=False),
            sa.Column('availability', sa.Text, nullable=False),
            sa.Column('due_date', sa.DateTime, nullable=False),
            sa.Column('status', sa.String(30), nullable=False),
            sa.Column('course_ids', sa.JSON, nullable=False),
            sa.Column('updated_at', sa.DateTime, nullable=False),
            sa.Column('version', sa.Integer, nullable=False),
        )
    if "veille_blockers" not in known:
        op.create_table("veille_blockers",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('task_id', GUID(), sa.ForeignKey('tasks.id', ondelete='SET NULL'), nullable=True),
            sa.Column('owner_id', GUID(), sa.ForeignKey('users.id'), nullable=False),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('cause', sa.String(40), nullable=False),
            sa.Column('description', sa.Text, nullable=False),
            sa.Column('requested_help', sa.Text, nullable=False),
            sa.Column('next_action', sa.Text, nullable=False),
            sa.Column('review_at', sa.DateTime, nullable=False),
            sa.Column('status', sa.String(30), nullable=False),
            sa.Column('resolution', sa.Text, nullable=True),
            sa.Column('resolved_at', sa.DateTime, nullable=True),
            sa.Column('version', sa.Integer, nullable=False),
        )
    if "uq_veille_open_blocker_task" not in {i["name"] for i in sa.inspect(bind).get_indexes("veille_blockers")}:
        op.create_index("uq_veille_open_blocker_task","veille_blockers",["task_id"],unique=True,sqlite_where=sa.text("status = 'open'"),postgresql_where=sa.text("status = 'open'"))
    if "veille_reviews" not in known:
        op.create_table("veille_reviews",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('task_id', GUID(), sa.ForeignKey('tasks.id', ondelete='SET NULL'), nullable=True),
            sa.Column('task_title', sa.String(200), nullable=False),
            sa.Column('verdict', sa.String(30), nullable=False),
            sa.Column('feedback', sa.Text, nullable=False),
            sa.Column('quality', sa.Integer, nullable=True),
            sa.Column('submitted_at', sa.DateTime, nullable=True),
        )
    if "veille_reports" not in known:
        op.create_table("veille_reports",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('season_id', GUID(), sa.ForeignKey('seasons.id'), nullable=True),
            sa.Column('pole_id', GUID(), sa.ForeignKey('poles.id'), nullable=True),
            sa.Column('project_id', GUID(), sa.ForeignKey('projects.id'), nullable=True),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('kind', sa.String(30), nullable=False),
            sa.Column('period_start', sa.Date, nullable=False),
            sa.Column('period_end', sa.Date, nullable=False),
            sa.Column('observations', sa.Text, nullable=False),
            sa.Column('next_actions', sa.Text, nullable=False),
            sa.Column('snapshot', sa.JSON, nullable=False),
            sa.Column('automatic_key', sa.String(100), unique=True, nullable=True),
        )
    if "veille_leaves" not in known:
        op.create_table("veille_leaves",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('member_id', GUID(), sa.ForeignKey('users.id'), nullable=False),
            sa.Column('start_date', sa.Date, nullable=False),
            sa.Column('end_date', sa.Date, nullable=False),
            sa.Column('reason', sa.Text, nullable=False),
            sa.Column('status', sa.String(30), nullable=False),
            sa.Column('response', sa.Text, nullable=True),
            sa.Column('reviewed_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('version', sa.Integer, nullable=False),
        )
    if "veille_cases" not in known:
        op.create_table("veille_cases",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('member_id', GUID(), sa.ForeignKey('users.id'), nullable=False),
            sa.Column('bureau_reviewer_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('task_id', GUID(), sa.ForeignKey('tasks.id', ondelete='SET NULL'), nullable=True),
            sa.Column('attendance_id', GUID(), sa.ForeignKey('attendance_records.id'), nullable=True),
            sa.Column('rule_id', GUID(), sa.ForeignKey('veille_rules.id'), nullable=True),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('facts', sa.Text, nullable=False),
            sa.Column('observed_at', sa.Date, nullable=False),
            sa.Column('status', sa.String(30), nullable=False),
            sa.Column('version', sa.Integer, nullable=False),
            sa.Column('response_deadline', sa.DateTime, nullable=True),
            sa.Column('proposed_action', sa.String(40), nullable=True),
            sa.Column('proposal', sa.Text, nullable=True),
            sa.Column('decision_action', sa.String(40), nullable=True),
            sa.Column('decision', sa.Text, nullable=True),
            sa.Column('decided_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('decided_at', sa.DateTime, nullable=True),
            sa.Column('endorsement', sa.Text, nullable=True),
            sa.Column('endorsed_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('appeal_until', sa.DateTime, nullable=True),
            sa.Column('appeal_count', sa.Integer, nullable=False),
            sa.Column('accepted_at', sa.DateTime, nullable=True),
            sa.Column('amount', sa.Numeric(12, 2), nullable=False),
            sa.Column('fee_id', GUID(), sa.ForeignKey('fees.id'), nullable=True),
        )
    if "veille_events" not in known:
        op.create_table("veille_events",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('entity_type', sa.String(40), nullable=False),
            sa.Column('entity_id', GUID(), nullable=False),
            sa.Column('action', sa.String(60), nullable=False),
            sa.Column('message', sa.Text, nullable=False),
            sa.Column('details', sa.JSON, nullable=False),
        )
        op.create_index("ix_veille_events_entity_type", "veille_events", ["entity_type"])
        op.create_index("ix_veille_events_entity_id", "veille_events", ["entity_id"])
    if "veille_reminders" not in known:
        op.create_table("veille_reminders",
            sa.Column('id', GUID(), primary_key=True, nullable=False),
            sa.Column('created_at', sa.DateTime, nullable=False),
            sa.Column('created_by_id', GUID(), sa.ForeignKey('users.id'), nullable=True),
            sa.Column('task_id', GUID(), nullable=False),
            sa.Column('recipient_id', GUID(), sa.ForeignKey('users.id'), nullable=False),
            sa.Column('due_date', sa.DateTime, nullable=False),
            sa.Column('kind', sa.String(30), nullable=False),
            sa.UniqueConstraint("task_id", "recipient_id", "due_date", "kind", name="uq_veille_reminder"),
        )
    if "veille_plan_id" not in {c["name"] for c in sa.inspect(bind).get_columns("tasks")}:
        op.add_column("tasks", sa.Column("veille_plan_id", GUID(), nullable=True))
    if "veille_season_id" not in {c["name"] for c in sa.inspect(bind).get_columns("tasks")}:
        op.add_column("tasks",sa.Column("veille_season_id",GUID(),nullable=True))
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    metadata = sa.MetaData()
    configs = sa.Table("veille_settings", metadata, autoload_with=bind)
    if not bind.execute(sa.select(configs.c.id)).first():
        bind.execute(configs.insert().values(id=1,version=1,reminders_enabled=True,effective_at=now,quiet_start_hour=21,quiet_end_hour=7,escalation_days=2,response_days=7,appeal_days=14,weekly_day=0,report_hour=8,auto_reports=True,updated_at=now))
    roles = sa.Table("roles", metadata, autoload_with=bind)
    if not bind.execute(sa.select(roles.c.id).where(roles.c.name=="pole_veille")).first():
        bind.execute(roles.insert().values(id=uuid.uuid4() if bind.dialect.name=="postgresql" else str(uuid.uuid4()),name="pole_veille",description="Suivi transversal des engagements et des activités",created_at=now))
    tasks = sa.Table("tasks", metadata, autoload_with=bind)
    events = sa.Table("veille_events", metadata, autoload_with=bind)
    for task in bind.execute(sa.select(tasks)).mappings():
        if bind.execute(sa.select(events.c.id).where(events.c.entity_type=="task",events.c.entity_id==task["id"],events.c.action=="baseline")).first(): continue
        details={key:(value.isoformat() + ("Z" if isinstance(value,datetime) and value.tzinfo is None else "") if hasattr(value,"isoformat") else str(value) if isinstance(value,uuid.UUID) else value) for key,value in task.items() if key in {"title","status","due_date","completed_at","validated_at","validated_by","pole_id","project_id","creator_id"}}
        bind.execute(events.insert().values(id=uuid.uuid4() if bind.dialect.name=="postgresql" else str(uuid.uuid4()),created_at=now,created_by_id=None,entity_type="task",entity_id=task["id"],action="baseline",message="État de la tâche au démarrage du suivi Veille",details={"after":details}))

def downgrade():
    if "veille_season_id" in {c["name"] for c in sa.inspect(op.get_bind()).get_columns("tasks")}:
        op.drop_column("tasks","veille_season_id")
    if "veille_plan_id" in {c["name"] for c in sa.inspect(op.get_bind()).get_columns("tasks")}:
        op.drop_column("tasks", "veille_plan_id")
    known = set(sa.inspect(op.get_bind()).get_table_names())
    if "veille_reminders" in known:
        op.drop_table("veille_reminders")
    if "veille_events" in known:
        op.drop_table("veille_events")
    if "veille_cases" in known:
        op.drop_table("veille_cases")
    if "veille_leaves" in known:
        op.drop_table("veille_leaves")
    if "veille_reports" in known:
        op.drop_table("veille_reports")
    if "veille_reviews" in known:
        op.drop_table("veille_reviews")
    if "veille_blockers" in known:
        op.drop_table("veille_blockers")
    if "veille_plans" in known:
        op.drop_table("veille_plans")
    if "veille_rules" in known:
        op.drop_table("veille_rules")
    if "veille_settings" in known:
        op.drop_table("veille_settings")
