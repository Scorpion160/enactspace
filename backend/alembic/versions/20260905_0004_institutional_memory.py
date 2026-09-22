"""Add normalized institutional memory foundation.

Revision ID: 20260905_0004
Revises: 20260903_0003
Create Date: 2026-09-05
"""

from alembic import op
import sqlalchemy as sa

from app.db.types import GUID


revision = "20260905_0004"
down_revision = "20260903_0003"
branch_labels = None
depends_on = None


MEMORY_TABLES = {
    "institutional_sources",
    "institutional_territories",
    "institutional_generations",
    "institutional_canonical_projects",
    "institutional_leadership_terms",
    "institutional_project_aliases",
    "institutional_project_years",
    "institutional_project_relationships",
    "institutional_events",
    "institutional_frameworks",
    "institutional_competition_participations",
}
COMPETITION_COLUMNS = {
    "territory_id",
    "source_id",
    "validation_status",
    "created_by_id",
    "validated_by_id",
    "validated_at",
}
AWARD_COLUMNS = {
    "competition_record_id",
    "canonical_project_id",
    "source_id",
    "validation_status",
    "created_by_id",
    "validated_by_id",
    "validated_at",
}
VALIDATION_SQL = (
    "validation_status IN ('HISTORICAL_REPORTED', 'EVIDENCE_PENDING', "
    "'EVIDENCE_ATTACHED', 'UNDER_REVIEW', 'VERIFIED', 'REJECTED', "
    "'SUPERSEDED')"
)


