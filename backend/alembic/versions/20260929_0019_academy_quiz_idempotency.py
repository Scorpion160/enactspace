"""Make Academy quiz submissions idempotent.

Revision ID: 20260929_0019
Revises: 20260928_0018
"""

from alembic import op
import sqlalchemy as sa


revision = "20260929_0019"
down_revision = "20260928_0018"
branch_labels = None
depends_on = None

TABLE_NAME = "academy_quiz_attempts"
CONSTRAINT_NAME = (
    "uq_academy_quiz_attempts_user_client_submission"
)


def _column_names() -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {
        column["name"]
        for column in inspector.get_columns(TABLE_NAME)
    }


def _constraint_names() -> set[str]:
    inspector = sa.inspect(op.get_bind())
    return {
        constraint["name"]
        for constraint in inspector.get_unique_constraints(TABLE_NAME)
        if constraint.get("name")
    }


def _is_sqlite() -> bool:
    return op.get_bind().dialect.name == "sqlite"


def upgrade() -> None:
    columns = _column_names()

    if "client_submission_id" not in columns:
        op.add_column(
            TABLE_NAME,
            sa.Column(
                "client_submission_id",
                sa.String(length=100),
                nullable=True,
            ),
        )

    if "result_payload" not in columns:
        op.add_column(
            TABLE_NAME,
            sa.Column(
                "result_payload",
                sa.JSON(),
                nullable=True,
            ),
        )

    if CONSTRAINT_NAME not in _constraint_names():
        if _is_sqlite():
            with op.batch_alter_table(
                TABLE_NAME,
                recreate="always",
            ) as batch_op:
                batch_op.create_unique_constraint(
                    CONSTRAINT_NAME,
                    ["user_id", "client_submission_id"],
                )
        else:
            op.create_unique_constraint(
                CONSTRAINT_NAME,
                TABLE_NAME,
                ["user_id", "client_submission_id"],
            )


def downgrade() -> None:
    columns = _column_names()
    constraint_exists = CONSTRAINT_NAME in _constraint_names()

    if _is_sqlite():
        if (
            constraint_exists
            or "result_payload" in columns
            or "client_submission_id" in columns
        ):
            with op.batch_alter_table(
                TABLE_NAME,
                recreate="always",
            ) as batch_op:
                if constraint_exists:
                    batch_op.drop_constraint(
                        CONSTRAINT_NAME,
                        type_="unique",
                    )

                if "result_payload" in columns:
                    batch_op.drop_column("result_payload")

                if "client_submission_id" in columns:
                    batch_op.drop_column("client_submission_id")

        return

    if constraint_exists:
        op.drop_constraint(
            CONSTRAINT_NAME,
            TABLE_NAME,
            type_="unique",
        )

    if "result_payload" in columns:
        op.drop_column(TABLE_NAME, "result_payload")

    if "client_submission_id" in columns:
        op.drop_column(TABLE_NAME, "client_submission_id")