from __future__ import annotations

import argparse
import os

from app.db.database import SessionLocal
from app.services.seed_service import (
    seed_admin_user,
    seed_badges,
    seed_current_season,
    seed_poles,
    seed_projects,
    seed_roles,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Initialize EnactSpace production reference data.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run checks and rollback instead of committing changes.",
    )
    return parser.parse_args()


def initial_admin_config() -> dict[str, str] | None:
    email = os.getenv("ENACTSPACE_INITIAL_ADMIN_EMAIL")
    password = os.getenv("ENACTSPACE_INITIAL_ADMIN_PASSWORD")
    if not email and not password:
        return None
    if not email or not password:
        raise ValueError(
            "Both ENACTSPACE_INITIAL_ADMIN_EMAIL and "
            "ENACTSPACE_INITIAL_ADMIN_PASSWORD are required"
        )
    if len(password) < 12:
        raise ValueError("Initial admin password must contain at least 12 characters")
    return {
        "email": email.strip().lower(),
        "password": password,
        "first_name": os.getenv("ENACTSPACE_INITIAL_ADMIN_FIRST_NAME", "Admin"),
        "last_name": os.getenv("ENACTSPACE_INITIAL_ADMIN_LAST_NAME", "EnactSpace"),
    }


def main() -> int:
    args = parse_args()
    db = SessionLocal()
    try:
        roles_created = seed_roles(db)
        season, season_created = seed_current_season(db)
        poles_created = seed_poles(db, season)
        projects_created = seed_projects(db, season)
        badges_created = seed_badges(db)

        admin_created = False
        admin_config = initial_admin_config()
        if admin_config:
            _, admin_created = seed_admin_user(
                db,
                first_name=admin_config["first_name"],
                last_name=admin_config["last_name"],
                email=admin_config["email"],
                password=admin_config["password"],
            )

        if args.dry_run:
            db.rollback()
        else:
            db.commit()

        print("Production initialization complete")
        print(f"dry_run={args.dry_run}")
        print(f"roles_created={roles_created}")
        print(f"season_created={season_created}")
        print(f"poles_created={poles_created}")
        print(f"projects_created={projects_created}")
        print(f"badges_created={badges_created}")
        print(f"initial_admin_created={admin_created}")
        print("No secrets were printed.")
        return 0
    except Exception as exc:
        db.rollback()
        print("Production initialization failed")
        print(str(exc))
        return 1
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
