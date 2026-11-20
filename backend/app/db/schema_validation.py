"""Read-only deployment check: an Alembic stamp alone cannot prove schema parity."""
import json
from sqlalchemy import inspect


def schema_gaps(connection, metadata):
    inspector = inspect(connection)
    tables = set(inspector.get_table_names())
    missing_tables = []
    missing_columns = []
    for name, table in sorted(metadata.tables.items()):
        if name not in tables:
            missing_tables.append(name)
            continue
        columns = {column["name"] for column in inspector.get_columns(name)}
        missing_columns.extend(
            {"table": name, "column": column.name}
            for column in table.columns if column.name not in columns
        )
    return {
        "model_table_count": len(metadata.tables),
        "missing_tables": missing_tables,
        "missing_columns": missing_columns,
    }


def main():
    import app.models.base  # Register all production models.
    from app.db.database import Base, engine
    with engine.connect() as connection:
        report = schema_gaps(connection, Base.metadata)
    print(json.dumps(report))
    return 1 if report["missing_tables"] or report["missing_columns"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
