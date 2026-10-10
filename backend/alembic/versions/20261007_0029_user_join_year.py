"""Map the existing user join year, including installations lacking the column."""
from alembic import op
import sqlalchemy as sa
revision = "20261007_0029"
down_revision = "20261007_0028"
branch_labels = None
depends_on = None

def upgrade():
    columns = {column["name"]: column for column in sa.inspect(op.get_bind()).get_columns("users")}
    if "enactus_join_year" not in columns:
        op.add_column("users", sa.Column("enactus_join_year", sa.Integer(), nullable=True))
    elif not isinstance(columns["enactus_join_year"]["type"], sa.Integer):
        raise RuntimeError("users.enactus_join_year must be an integer")
    # Preserve recorded Alumni years without overwriting user-level historical data.
    op.execute(sa.text("""UPDATE users SET enactus_join_year =
        (SELECT alumni_profiles.enactus_join_year FROM alumni_profiles
         WHERE alumni_profiles.user_id = users.id)
        WHERE users.enactus_join_year IS NULL AND EXISTS
        (SELECT 1 FROM alumni_profiles WHERE alumni_profiles.user_id = users.id
         AND alumni_profiles.enactus_join_year IS NOT NULL)"""))

def downgrade():
    # This historical column predates this repair on deployed databases.
    # Retain it and its data on every installation rather than dropping history.
    pass
