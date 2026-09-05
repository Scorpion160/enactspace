"""Add explicit impact claim truth and provenance semantics.

Revision ID: 20260903_0003
Revises: 20260902_0002
Create Date: 2026-09-03
"""

from __future__ import annotations

import uuid
from datetime import datetime

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260903_0003"
down_revision = "20260902_0002"
branch_labels = None
depends_on = None


PROJECT_NUMERIC_COLUMNS = (
    "direct_beneficiaries",
    "indirect_beneficiaries",
    "reach",
    "jobs_created",
    "lives_impacted",
    "revenue_generated",
    "profit_or_surplus",
    "cost_savings",
    "trees_planted",
    "waste_reduced",
    "water_saved",
    "co2_reduced",
)

LEGACY_CLAIMS = {
    "direct_beneficiaries": ("direct_beneficiaries", "Beneficiaires directs", "personnes"),
    "indirect_beneficiaries": ("indirect_beneficiaries", "Beneficiaires indirects", "personnes"),
    "reach": ("reach", "Portee", "personnes"),
    "jobs_created": ("jobs_created", "Emplois crees", "emplois"),
    "lives_impacted": ("lives_impacted", "Vies impactees", "personnes"),
    "revenue_generated": ("revenue_generated", "Revenus generes", "FCFA"),
    "profit_or_surplus": ("profit_or_surplus", "Profit ou surplus", "FCFA"),
    "cost_savings": ("cost_savings", "Economies realisees", "FCFA"),
    "trees_planted": ("trees_planted", "Arbres plantes", "arbres"),
    "waste_reduced": ("waste_reduced", "Dechets reduits", "kg"),
    "water_saved": ("water_saved", "Eau economisee", "litres"),
    "co2_reduced": ("co2_reduced", "CO2 reduit", "kg"),
}

LEGACY_CLAIM_NAMESPACE = uuid.UUID("95f46a98-29b9-5fca-a664-58a9f3da8a19")
ACTIVE_REPLACEMENT_PREDICATE = (
    "supersedes_metric_id IS NOT NULL AND validation_status IN "
    "('DRAFT', 'EVIDENCE_PENDING', 'EVIDENCE_ATTACHED', "
    "'UNDER_REVIEW', 'VERIFIED')"
)


def _legacy_claim_id(impact_project_id, semantic_key: str) -> str:
    return str(
        uuid.uuid5(
            LEGACY_CLAIM_NAMESPACE,
            f"20260903_0003:{impact_project_id}:{semantic_key}",
        )
    )


def _column_names(table_name: str) -> set[str]:
    return {column["name"] for column in sa.inspect(op.get_bind()).get_columns(table_name)}


def _constraint_names(table_name: str) -> set[str]:
    inspector = sa.inspect(op.get_bind())
    names = {
        item["name"]
        for item in inspector.get_check_constraints(table_name)
        + inspector.get_unique_constraints(table_name)
        + inspector.get_foreign_keys(table_name)
        if item.get("name")
    }
    return names


def _index_names(table_name: str) -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_indexes(table_name)
        if item.get("name")
    }


def _supersedes_foreign_key_names() -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_foreign_keys("impact_metrics")
        if item.get("name")
        and item.get("constrained_columns") == ["supersedes_metric_id"]
    }


def _require_all_or_none(table_name: str, expected: set[str]) -> bool:
    present = expected.intersection(_column_names(table_name))
    if present == expected:
        return True
    if present:
        raise RuntimeError(
            f"Partial PR-2C schema detected in {table_name}: "
            + ", ".join(sorted(present))
        )
    return False


def _add_columns() -> None:
    op.add_column(
        "impact_projects",
        sa.Column(
            "validation_status",
            sa.String(32),
            nullable=False,
            server_default=sa.text("'DRAFT'"),
        ),
    )
    op.add_column("impact_metrics", sa.Column("semantic_key", sa.String(100)))
    op.add_column(
        "impact_metrics",
        sa.Column(
            "claim_type",
            sa.String(32),
            nullable=False,
            server_default=sa.text("'HISTORICAL_CLAIM'"),
        ),
    )
    op.add_column(
        "impact_metrics",
        sa.Column(
            "validation_status",
            sa.String(32),
            nullable=False,
            server_default=sa.text("'DRAFT'"),
        ),
    )
    op.add_column("impact_metrics", sa.Column("period_start", sa.Date()))
    op.add_column("impact_metrics", sa.Column("period_end", sa.Date()))
    op.add_column("impact_metrics", sa.Column("population_scope", sa.Text()))
    op.add_column("impact_metrics", sa.Column("source_reference", sa.Text()))
    op.add_column("impact_metrics", sa.Column("notes_limitations", sa.Text()))
    op.add_column("impact_metrics", sa.Column("supersedes_metric_id", GUID()))
    op.add_column(
        "impact_evidence",
        sa.Column(
            "validation_status",
            sa.String(32),
            nullable=False,
            server_default=sa.text("'EVIDENCE_ATTACHED'"),
        ),
    )


