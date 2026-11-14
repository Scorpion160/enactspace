"""Campaign-specific application questionnaire and submission snapshots."""
from alembic import op
import sqlalchemy as sa

revision = '20261004_0020'
down_revision = '20260929_0019'
branch_labels = None
depends_on = None


def _columns(table):
    return {column['name'] for column in sa.inspect(op.get_bind()).get_columns(table)}


def upgrade():
    # The baseline creates current model metadata on a fresh installation.
    # Existing installations need the additions, while fresh ones already have them.
    if 'application_questions' not in _columns('recruitment_campaigns'):
        op.add_column('recruitment_campaigns', sa.Column('application_questions', sa.JSON(), nullable=True))
    if 'questionnaire_answers' not in _columns('applications'):
        op.add_column('applications', sa.Column('questionnaire_answers', sa.JSON(), nullable=True))


def downgrade():
    if 'questionnaire_answers' in _columns('applications'):
        op.drop_column('applications', 'questionnaire_answers')
    if 'application_questions' in _columns('recruitment_campaigns'):
        op.drop_column('recruitment_campaigns', 'application_questions')
