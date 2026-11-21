"""Preserve public replies and idempotent submissions for support and feedback."""
from alembic import op
import sqlalchemy as sa
from app.db.types import GUID

revision="20261007_0031"
down_revision="20261007_0030"
branch_labels=None
depends_on=None

def upgrade():
    bind=op.get_bind()
    for table,owner,name in (
        ("support_tickets","user_id","uq_support_ticket_client_request"),
        ("support_ticket_messages","author_id","uq_support_message_client_request"),
        ("product_feedback","user_id","uq_feedback_client_request"),
    ):
        inspector=sa.inspect(bind)
        columns={x["name"] for x in inspector.get_columns(table)}
        for column in (
            sa.Column("client_request_id",GUID(),nullable=True),
            sa.Column("submission_hash",sa.String(64),nullable=True),
        ):
            if column.name not in columns:op.add_column(table,column)
        existing={x["name"] for x in sa.inspect(bind).get_unique_constraints(table)}
        if name not in existing:
            with op.batch_alter_table(table) as batch:
                batch.create_unique_constraint(name,[owner,"client_request_id"])
    if "public_reply" not in {x["name"] for x in sa.inspect(bind).get_columns("product_feedback")}:
        op.add_column("product_feedback",sa.Column("public_reply",sa.Text(),nullable=True))

def downgrade():
    # Retain submissions, public answers and retry keys when rolling back code.
    pass
