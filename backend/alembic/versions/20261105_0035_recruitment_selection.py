"""Blind dossier evaluation and campaign-wide result publication.

Revision ID: 20261105_0035
Revises: 20261104_0034
"""
from alembic import op
import sqlalchemy as sa

from app.db.types import GUID

revision = "20261105_0035"
down_revision = "20261104_0034"
branch_labels = None
depends_on = None


def upgrade():
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    campaign_columns = {column["name"] for column in inspector.get_columns("recruitment_campaigns")}
    additions = [
        sa.Column("selection_policy_version", sa.String(40), nullable=True),
        sa.Column("screening_min_reviews", sa.Integer(), nullable=False, server_default="2"),
        sa.Column("screening_disagreement_threshold", sa.Integer(), nullable=False, server_default="20"),
        sa.Column("screening_published_at", sa.DateTime(), nullable=True),
        sa.Column("final_published_at", sa.DateTime(), nullable=True),
        sa.Column("identities_revealed_at", sa.DateTime(), nullable=True),
        sa.Column("identities_revealed_by", GUID(), nullable=True),
    ]
    with op.batch_alter_table("recruitment_campaigns") as batch:
        for column in additions:
            if column.name not in campaign_columns:
                batch.add_column(column)
        if "identities_revealed_by" not in campaign_columns:
            batch.create_foreign_key("fk_selection_identity_actor", "users", ["identities_revealed_by"], ["id"], ondelete="SET NULL")
    application_columns = {column["name"] for column in inspector.get_columns("applications")}
    with op.batch_alter_table("applications") as batch:
        for column in [
            sa.Column("other_clubs_count", sa.Integer(), nullable=True),
            sa.Column("screening_decision", sa.String(24), nullable=True),
            sa.Column("legacy_result_published", sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column("pending_final_decision", sa.String(24), nullable=True),
        ]:
            if column.name not in application_columns:
                batch.add_column(column)
    review_columns = {column["name"] for column in inspector.get_columns("application_reviews")}
    unique_names = {constraint["name"] for constraint in inspector.get_unique_constraints("application_reviews")}
    with op.batch_alter_table("application_reviews") as batch:
        if "stage" not in review_columns:
            batch.add_column(sa.Column("stage", sa.String(20), nullable=False, server_default="screening"))
        if "uq_application_reviewer" in unique_names:
            batch.drop_constraint("uq_application_reviewer", type_="unique")
        if "uq_application_reviewer_stage" not in unique_names:
            batch.create_unique_constraint("uq_application_reviewer_stage", ["application_id", "reviewer_id", "stage"])
    if not inspector.has_table("application_screening_assignments"):
        op.create_table(
            "application_screening_assignments",
            sa.Column("application_id", GUID(), sa.ForeignKey("applications.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("reviewer_id", GUID(), sa.ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
            sa.Column("assigned_by", GUID(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("assigned_at", sa.DateTime(), nullable=False),
            sa.Column("declined_at", sa.DateTime(), nullable=True),
            sa.Column("decline_reason", sa.String(500), nullable=True),
        )
    # Every existing campaign with ongoing dossiers enters the blind workflow.
    # Completed historical campaigns keep their published outcomes.
    op.execute(sa.text("""
        UPDATE recruitment_campaigns SET selection_policy_version = 'blind-selection-v1'
        WHERE is_active = true OR EXISTS (
            SELECT 1 FROM applications
            WHERE applications.campaign_id = recruitment_campaigns.id
            AND applications.status IN ('submitted', 'under_review', 'received', 'preselected')
        )
    """))
    op.execute(sa.text("""
        UPDATE applications SET legacy_result_published = true
        WHERE status IN ('accepted', 'rejected', 'waiting_list', 'cancelled')
    """))
    op.execute(sa.text("""
        UPDATE applications SET screening_decision = 'shortlisted'
        WHERE status IN ('interview_scheduled', 'interview')
    """))
    op.execute(sa.text("""
        UPDATE application_reviews SET stage = 'interview' WHERE application_id IN (
            SELECT id FROM applications WHERE status IN ('interview_scheduled', 'interview')
        )
    """))
    op.execute(sa.text("""
        UPDATE recruitment_campaigns SET screening_published_at = CURRENT_TIMESTAMP
        WHERE selection_policy_version = 'blind-selection-v1'
        AND EXISTS (SELECT 1 FROM applications WHERE applications.campaign_id = recruitment_campaigns.id)
        AND NOT EXISTS (
            SELECT 1 FROM applications WHERE applications.campaign_id = recruitment_campaigns.id
            AND applications.status IN ('submitted', 'under_review', 'received', 'preselected')
        )
    """))
    op.execute(sa.text("""
        UPDATE notifications SET message = 'Une candidature a été reçue pour cette campagne.'
        WHERE type = 'application_received' AND related_id IN (
            SELECT applications.id FROM applications JOIN recruitment_campaigns
            ON recruitment_campaigns.id = applications.campaign_id
            WHERE recruitment_campaigns.selection_policy_version = 'blind-selection-v1'
        )
    """))
    op.execute(sa.text("""
        UPDATE email_deliveries SET
            text_body = 'Une candidature a été reçue. Consulte le recrutement dans EnactSpace.',
            html_body = NULL
        WHERE status IN ('pending', 'retry') AND notification_id IN (
            SELECT id FROM notifications WHERE type = 'application_received'
            AND related_id IN (
                SELECT applications.id FROM applications JOIN recruitment_campaigns
                ON recruitment_campaigns.id = applications.campaign_id
                WHERE recruitment_campaigns.selection_policy_version = 'blind-selection-v1'
            )
        )
    """))


def downgrade():
    duplicate = op.get_bind().execute(sa.text("""
        SELECT application_id FROM application_reviews
        GROUP BY application_id, reviewer_id HAVING count(*) > 1
    """)).first()
    if duplicate:
        raise RuntimeError("Des évaluations de dossier et d’entretien existent. Conserve la révision de sélection.")
    op.drop_table("application_screening_assignments")
    with op.batch_alter_table("application_reviews") as batch:
        batch.drop_constraint("uq_application_reviewer_stage", type_="unique")
        batch.drop_column("stage")
        batch.create_unique_constraint("uq_application_reviewer", ["application_id", "reviewer_id"])
    with op.batch_alter_table("applications") as batch:
        batch.drop_column("pending_final_decision")
        batch.drop_column("screening_decision")
        batch.drop_column("legacy_result_published")
        batch.drop_column("other_clubs_count")
    with op.batch_alter_table("recruitment_campaigns") as batch:
        foreign_keys = sa.inspect(op.get_bind()).get_foreign_keys("recruitment_campaigns")
        for constraint in foreign_keys:
            if constraint.get("name") and constraint.get("constrained_columns") == ["identities_revealed_by"]:
                batch.drop_constraint(constraint["name"], type_="foreignkey")
        for column in (
            "identities_revealed_by", "identities_revealed_at", "final_published_at",
            "screening_published_at", "screening_disagreement_threshold",
            "screening_min_reviews", "selection_policy_version",
        ):
            batch.drop_column(column)
