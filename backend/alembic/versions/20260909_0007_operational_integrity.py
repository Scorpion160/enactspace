"""Fence operational integrity invariants.

Revision ID: 20260909_0007
Revises: 20260906_0006
Create Date: 2026-09-09
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


revision = "20260909_0007"
down_revision = "20260906_0006"
branch_labels = None
depends_on = None


def _scalar(sql: str) -> int:
    return int(op.get_bind().execute(sa.text(sql)).scalar() or 0)


def _refuse_duplicates(label: str, sql: str) -> None:
    count = _scalar(f"SELECT COUNT(*) FROM ({sql}) AS conflicts")
    if count:
        raise RuntimeError(
            f"PR-6.5 migration refused: {label} has {count} conflicting group(s); "
            "review and repair the data explicitly before retrying"
        )


def _refuse_rows(label: str, table: str, predicate: str) -> None:
    count = _scalar(f"SELECT COUNT(*) FROM {table} WHERE {predicate}")
    if count:
        raise RuntimeError(
            f"PR-6.5 migration refused: {label} has {count} invalid row(s); "
            "review and repair the data explicitly before retrying"
        )


def _index_names(table: str) -> set[str]:
    bind = op.get_bind()
    names = {item["name"] for item in sa.inspect(bind).get_indexes(table)}
    if bind.dialect.name == "sqlite":
        names.update(
            bind.execute(
                sa.text(
                    "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = :table"
                ),
                {"table": table},
            ).scalars()
        )
    return names


def _unique_names(table: str) -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_unique_constraints(table)
        if item.get("name")
    }


def _check_names(table: str) -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_check_constraints(table)
        if item.get("name")
    }


def _create_unique(table: str, name: str, columns: list[str]) -> None:
    if name not in _unique_names(table):
        with op.batch_alter_table(table) as batch_op:
            batch_op.create_unique_constraint(name, columns)


def _create_check(table: str, name: str, condition: str) -> None:
    if name not in _check_names(table):
        with op.batch_alter_table(table) as batch_op:
            batch_op.create_check_constraint(name, condition)


def _create_index(
    table: str,
    name: str,
    columns,
    *,
    unique: bool = False,
    where: str | None = None,
) -> None:
    if name in _index_names(table):
        return
    kwargs = {}
    if where:
        kwargs["postgresql_where"] = sa.text(where)
        kwargs["sqlite_where"] = sa.text(where.replace(" = true", " = 1"))
    op.create_index(name, table, columns, unique=unique, **kwargs)


def upgrade() -> None:
    # Safe deterministic normalization only.
    op.execute("UPDATE applications SET status = 'submitted' WHERE status = 'received'")
    op.execute("UPDATE applications SET status = 'under_review' WHERE status = 'preselected'")
    op.execute(
        "UPDATE applications SET status = 'interview_scheduled' WHERE status = 'interview'"
    )
    op.execute("UPDATE projects SET status = 'termine' WHERE status IN ('completed', 'done')")
    op.execute("UPDATE tasks SET status = 'termine' WHERE status IN ('completed', 'done')")
    op.execute(
        "UPDATE attendance_sessions SET is_closed = CASE "
        "WHEN status IN ('closed', 'archived') THEN true ELSE false END"
    )

    # Refuse identity conflicts. Financial and attendance rows are never merged/deleted.
    _refuse_duplicates(
        "attendance expected-member identity",
        "SELECT session_id, user_id FROM attendance_expected_members "
        "GROUP BY session_id, user_id HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "attendance record identity",
        "SELECT session_id, user_id FROM attendance_records "
        "GROUP BY session_id, user_id HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "attendance penalty source",
        "SELECT related_attendance_id FROM fees WHERE related_attendance_id IS NOT NULL "
        "GROUP BY related_attendance_id HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "fee source identity",
        "SELECT source_type, source_id, user_id FROM fees "
        "WHERE source_type IS NOT NULL AND source_id IS NOT NULL "
        "GROUP BY source_type, source_id, user_id HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "payment allocation identity",
        "SELECT payment_id, fee_id FROM payment_allocations "
        "GROUP BY payment_id, fee_id HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "payment accounting identity",
        "SELECT payment_id FROM club_transactions WHERE payment_id IS NOT NULL "
        "GROUP BY payment_id HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "mobile-money provider event identity",
        "SELECT transaction_id, provider_event_id FROM mobile_money_transaction_events "
        "WHERE provider_event_id IS NOT NULL GROUP BY transaction_id, provider_event_id "
        "HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "active pole leadership",
        "SELECT pole_id, position FROM pole_members WHERE is_active = true "
        "AND left_at IS NULL AND position IN ('chef_pole', 'adjoint_chef_pole') "
        "GROUP BY pole_id, position HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "active project leadership",
        "SELECT project_id, position FROM project_members WHERE is_active = true "
        "AND left_at IS NULL AND position IN ('chef_projet', 'adjoint_chef_projet') "
        "GROUP BY project_id, position HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "application campaign/email identity",
        "SELECT campaign_id, lower(email) FROM applications "
        "GROUP BY campaign_id, lower(email) HAVING COUNT(*) > 1",
    )
    _refuse_duplicates(
        "user/email identity",
        "SELECT lower(email) FROM users "
        "GROUP BY lower(email) HAVING COUNT(*) > 1",
    )

    _refuse_rows("project status", "projects", "status NOT IN ('idee','etude','prototype','test','deploiement','termine','suspendu')")
    _refuse_rows("task status", "tasks", "status NOT IN ('a_faire','en_cours','bloque','termine','valide','annule')")
    _refuse_rows("attendance session status", "attendance_sessions", "status NOT IN ('draft','open','closed','archived')")
    _refuse_rows("application status", "applications", "status NOT IN ('submitted','under_review','interview_scheduled','waiting_list','accepted','rejected','cancelled')")
    _refuse_rows("invalid fee amount", "fees", "amount <= 0 OR amount_paid < 0 OR amount_paid > amount")
    _refuse_rows("invalid payment amount", "payments", "amount <= 0")
    _refuse_rows("invalid allocation amount", "payment_allocations", "amount <= 0")
    _refuse_rows("invalid accounting amount", "club_transactions", "amount <= 0")
    _refuse_rows("invalid financial account", "financial_accounts", "balance_due < 0 OR total_paid < 0")
    _refuse_rows("invalid event values", "events", "(end_time IS NOT NULL AND end_time <= start_time) OR budget < 0 OR (max_participants IS NOT NULL AND max_participants <= 0)")

    _create_unique("attendance_expected_members", "uq_attendance_expected_session_user", ["session_id", "user_id"])
    _create_unique("attendance_records", "uq_attendance_record_session_user", ["session_id", "user_id"])
    _create_unique("payment_allocations", "uq_payment_allocation_fee", ["payment_id", "fee_id"])
    _create_unique("mobile_money_transaction_events", "uq_mobile_money_event_provider_id", ["transaction_id", "provider_event_id"])

    _create_index("pole_members", "ux_pole_members_active_leadership_position", ["pole_id", "position"], unique=True, where="is_active = true AND left_at IS NULL AND position IN ('chef_pole', 'adjoint_chef_pole')")
    _create_index("project_members", "ux_project_members_active_leadership_position", ["project_id", "position"], unique=True, where="is_active = true AND left_at IS NULL AND position IN ('chef_projet', 'adjoint_chef_projet')")
    _create_index("fees", "ux_fees_related_attendance", ["related_attendance_id"], unique=True, where="related_attendance_id IS NOT NULL")
    _create_index("fees", "ux_fees_source_identity", ["source_type", "source_id", "user_id"], unique=True, where="source_type IS NOT NULL AND source_id IS NOT NULL")
    _create_index("club_transactions", "ux_club_transactions_payment", ["payment_id"], unique=True, where="payment_id IS NOT NULL")
    _create_index("applications", "ux_applications_campaign_lower_email", ["campaign_id", sa.text("lower(email)")], unique=True)
    _create_index("users", "ux_users_lower_email", [sa.text("lower(email)")], unique=True)

    _create_check("projects", "ck_projects_status", "status IN ('idee','etude','prototype','test','deploiement','termine','suspendu')")
    _create_check("tasks", "ck_tasks_status", "status IN ('a_faire','en_cours','bloque','termine','valide','annule')")
    _create_check("attendance_sessions", "ck_attendance_sessions_status", "status IN ('draft','open','closed','archived')")
    _create_check("attendance_sessions", "ck_attendance_sessions_closed_state", "((status IN ('draft','open') AND is_closed = false) OR (status IN ('closed','archived') AND is_closed = true))")
    _create_check("applications", "ck_applications_status", "status IN ('submitted','under_review','interview_scheduled','waiting_list','accepted','rejected','cancelled')")
    _create_check("financial_accounts", "ck_financial_accounts_balance_nonnegative", "balance_due >= 0")
    _create_check("financial_accounts", "ck_financial_accounts_paid_nonnegative", "total_paid >= 0")
    _create_check("fees", "ck_fees_amount_positive", "amount > 0")
    _create_check("fees", "ck_fees_paid_range", "amount_paid >= 0 AND amount_paid <= amount")
    _create_check("payments", "ck_payments_amount_positive", "amount > 0")
    _create_check("payment_allocations", "ck_payment_allocations_amount_positive", "amount > 0")
    _create_check("club_transactions", "ck_club_transactions_amount_positive", "amount > 0")
    _create_check("events", "ck_events_time_order", "end_time IS NULL OR end_time > start_time")
    _create_check("events", "ck_events_budget_nonnegative", "budget >= 0")
    _create_check("events", "ck_events_capacity_positive", "max_participants IS NULL OR max_participants > 0")


def downgrade() -> None:
    for table, name in [
        ("events", "ck_events_capacity_positive"),
        ("events", "ck_events_budget_nonnegative"),
        ("events", "ck_events_time_order"),
        ("club_transactions", "ck_club_transactions_amount_positive"),
        ("payment_allocations", "ck_payment_allocations_amount_positive"),
        ("payments", "ck_payments_amount_positive"),
        ("fees", "ck_fees_paid_range"),
        ("fees", "ck_fees_amount_positive"),
        ("financial_accounts", "ck_financial_accounts_paid_nonnegative"),
        ("financial_accounts", "ck_financial_accounts_balance_nonnegative"),
        ("applications", "ck_applications_status"),
        ("attendance_sessions", "ck_attendance_sessions_closed_state"),
        ("attendance_sessions", "ck_attendance_sessions_status"),
        ("tasks", "ck_tasks_status"),
        ("projects", "ck_projects_status"),
    ]:
        if name in _check_names(table):
            with op.batch_alter_table(table) as batch_op:
                batch_op.drop_constraint(name, type_="check")

    for table, name in [
        ("users", "ux_users_lower_email"),
        ("applications", "ux_applications_campaign_lower_email"),
        ("club_transactions", "ux_club_transactions_payment"),
        ("fees", "ux_fees_source_identity"),
        ("fees", "ux_fees_related_attendance"),
        ("project_members", "ux_project_members_active_leadership_position"),
        ("pole_members", "ux_pole_members_active_leadership_position"),
    ]:
        if name in _index_names(table):
            op.drop_index(name, table_name=table)

    for table, name in [
        ("mobile_money_transaction_events", "uq_mobile_money_event_provider_id"),
        ("payment_allocations", "uq_payment_allocation_fee"),
        ("attendance_records", "uq_attendance_record_session_user"),
        ("attendance_expected_members", "uq_attendance_expected_session_user"),
    ]:
        if name in _unique_names(table):
            with op.batch_alter_table(table) as batch_op:
                batch_op.drop_constraint(name, type_="unique")