def _fact_columns() -> list[sa.Column]:
    return [
        sa.Column("source_id", GUID(), nullable=True),
        sa.Column(
            "validation_status",
            sa.String(32),
            nullable=False,
            server_default="HISTORICAL_REPORTED",
        ),
        sa.Column("created_by_id", GUID(), nullable=True),
        sa.Column("validated_by_id", GUID(), nullable=True),
        sa.Column("validated_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["source_id"], ["institutional_sources.id"], ondelete="RESTRICT"
        ),
        sa.ForeignKeyConstraint(
            ["created_by_id"], ["users.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(
            ["validated_by_id"], ["users.id"], ondelete="SET NULL"
        ),
    ]


def _schema_state() -> tuple[set[str], set[str], set[str]]:
    inspector = sa.inspect(op.get_bind())
    tables = set(inspector.get_table_names())
    competition = {
        column["name"]
        for column in inspector.get_columns("archive_competition_records")
    }
    awards = {column["name"] for column in inspector.get_columns("archive_awards")}
    return tables, competition, awards


def _create_tables() -> None:
    op.create_table(
        "institutional_sources",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("source_type", sa.String(50), nullable=False),
        sa.Column("title", sa.String(220), nullable=False),
        sa.Column("document_id", GUID(), nullable=True),
        sa.Column("file_id", GUID(), nullable=True),
        sa.Column("external_url", sa.Text(), nullable=True),
        sa.Column("source_label", sa.String(220), nullable=True),
        sa.Column("publication_date", sa.Date(), nullable=True),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("visibility", sa.String(30), nullable=False, server_default="internal"),
        sa.Column(
            "validation_status",
            sa.String(32),
            nullable=False,
            server_default="HISTORICAL_REPORTED",
        ),
        sa.Column("created_by_id", GUID(), nullable=True),
        sa.Column("validated_by_id", GUID(), nullable=True),
        sa.Column("validated_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_source_validation"),
        sa.CheckConstraint(
            "year IS NULL OR (year BETWEEN 1000 AND 9999)",
            name="ck_memory_source_year",
        ),
        sa.CheckConstraint(
            "visibility IN ('private', 'internal')",
            name="ck_memory_source_visibility",
        ),
        sa.ForeignKeyConstraint(["document_id"], ["documents.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["file_id"], ["stored_files.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["created_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["validated_by_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_memory_source_year_type", "institutional_sources", ["year", "source_type"]
    )

    op.create_table(
        "institutional_territories",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("name", sa.String(180), nullable=False),
        sa.Column("place_type", sa.String(60), nullable=False),
        sa.Column("country", sa.String(120), nullable=False),
        sa.Column("region", sa.String(160), nullable=True),
        sa.Column("department_or_locality", sa.String(180), nullable=True),
        sa.Column("latitude", sa.Numeric(9, 6), nullable=True),
        sa.Column("longitude", sa.Numeric(9, 6), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_territory_validation"),
        sa.CheckConstraint(
            "latitude IS NULL OR (latitude BETWEEN -90 AND 90)",
            name="ck_memory_territory_latitude",
        ),
        sa.CheckConstraint(
            "longitude IS NULL OR (longitude BETWEEN -180 AND 180)",
            name="ck_memory_territory_longitude",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "name", "place_type", "country", "region", "department_or_locality",
            name="uq_memory_territory_identity",
        ),
    )
    op.create_index(
        "ix_memory_territory_country_region",
        "institutional_territories",
        ["country", "region"],
    )

    op.create_table(
        "institutional_generations",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("name", sa.String(180), nullable=False),
        sa.Column("start_year", sa.Integer(), nullable=False),
        sa.Column("end_year", sa.Integer(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(40), nullable=False, server_default="historical"),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_generation_validation"),
        sa.CheckConstraint(
            "start_year BETWEEN 1000 AND 9999",
            name="ck_memory_generation_start_year",
        ),
        sa.CheckConstraint(
            "end_year IS NULL OR (end_year BETWEEN 1000 AND 9999 AND end_year >= start_year)",
            name="ck_memory_generation_end_year",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name", "start_year", name="uq_memory_generation_name_year"),
    )
    op.create_index(
        "ix_memory_generation_years",
        "institutional_generations",
        ["start_year", "end_year"],
    )

    op.create_table(
        "institutional_canonical_projects",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("canonical_name", sa.String(180), nullable=False),
        sa.Column("slug", sa.String(180), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("first_year", sa.Integer(), nullable=True),
        sa.Column("last_year", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(50), nullable=False, server_default="historical"),
        sa.Column("current_project_id", GUID(), nullable=True),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_project_validation"),
        sa.CheckConstraint(
            "first_year IS NULL OR (first_year BETWEEN 1000 AND 9999)",
            name="ck_memory_project_first_year",
        ),
        sa.CheckConstraint(
            "last_year IS NULL OR (last_year BETWEEN 1000 AND 9999 AND "
            "(first_year IS NULL OR last_year >= first_year))",
            name="ck_memory_project_last_year",
        ),
        sa.ForeignKeyConstraint(
            ["current_project_id"], ["projects.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("slug"),
    )
    op.create_index(
        "ix_memory_project_years",
        "institutional_canonical_projects",
        ["first_year", "last_year"],
    )

    op.create_table(
        "institutional_leadership_terms",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("user_id", GUID(), nullable=True),
        sa.Column("display_name", sa.String(180), nullable=True),
        sa.Column("role_label", sa.String(180), nullable=False),
        sa.Column("pole_id", GUID(), nullable=True),
        sa.Column("generation_id", GUID(), nullable=True),
        sa.Column("start_year", sa.Integer(), nullable=False),
        sa.Column("end_year", sa.Integer(), nullable=True),
        sa.Column("is_current", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("notes", sa.Text(), nullable=True),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_term_validation"),
        sa.CheckConstraint(
            "user_id IS NOT NULL OR length(trim(display_name)) > 0",
            name="ck_memory_term_person",
        ),
        sa.CheckConstraint(
            "start_year BETWEEN 1000 AND 9999", name="ck_memory_term_start_year"
        ),
        sa.CheckConstraint(
            "end_year IS NULL OR (end_year BETWEEN 1000 AND 9999 AND end_year >= start_year)",
            name="ck_memory_term_end_year",
        ),
        sa.CheckConstraint(
            "is_current = false OR end_year IS NULL", name="ck_memory_term_current_end"
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["pole_id"], ["poles.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(
            ["generation_id"], ["institutional_generations.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_memory_term_years", "institutional_leadership_terms", ["start_year", "end_year"]
    )
    op.create_index(
        "ix_memory_term_user", "institutional_leadership_terms", ["user_id"]
    )

    op.create_table(
        "institutional_project_aliases",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("canonical_project_id", GUID(), nullable=False),
        sa.Column("alias", sa.String(180), nullable=False),
        sa.Column("start_year", sa.Integer(), nullable=True),
        sa.Column("end_year", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_alias_validation"),
        sa.CheckConstraint(
            "start_year IS NULL OR (start_year BETWEEN 1000 AND 9999)",
            name="ck_memory_alias_start_year",
        ),
        sa.CheckConstraint(
            "end_year IS NULL OR (end_year BETWEEN 1000 AND 9999 AND "
            "(start_year IS NULL OR end_year >= start_year))",
            name="ck_memory_alias_end_year",
        ),
        sa.ForeignKeyConstraint(
            ["canonical_project_id"],
            ["institutional_canonical_projects.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "uq_memory_project_alias_ci",
        "institutional_project_aliases",
        [sa.text("lower(alias)")],
        unique=True,
    )
    op.create_index(
        "ix_memory_alias_project",
        "institutional_project_aliases",
        ["canonical_project_id"],
    )

    op.create_table(
        "institutional_project_years",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("canonical_project_id", GUID(), nullable=False),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("display_name", sa.String(180), nullable=True),
        sa.Column("status", sa.String(50), nullable=False, server_default="reported"),
        sa.Column("problem_summary", sa.Text(), nullable=True),
        sa.Column("solution_summary", sa.Text(), nullable=True),
        sa.Column("territory_id", GUID(), nullable=True),
        sa.Column("operational_project_id", GUID(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_project_year_validation"),
        sa.CheckConstraint(
            "year BETWEEN 1000 AND 9999", name="ck_memory_project_year_year"
        ),
        sa.ForeignKeyConstraint(
            ["canonical_project_id"],
            ["institutional_canonical_projects.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["territory_id"], ["institutional_territories.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(
            ["operational_project_id"], ["projects.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "canonical_project_id", "year", name="uq_memory_project_year"
        ),
    )
    op.create_index(
        "ix_memory_project_year_year", "institutional_project_years", ["year"]
    )
    op.create_index(
        "ix_memory_project_year_territory",
        "institutional_project_years",
        ["territory_id", "year"],
    )

    op.create_table(
        "institutional_project_relationships",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("source_project_id", GUID(), nullable=False),
        sa.Column("target_project_id", GUID(), nullable=False),
        sa.Column("relationship_type", sa.String(50), nullable=False),
        sa.Column("year", sa.Integer(), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_relationship_validation"),
        sa.CheckConstraint(
            "source_project_id <> target_project_id",
            name="ck_memory_relationship_not_self",
        ),
        sa.CheckConstraint(
            "relationship_type IN ('renamed_from', 'continued_as', 'merged_into', "
            "'split_from', 'inspired_by', 'technology_transferred_to', 'other')",
            name="ck_memory_relationship_type",
        ),
        sa.CheckConstraint(
            "year IS NULL OR (year BETWEEN 1000 AND 9999)",
            name="ck_memory_relationship_year",
        ),
        sa.ForeignKeyConstraint(
            ["source_project_id"],
            ["institutional_canonical_projects.id"],
            ondelete="RESTRICT",
        ),
        sa.ForeignKeyConstraint(
            ["target_project_id"],
            ["institutional_canonical_projects.id"],
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_memory_relationship_source",
        "institutional_project_relationships",
        ["source_project_id", "year"],
    )
    op.create_index(
        "ix_memory_relationship_target",
        "institutional_project_relationships",
        ["target_project_id", "year"],
    )

    op.create_table(
        "institutional_events",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("title", sa.String(220), nullable=False),
        sa.Column("event_type", sa.String(60), nullable=False),
        sa.Column("event_date", sa.Date(), nullable=True),
        sa.Column("year", sa.Integer(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("territory_id", GUID(), nullable=True),
        sa.Column("canonical_project_id", GUID(), nullable=True),
        sa.Column("generation_id", GUID(), nullable=True),
        sa.Column("visibility", sa.String(30), nullable=False, server_default="internal"),
        sa.Column("status", sa.String(40), nullable=False, server_default="reported"),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_event_validation"),
        sa.CheckConstraint("year BETWEEN 1000 AND 9999", name="ck_memory_event_year"),
        sa.CheckConstraint(
            "end_date IS NULL OR event_date IS NULL OR end_date >= event_date",
            name="ck_memory_event_dates",
        ),
        sa.CheckConstraint(
            "visibility IN ('private', 'internal')", name="ck_memory_event_visibility"
        ),
        sa.ForeignKeyConstraint(
            ["territory_id"], ["institutional_territories.id"], ondelete="SET NULL"
        ),
        sa.ForeignKeyConstraint(
            ["canonical_project_id"],
            ["institutional_canonical_projects.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["generation_id"], ["institutional_generations.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_memory_event_timeline", "institutional_events", ["year", "event_date"]
    )
    op.create_index(
        "ix_memory_event_project",
        "institutional_events",
        ["canonical_project_id", "year"],
    )
    op.create_index(
        "ix_memory_event_territory",
        "institutional_events",
        ["territory_id", "year"],
    )

    op.create_table(
        "institutional_frameworks",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("name", sa.String(220), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("framework_type", sa.String(80), nullable=False),
        sa.Column("version_label", sa.String(100), nullable=False),
        sa.Column("effective_from_year", sa.Integer(), nullable=False),
        sa.Column("effective_to_year", sa.Integer(), nullable=True),
        sa.Column("steps", sa.JSON(), nullable=False),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_framework_validation"),
        sa.CheckConstraint(
            "effective_from_year BETWEEN 1000 AND 9999",
            name="ck_memory_framework_start_year",
        ),
        sa.CheckConstraint(
            "effective_to_year IS NULL OR (effective_to_year BETWEEN 1000 AND 9999 "
            "AND effective_to_year >= effective_from_year)",
            name="ck_memory_framework_end_year",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "name", "version_label", name="uq_memory_framework_name_version"
        ),
    )
    op.create_index(
        "ix_memory_framework_years",
        "institutional_frameworks",
        ["effective_from_year", "effective_to_year"],
    )

    op.create_table(
        "institutional_competition_participations",
        sa.Column("id", GUID(), nullable=False),
        sa.Column("competition_record_id", GUID(), nullable=False),
        sa.Column("participant_scope", sa.String(20), nullable=False),
        sa.Column("canonical_project_id", GUID(), nullable=True),
        sa.Column("stage", sa.String(140), nullable=True),
        sa.Column("result", sa.String(180), nullable=True),
        *_fact_columns(),
        sa.CheckConstraint(VALIDATION_SQL, name="ck_memory_participation_validation"),
        sa.CheckConstraint(
            "participant_scope IN ('organization', 'project')",
            name="ck_memory_participation_scope",
        ),
        sa.CheckConstraint(
            "(participant_scope = 'organization' AND canonical_project_id IS NULL) OR "
            "(participant_scope = 'project' AND canonical_project_id IS NOT NULL)",
            name="ck_memory_participation_project",
        ),
        sa.ForeignKeyConstraint(
            ["competition_record_id"],
            ["archive_competition_records.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["canonical_project_id"],
            ["institutional_canonical_projects.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "uq_memory_competition_organization",
        "institutional_competition_participations",
        ["competition_record_id"],
        unique=True,
        postgresql_where=sa.text("participant_scope = 'organization'"),
        sqlite_where=sa.text("participant_scope = 'organization'"),
    )
    op.create_index(
        "uq_memory_competition_project",
        "institutional_competition_participations",
        ["competition_record_id", "canonical_project_id"],
        unique=True,
        postgresql_where=sa.text("participant_scope = 'project'"),
        sqlite_where=sa.text("participant_scope = 'project'"),
    )


def _extend_archive_tables() -> None:
    with op.batch_alter_table("archive_competition_records") as batch:
        batch.add_column(sa.Column("territory_id", GUID(), nullable=True))
        batch.add_column(sa.Column("source_id", GUID(), nullable=True))
        batch.add_column(
            sa.Column(
                "validation_status",
                sa.String(32),
                nullable=False,
                server_default="HISTORICAL_REPORTED",
            )
        )
        batch.add_column(sa.Column("created_by_id", GUID(), nullable=True))
        batch.add_column(sa.Column("validated_by_id", GUID(), nullable=True))
        batch.add_column(sa.Column("validated_at", sa.DateTime(), nullable=True))
        batch.create_check_constraint(
            "ck_archive_competition_memory_validation", VALIDATION_SQL
        )
        batch.create_foreign_key(
            "fk_archive_competition_territory",
            "institutional_territories",
            ["territory_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch.create_foreign_key(
            "fk_archive_competition_source",
            "institutional_sources",
            ["source_id"],
            ["id"],
            ondelete="RESTRICT",
        )
        batch.create_foreign_key(
            "fk_archive_competition_created_by",
            "users",
            ["created_by_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch.create_foreign_key(
            "fk_archive_competition_validated_by",
            "users",
            ["validated_by_id"],
            ["id"],
            ondelete="SET NULL",
        )

    with op.batch_alter_table("archive_awards") as batch:
        batch.add_column(sa.Column("competition_record_id", GUID(), nullable=True))
        batch.add_column(sa.Column("canonical_project_id", GUID(), nullable=True))
        batch.add_column(sa.Column("source_id", GUID(), nullable=True))
        batch.add_column(
            sa.Column(
                "validation_status",
                sa.String(32),
                nullable=False,
                server_default="HISTORICAL_REPORTED",
            )
        )
        batch.add_column(sa.Column("created_by_id", GUID(), nullable=True))
        batch.add_column(sa.Column("validated_by_id", GUID(), nullable=True))
        batch.add_column(sa.Column("validated_at", sa.DateTime(), nullable=True))
        batch.create_check_constraint("ck_archive_award_memory_validation", VALIDATION_SQL)
        batch.create_foreign_key(
            "fk_archive_award_competition",
            "archive_competition_records",
            ["competition_record_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch.create_foreign_key(
            "fk_archive_award_project",
            "institutional_canonical_projects",
            ["canonical_project_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch.create_foreign_key(
            "fk_archive_award_source",
            "institutional_sources",
            ["source_id"],
            ["id"],
            ondelete="RESTRICT",
        )
        batch.create_foreign_key(
            "fk_archive_award_created_by",
            "users",
            ["created_by_id"],
            ["id"],
            ondelete="SET NULL",
        )
        batch.create_foreign_key(
            "fk_archive_award_validated_by",
            "users",
            ["validated_by_id"],
            ["id"],
            ondelete="SET NULL",
        )


def upgrade() -> None:
    tables, competition_columns, award_columns = _schema_state()
    present_tables = MEMORY_TABLES.intersection(tables)
    present_competition = COMPETITION_COLUMNS.intersection(competition_columns)
    present_awards = AWARD_COLUMNS.intersection(award_columns)
    if (
        present_tables == MEMORY_TABLES
        and present_competition == COMPETITION_COLUMNS
        and present_awards == AWARD_COLUMNS
    ):
        return
    if present_tables or present_competition or present_awards:
        raise RuntimeError("Partial PR-2D institutional-memory schema detected")
    _create_tables()
    _extend_archive_tables()


def downgrade() -> None:
    tables, competition_columns, award_columns = _schema_state()
    if not MEMORY_TABLES.intersection(tables):
        return

    with op.batch_alter_table("archive_awards") as batch:
        batch.drop_constraint("fk_archive_award_validated_by", type_="foreignkey")
        batch.drop_constraint("fk_archive_award_created_by", type_="foreignkey")
        batch.drop_constraint("fk_archive_award_source", type_="foreignkey")
        batch.drop_constraint("fk_archive_award_project", type_="foreignkey")
        batch.drop_constraint("fk_archive_award_competition", type_="foreignkey")
        batch.drop_constraint("ck_archive_award_memory_validation", type_="check")
        for column in (
            "validated_at",
            "validated_by_id",
            "created_by_id",
            "validation_status",
            "source_id",
            "canonical_project_id",
            "competition_record_id",
        ):
            batch.drop_column(column)

    op.drop_table("institutional_competition_participations")

    with op.batch_alter_table("archive_competition_records") as batch:
        batch.drop_constraint("fk_archive_competition_validated_by", type_="foreignkey")
        batch.drop_constraint("fk_archive_competition_created_by", type_="foreignkey")
        batch.drop_constraint("fk_archive_competition_source", type_="foreignkey")
        batch.drop_constraint("fk_archive_competition_territory", type_="foreignkey")
        batch.drop_constraint("ck_archive_competition_memory_validation", type_="check")
        for column in (
            "validated_at",
            "validated_by_id",
            "created_by_id",
            "validation_status",
            "source_id",
            "territory_id",
        ):
            batch.drop_column(column)

    for table_name in (
        "institutional_frameworks",
        "institutional_events",
        "institutional_project_relationships",
        "institutional_project_years",
        "institutional_project_aliases",
        "institutional_leadership_terms",
        "institutional_canonical_projects",
        "institutional_generations",
        "institutional_territories",
        "institutional_sources",
    ):
        op.drop_table(table_name)
