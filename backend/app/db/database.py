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

    if "documents" in inspector.get_table_names():
        document_columns = {
            column["name"] for column in inspector.get_columns("documents")
        }
        if "file_id" not in document_columns:
            statements.append("ALTER TABLE documents ADD COLUMN file_id CHAR(36)")
        if "status" not in document_columns:
            statements.append(
                "ALTER TABLE documents ADD COLUMN status VARCHAR(40) "
                "DEFAULT 'validated'"
            )
        if "rejected_by" not in document_columns:
            statements.append("ALTER TABLE documents ADD COLUMN rejected_by CHAR(36)")
        if "rejected_at" not in document_columns:
            statements.append("ALTER TABLE documents ADD COLUMN rejected_at DATETIME")
        if "rejection_reason" not in document_columns:
            statements.append("ALTER TABLE documents ADD COLUMN rejection_reason TEXT")
        if "is_permanent" not in document_columns:
            statements.append(
                "ALTER TABLE documents ADD COLUMN is_permanent BOOLEAN DEFAULT 0"
            )
        if "expires_at" not in document_columns:
            statements.append("ALTER TABLE documents ADD COLUMN expires_at DATETIME")

    if "posts" in inspector.get_table_names():
        post_columns = {column["name"] for column in inspector.get_columns("posts")}
        if "media_file_id" not in post_columns:
            statements.append("ALTER TABLE posts ADD COLUMN media_file_id CHAR(36)")
        if "media_url" not in post_columns:
            statements.append("ALTER TABLE posts ADD COLUMN media_url VARCHAR(500)")
        if "media_name" not in post_columns:
            statements.append("ALTER TABLE posts ADD COLUMN media_name VARCHAR(255)")
        if "media_mime_type" not in post_columns:
            statements.append("ALTER TABLE posts ADD COLUMN media_mime_type VARCHAR(120)")
        if "media_size_bytes" not in post_columns:
            statements.append("ALTER TABLE posts ADD COLUMN media_size_bytes INTEGER")

    if statements:
        with engine.begin() as connection:
            for statement in statements:
                connection.execute(text(statement))
