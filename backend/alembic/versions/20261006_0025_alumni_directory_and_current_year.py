"""Repair Alumni directory entries and enforce one current year."""
import uuid
from datetime import datetime, timezone
from alembic import op
import sqlalchemy as sa

revision = "20261006_0025"
down_revision = "20261006_0024"
branch_labels = None
depends_on = None


def upgrade():
    conn = op.get_bind()
    meta = sa.MetaData()
    users = sa.Table("users", meta, autoload_with=conn)
    profiles = sa.Table("alumni_profiles", meta, autoload_with=conn)
    missing = conn.execute(sa.select(users.c.id).where(
        users.c.status == "alumni", users.c.is_active.is_(True),
        ~sa.exists(sa.select(profiles.c.id).where(profiles.c.user_id == users.c.id))
    )).scalars().all()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    for user_id in missing:
        profile_id = uuid.uuid4()
        if conn.dialect.name == "sqlite":
            profile_id = str(profile_id)
        conn.execute(profiles.insert().values(id=profile_id, user_id=user_id,
            available_for_mentoring=False, visibility="internal",
            created_at=now, updated_at=now))
    seasons = sa.Table("seasons", meta, autoload_with=conn)
    for row in conn.execute(sa.select(seasons.c.id, seasons.c.name)):
        if row.name.startswith("Saison "):
            conn.execute(seasons.update().where(seasons.c.id == row.id)
                         .values(name="Année " + row.name[7:]))
    existing = {i["name"] for i in sa.inspect(conn).get_indexes("seasons")}
    if "ux_seasons_current" not in existing:
        op.create_index("ux_seasons_current", "seasons", ["is_current"], unique=True,
                        postgresql_where=sa.text("is_current = true"),
                        sqlite_where=sa.text("is_current = 1"))


def downgrade():
    # Alumni profiles belong to members: never delete them in a code rollback.
    existing = {i["name"] for i in sa.inspect(op.get_bind()).get_indexes("seasons")}
    if "ux_seasons_current" in existing:
        op.drop_index("ux_seasons_current", table_name="seasons")
