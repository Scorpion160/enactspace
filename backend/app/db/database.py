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

    if "attendance_sessions" in inspector.get_table_names():
        session_columns = {
            column["name"] for column in inspector.get_columns("attendance_sessions")
        }
        if "scope_type" not in session_columns:
            statements.append(
                "ALTER TABLE attendance_sessions ADD COLUMN scope_type "
                "VARCHAR(40) DEFAULT 'club'"
            )
        if "group_name" not in session_columns:
            statements.append(
                "ALTER TABLE attendance_sessions ADD COLUMN group_name VARCHAR(150)"
            )
        if "status" not in session_columns:
            statements.append(
                "ALTER TABLE attendance_sessions ADD COLUMN status "
                "VARCHAR(40) DEFAULT 'draft'"
            )
        if "notes" not in session_columns:
            statements.append("ALTER TABLE attendance_sessions ADD COLUMN notes TEXT")

    if "attendance_records" in inspector.get_table_names():
        record_columns = {
            column["name"] for column in inspector.get_columns("attendance_records")
        }
        if "delay_minutes" not in record_columns:
            statements.append(
                "ALTER TABLE attendance_records ADD COLUMN delay_minutes INTEGER"
            )
        if "recorded_at" not in record_columns:
            statements.append(
                "ALTER TABLE attendance_records ADD COLUMN recorded_at DATETIME"
            )
        if "justification_status" not in record_columns:
            statements.append(
                "ALTER TABLE attendance_records ADD COLUMN justification_status "
                "VARCHAR(40) DEFAULT 'not_submitted'"
            )
        if "justification_reason" not in record_columns:
            statements.append(
                "ALTER TABLE attendance_records ADD COLUMN justification_reason TEXT"
            )
        if "justification_file_id" not in record_columns:
            statements.append(
                "ALTER TABLE attendance_records ADD COLUMN justification_file_id CHAR(36)"
            )

    if "fees" in inspector.get_table_names():
        fee_columns = {column["name"] for column in inspector.get_columns("fees")}
        if "category" not in fee_columns:
            statements.append("ALTER TABLE fees ADD COLUMN category VARCHAR(100)")
        if "description" not in fee_columns:
            statements.append("ALTER TABLE fees ADD COLUMN description TEXT")
        if "currency" not in fee_columns:
            statements.append("ALTER TABLE fees ADD COLUMN currency VARCHAR(10) DEFAULT 'FCFA'")
        if "paid_at" not in fee_columns:
            statements.append("ALTER TABLE fees ADD COLUMN paid_at DATETIME")
        if "cancelled_at" not in fee_columns:
            statements.append("ALTER TABLE fees ADD COLUMN cancelled_at DATETIME")
        if "source_type" not in fee_columns:
            statements.append("ALTER TABLE fees ADD COLUMN source_type VARCHAR(80)")
        if "source_id" not in fee_columns:
            statements.append("ALTER TABLE fees ADD COLUMN source_id CHAR(36)")
        if "proof_file_id" not in fee_columns:
            statements.append("ALTER TABLE fees ADD COLUMN proof_file_id CHAR(36)")

    if "payments" in inspector.get_table_names():
        payment_columns = {
            column["name"] for column in inspector.get_columns("payments")
        }
        if "currency" not in payment_columns:
            statements.append(
                "ALTER TABLE payments ADD COLUMN currency VARCHAR(10) DEFAULT 'FCFA'"
            )
        if "proof_file_id" not in payment_columns:
            statements.append("ALTER TABLE payments ADD COLUMN proof_file_id CHAR(36)")
        if "rejected_at" not in payment_columns:
            statements.append("ALTER TABLE payments ADD COLUMN rejected_at DATETIME")
        if "rejection_reason" not in payment_columns:
            statements.append("ALTER TABLE payments ADD COLUMN rejection_reason TEXT")
        if "receipt_file_id" not in payment_columns:
            statements.append("ALTER TABLE payments ADD COLUMN receipt_file_id CHAR(36)")

    if "club_transactions" in inspector.get_table_names():
        transaction_columns = {
            column["name"] for column in inspector.get_columns("club_transactions")
        }
        if "description" not in transaction_columns:
            statements.append("ALTER TABLE club_transactions ADD COLUMN description TEXT")
        if "currency" not in transaction_columns:
            statements.append(
                "ALTER TABLE club_transactions ADD COLUMN currency VARCHAR(10) DEFAULT 'FCFA'"
            )
        if "proof_file_id" not in transaction_columns:
            statements.append(
                "ALTER TABLE club_transactions ADD COLUMN proof_file_id CHAR(36)"
            )

    if statements:
        with engine.begin() as connection:
            for statement in statements:
                connection.execute(text(statement))
