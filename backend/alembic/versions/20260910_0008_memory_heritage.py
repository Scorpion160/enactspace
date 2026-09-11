"""Add operational provenance to institutional memory events.

Revision ID: 20260910_0008
Revises: 20260909_0007
Create Date: 2026-09-10
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260910_0008"
down_revision = "20260909_0007"
branch_labels = None
depends_on = None


EVENT_COLUMN_ORDER = (
    "id", "title", "event_type", "event_date", "year", "end_date",
    "description", "territory_id", "canonical_project_id", "generation_id",
    "visibility", "status", "source_id", "validation_status", "created_by_id",
    "validated_by_id", "validated_at", "created_at", "updated_at", "origin",
    "capture_key", "source_entity_type", "source_entity_id",
    "source_entity_version", "captured_at", "operational_project_id", "pole_id",
    "operational_event_id",
)
PROVENANCE_COLUMNS = {
    "origin",
    "capture_key",
    "source_entity_type",
    "source_entity_id",
    "source_entity_version",
    "captured_at",
    "operational_project_id",
    "pole_id",
    "operational_event_id",
}


def _index_names() -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_indexes("institutional_events")
    }


def _create_index(name: str, columns: list[str]) -> None:
    if name not in _index_names():
        op.create_index(name, "institutional_events", columns)


def _drop_index(name: str) -> None:
    if name in _index_names():
        op.drop_index(name, table_name="institutional_events")


def _ensure_indexes() -> None:
    _create_index("ix_memory_event_capture_key", ["capture_key"])
    _create_index("ix_memory_event_origin", ["origin"])
    _create_index(
        "ix_memory_event_source_entity",
        ["source_entity_type", "source_entity_id"],
    )
    _create_index(
        "ix_memory_event_operational_project",
        ["operational_project_id", "year"],
    )
    _create_index("ix_memory_event_pole", ["pole_id", "year"])
    _create_index(
        "ix_memory_event_operational_event",
        ["operational_event_id", "year"],
    )


def upgrade() -> None:
    columns = {
        column["name"]
        for column in sa.inspect(op.get_bind()).get_columns("institutional_events")
    }
    present = PROVENANCE_COLUMNS.intersection(columns)
    if present == PROVENANCE_COLUMNS:
        _ensure_indexes()
        return
    if present:
        raise RuntimeError("Partial PR-6.6 institutional-event provenance schema detected")
    with op.batch_alter_table(
        "institutional_events", partial_reordering=[EVENT_COLUMN_ORDER]
    ) as batch_op:
        batch_op.add_column(
            sa.Column("origin", sa.String(20), nullable=False, server_default="manual")
        )
        batch_op.add_column(sa.Column("capture_key", sa.String(255), nullable=True))
        batch_op.add_column(sa.Column("source_entity_type", sa.String(80), nullable=True))
        batch_op.add_column(sa.Column("source_entity_id", GUID(), nullable=True))
        batch_op.add_column(sa.Column("source_entity_version", sa.String(120), nullable=True))
        batch_op.add_column(sa.Column("captured_at", sa.DateTime(), nullable=True))
        batch_op.add_column(sa.Column("operational_project_id", GUID(), nullable=True))
        batch_op.add_column(sa.Column("pole_id", GUID(), nullable=True))
        batch_op.add_column(sa.Column("operational_event_id", GUID(), nullable=True))
        batch_op.create_foreign_key(
            "fk_memory_event_operational_project",
            "projects",
            ["operational_project_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch_op.create_foreign_key(
            "fk_memory_event_pole", "poles", ["pole_id"], ["id"], ondelete="SET NULL"
        )
        batch_op.create_foreign_key(
            "fk_memory_event_operational_event",
            "events",
            ["operational_event_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch_op.create_check_constraint(
            "ck_memory_event_origin", "origin IN ('manual', 'operational')"
        )
        batch_op.create_check_constraint(
            "ck_memory_event_operational_provenance",
            "(origin = 'manual') OR (capture_key IS NOT NULL AND "
            "source_entity_type IS NOT NULL AND source_entity_id IS NOT NULL "
            "AND captured_at IS NOT NULL)",
        )
        batch_op.create_unique_constraint("uq_memory_event_capture_key", ["capture_key"])
    _ensure_indexes()


def downgrade() -> None:
    _drop_index("ix_memory_event_capture_key")
    _drop_index("ix_memory_event_operational_event")
    _drop_index("ix_memory_event_pole")
    _drop_index("ix_memory_event_operational_project")
    _drop_index("ix_memory_event_source_entity")
    _drop_index("ix_memory_event_origin")
    inspector = sa.inspect(op.get_bind())
    unique_names = {
        constraint["name"]
        for constraint in inspector.get_unique_constraints("institutional_events")
        if constraint.get("name")
    }
    check_names = {
        constraint["name"]
        for constraint in inspector.get_check_constraints("institutional_events")
        if constraint.get("name")
    }
    foreign_key_names = {
        constraint["name"]
        for constraint in inspector.get_foreign_keys("institutional_events")
        if constraint.get("name")
    }
    with op.batch_alter_table("institutional_events") as batch_op:
        if "uq_memory_event_capture_key" in unique_names:
            batch_op.drop_constraint("uq_memory_event_capture_key", type_="unique")
        if "ck_memory_event_operational_provenance" in check_names:
            batch_op.drop_constraint(
                "ck_memory_event_operational_provenance",
                type_="check",
            )
        if "ck_memory_event_origin" in check_names:
            batch_op.drop_constraint("ck_memory_event_origin", type_="check")
        if "fk_memory_event_operational_event" in foreign_key_names:
            batch_op.drop_constraint(
                "fk_memory_event_operational_event",
                type_="foreignkey",
            )
        if "fk_memory_event_pole" in foreign_key_names:
            batch_op.drop_constraint("fk_memory_event_pole", type_="foreignkey")
        if "fk_memory_event_operational_project" in foreign_key_names:
            batch_op.drop_constraint(
                "fk_memory_event_operational_project",
                type_="foreignkey",
            )
        batch_op.drop_column("operational_event_id")
        batch_op.drop_column("pole_id")
        batch_op.drop_column("operational_project_id")
        batch_op.drop_column("captured_at")
        batch_op.drop_column("source_entity_version")
        batch_op.drop_column("source_entity_id")
        batch_op.drop_column("source_entity_type")
        batch_op.drop_column("capture_key")
        batch_op.drop_column("origin")
