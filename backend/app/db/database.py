from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from app.core.config import settings


connect_args = {}

if settings.DATABASE_URL.startswith("sqlite"):
    connect_args = {
        "check_same_thread": False,
    }


engine = create_engine(
    settings.DATABASE_URL,
    connect_args=connect_args,
)


SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()


def ensure_compatibility_columns() -> None:
    # Import every model before create_all so installations upgraded from an
    # older database receive newly introduced tables without losing data.
    import app.models.base  # noqa: F401

    Base.metadata.create_all(bind=engine)

    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return

    columns = {column["name"] for column in inspector.get_columns("users")}
    statements = []
    if "gender" not in columns:
        statements.append("ALTER TABLE users ADD COLUMN gender VARCHAR(20)")
    if "profile_type" not in columns:
        statements.append(
            "ALTER TABLE users ADD COLUMN profile_type VARCHAR(30) "
            "DEFAULT 'enacteur'"
        )

    if statements:
        with engine.begin() as connection:
            for statement in statements:
                connection.execute(text(statement))
