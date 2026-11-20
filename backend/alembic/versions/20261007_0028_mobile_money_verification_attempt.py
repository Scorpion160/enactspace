"""Track verification attempts separately from successful provider lookups."""
from alembic import op
import sqlalchemy as sa
revision = "20261007_0028"
down_revision = "20261007_0027"
branch_labels = None
depends_on = None

def upgrade():
    inspector = sa.inspect(op.get_bind())
    columns = {item["name"]: item for item in inspector.get_columns("mobile_money_transactions")}
    column = columns.get("last_verification_attempt_at")
    if column is None:
        op.add_column("mobile_money_transactions",
            sa.Column("last_verification_attempt_at", sa.DateTime(), nullable=True))
    elif not column["nullable"] or not isinstance(column["type"], sa.DateTime):
        raise RuntimeError("Incompatible verification-attempt column")
    indexes = {item["name"] for item in sa.inspect(op.get_bind()).get_indexes("mobile_money_transactions")}
    if "ix_mobile_money_transactions_last_verification_attempt_at" not in indexes:
        op.create_index("ix_mobile_money_transactions_last_verification_attempt_at",
            "mobile_money_transactions", ["last_verification_attempt_at"])


def downgrade():
    op.drop_index("ix_mobile_money_transactions_last_verification_attempt_at",
        table_name="mobile_money_transactions")
    op.drop_column("mobile_money_transactions", "last_verification_attempt_at")