def _migrate_values() -> None:
    connection = op.get_bind()
    connection.execute(
        sa.text(
            """
            UPDATE impact_projects
            SET validation_status = CASE status
                WHEN 'submitted' THEN 'EVIDENCE_PENDING'
                WHEN 'under_review' THEN 'UNDER_REVIEW'
                WHEN 'validated' THEN 'VERIFIED'
                WHEN 'rejected' THEN 'REJECTED'
                WHEN 'archived' THEN 'SUPERSEDED'
                ELSE 'DRAFT'
            END
            """
        )
    )
    connection.execute(
        sa.text(
            """
            UPDATE impact_metrics
            SET validation_status = CASE status
                WHEN 'submitted' THEN 'EVIDENCE_PENDING'
                WHEN 'under_review' THEN 'UNDER_REVIEW'
                WHEN 'validated' THEN 'VERIFIED'
                WHEN 'rejected' THEN 'REJECTED'
                WHEN 'archived' THEN 'SUPERSEDED'
                ELSE 'DRAFT'
            END,
            semantic_key = 'legacy:' || CAST(id AS VARCHAR)
            """
        )
    )
    connection.execute(
        sa.text(
            """
            UPDATE impact_evidence
            SET validation_status = CASE status
                WHEN 'draft' THEN 'DRAFT'
                WHEN 'under_review' THEN 'UNDER_REVIEW'
                WHEN 'validated' THEN 'VERIFIED'
                WHEN 'rejected' THEN 'REJECTED'
                WHEN 'archived' THEN 'SUPERSEDED'
                ELSE 'EVIDENCE_ATTACHED'
            END
            """
        )
    )

    legacy_rows = connection.execute(
        sa.text(
            "SELECT id, created_by_id, created_at, "
            + ", ".join(PROJECT_NUMERIC_COLUMNS)
            + " FROM impact_projects"
        )
    ).mappings()
    now = datetime.utcnow()
    for row in legacy_rows:
        for column, (semantic_key, title, unit) in LEGACY_CLAIMS.items():
            value = row[column]
            if value is None or value == 0:
                continue
            connection.execute(
                sa.text(
                    """
                    INSERT INTO impact_metrics (
                        id, impact_project_id, semantic_key, title, category,
                        unit, value, claim_type, validation_status, source,
                        notes_limitations, status, created_by_id, created_at,
                        updated_at
                    ) VALUES (
                        :id, :impact_project_id, :semantic_key, :title, 'legacy',
                        :unit, :value, 'HISTORICAL_CLAIM', 'DRAFT',
                        'legacy_impact_project', :notes, 'draft',
                        :created_by_id, :created_at, :updated_at
                    )
                    """
                ),
                {
                    "id": _legacy_claim_id(row["id"], semantic_key),
                    "impact_project_id": row["id"],
                    "semantic_key": semantic_key,
                    "title": title,
                    "unit": unit,
                    "value": value,
                    "notes": (
                        "Valeur preservee depuis le champ historique du projet; "
                        "provenance et mesure a verifier."
                    ),
                    "created_by_id": row["created_by_id"],
                    "created_at": row["created_at"] or now,
                    "updated_at": now,
                },
            )

    for column in PROJECT_NUMERIC_COLUMNS:
        connection.execute(
            sa.text(f"UPDATE impact_projects SET {column} = NULL WHERE {column} = 0")
        )
    connection.execute(sa.text("UPDATE impact_metrics SET value = NULL WHERE value = 0"))


def _allow_unknown_numeric_values() -> None:
    with op.batch_alter_table("impact_projects") as batch:
        for column in PROJECT_NUMERIC_COLUMNS:
            batch.alter_column(column, existing_type=sa.Numeric(), nullable=True)
    with op.batch_alter_table("impact_metrics") as batch:
        batch.alter_column("value", existing_type=sa.Numeric(14, 2), nullable=True)


def _add_constraints() -> None:
    with op.batch_alter_table("impact_projects") as batch:
        batch.create_check_constraint(
            "ck_impact_project_validation_status",
            "validation_status IN ('DRAFT', 'EVIDENCE_PENDING', "
            "'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED', "
            "'SUPERSEDED')",
        )
        batch.alter_column("validation_status", server_default=None)

    with op.batch_alter_table("impact_metrics") as batch:
        batch.alter_column("semantic_key", existing_type=sa.String(100), nullable=False)
        batch.create_check_constraint(
            "ck_impact_metric_claim_type",
            "claim_type IN ('MEASURED', 'ESTIMATE', 'PROJECTION', "
            "'HISTORICAL_CLAIM')",
        )
        batch.create_check_constraint(
            "ck_impact_metric_validation_status",
            "validation_status IN ('DRAFT', 'EVIDENCE_PENDING', "
            "'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED', "
            "'SUPERSEDED')",
        )
        batch.create_check_constraint(
            "ck_impact_metric_period",
            "period_end IS NULL OR period_start IS NULL OR period_end >= period_start",
        )
        batch.create_check_constraint(
            "ck_impact_metric_semantic_key",
            "length(trim(semantic_key)) > 0",
        )
        batch.create_foreign_key(
            "fk_impact_metric_supersedes",
            "impact_metrics",
            ["supersedes_metric_id"],
            ["id"],
            ondelete="RESTRICT",
        )
        batch.alter_column("claim_type", server_default=None)
        batch.alter_column("validation_status", server_default=None)

    op.create_index(
        "uq_impact_metric_active_supersedes",
        "impact_metrics",
        ["supersedes_metric_id"],
        unique=True,
        postgresql_where=sa.text(ACTIVE_REPLACEMENT_PREDICATE),
        sqlite_where=sa.text(ACTIVE_REPLACEMENT_PREDICATE),
    )

    with op.batch_alter_table("impact_evidence") as batch:
        batch.create_check_constraint(
            "ck_impact_evidence_validation_status",
            "validation_status IN ('DRAFT', 'EVIDENCE_PENDING', "
            "'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED', "
            "'SUPERSEDED')",
        )
        batch.alter_column("validation_status", server_default=None)


def upgrade() -> None:
    project_ready = _require_all_or_none("impact_projects", {"validation_status"})
    metric_columns = {
        "semantic_key",
        "claim_type",
        "validation_status",
        "period_start",
        "period_end",
        "population_scope",
        "source_reference",
        "notes_limitations",
        "supersedes_metric_id",
    }
    metric_ready = _require_all_or_none("impact_metrics", metric_columns)
    evidence_ready = _require_all_or_none("impact_evidence", {"validation_status"})
    ready_states = {project_ready, metric_ready, evidence_ready}
    if len(ready_states) != 1:
        raise RuntimeError("Partial PR-2C schema detected across impact tables")
    if project_ready:
        return

    _add_columns()
    _allow_unknown_numeric_values()
    _migrate_values()
    _add_constraints()


def downgrade() -> None:
    if "validation_status" not in _column_names("impact_projects"):
        return

    connection = op.get_bind()
    impact_project_ids = list(
        connection.execute(sa.text("SELECT id FROM impact_projects")).scalars()
    )
    for impact_project_id in impact_project_ids:
        for semantic_key, _title, _unit in LEGACY_CLAIMS.values():
            connection.execute(
                sa.text("DELETE FROM impact_metrics WHERE id = :id"),
                {"id": _legacy_claim_id(impact_project_id, semantic_key)},
            )
    for column in PROJECT_NUMERIC_COLUMNS:
        connection.execute(
            sa.text(f"UPDATE impact_projects SET {column} = 0 WHERE {column} IS NULL")
        )
    connection.execute(sa.text("UPDATE impact_metrics SET value = 0 WHERE value IS NULL"))

    metric_constraints = _constraint_names("impact_metrics")
    metric_indexes = _index_names("impact_metrics")
    supersedes_foreign_keys = _supersedes_foreign_key_names()
    if "uq_impact_metric_active_supersedes" in metric_indexes:
        op.drop_index(
            "uq_impact_metric_active_supersedes",
            table_name="impact_metrics",
        )
    with op.batch_alter_table("impact_metrics") as batch:
        for name in (
            "ck_impact_metric_period",
            "ck_impact_metric_validation_status",
            "ck_impact_metric_claim_type",
            "ck_impact_metric_semantic_key",
        ):
            if name in metric_constraints:
                batch.drop_constraint(name, type_="check")
        if "uq_impact_metric_supersedes" in metric_constraints:
            batch.drop_constraint("uq_impact_metric_supersedes", type_="unique")
        for name in supersedes_foreign_keys:
            batch.drop_constraint(name, type_="foreignkey")
        batch.alter_column("value", existing_type=sa.Numeric(14, 2), nullable=False)
        for column in (
            "supersedes_metric_id",
            "notes_limitations",
            "source_reference",
            "population_scope",
            "period_end",
            "period_start",
            "validation_status",
            "claim_type",
            "semantic_key",
        ):
            batch.drop_column(column)

    evidence_constraints = _constraint_names("impact_evidence")
    with op.batch_alter_table("impact_evidence") as batch:
        if "ck_impact_evidence_validation_status" in evidence_constraints:
            batch.drop_constraint(
                "ck_impact_evidence_validation_status", type_="check"
            )
        batch.drop_column("validation_status")

    project_constraints = _constraint_names("impact_projects")
    with op.batch_alter_table("impact_projects") as batch:
        if "ck_impact_project_validation_status" in project_constraints:
            batch.drop_constraint(
                "ck_impact_project_validation_status", type_="check"
            )
        for column in PROJECT_NUMERIC_COLUMNS:
            batch.alter_column(column, existing_type=sa.Numeric(), nullable=False)
        batch.drop_column("validation_status")
