import argparse
import csv
import re
import secrets
import sys
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path

from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.db.database import SessionLocal, ensure_compatibility_columns
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember
from app.models.role import Role, UserRole
from app.models.user import User


REQUIRED_COLUMNS = {
    "prenom",
    "nom",
    "email",
}
OPTIONAL_COLUMNS = {
    "telephone",
    "genre",
    "role",
    "statut",
    "pole_coeur",
    "poles_support",
    "projet",
    "responsabilite",
    "date_adhesion",
}
ALL_COLUMNS = REQUIRED_COLUMNS | OPTIONAL_COLUMNS
VALID_STATUSES = {"active", "pending", "alumni", "inactive"}


@dataclass
class ImportReport:
    rows: int = 0
    created_users: int = 0
    updated_users: int = 0
    role_links: int = 0
    pole_links: int = 0
    project_links: int = 0
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def has_errors(self) -> bool:
        return bool(self.errors)


@dataclass
class MemberRow:
    row_number: int
    first_name: str
    last_name: str
    email: str
    phone: str | None
    gender: str | None
    roles: list[str]
    status: str
    core_pole: str | None
    support_poles: list[str]
    project: str | None
    responsibility: str
    joined_at: date | None


def normalize_text(value: str | None) -> str:
    return " ".join((value or "").strip().split())


def normalize_email(value: str | None) -> str:
    return normalize_text(value).lower()


def normalize_phone(value: str | None) -> str | None:
    phone = normalize_text(value)
    if not phone:
        return None
    cleaned = re.sub(r"[^\d+]", "", phone)
    if cleaned.startswith("00"):
        cleaned = f"+{cleaned[2:]}"
    return cleaned or None


def normalize_role(value: str) -> str:
    normalized = normalize_text(value).lower()
    normalized = (
        normalized.replace(" ", "_")
        .replace("-", "_")
        .replace("é", "e")
        .replace("è", "e")
        .replace("ê", "e")
        .replace("à", "a")
        .replace("ç", "c")
    )
    return normalized


def split_values(value: str | None) -> list[str]:
    raw = normalize_text(value)
    if not raw:
        return []
    return [
        normalize_text(part)
        for part in re.split(r"[;,|]", raw)
        if normalize_text(part)
    ]


def parse_date(value: str | None, report: ImportReport, row_number: int) -> date | None:
    raw = normalize_text(value)
    if not raw:
        return None
    for pattern in ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y"):
        try:
            return datetime.strptime(raw, pattern).date()
        except ValueError:
            continue
    report.errors.append(
        f"Ligne {row_number}: date_adhesion invalide '{raw}'. Formats: YYYY-MM-DD, DD/MM/YYYY."
    )
    return None


def parse_member_row(row: dict[str, str], row_number: int, report: ImportReport) -> MemberRow | None:
    error_count_before = len(report.errors)
    first_name = normalize_text(row.get("prenom"))
    last_name = normalize_text(row.get("nom"))
    email = normalize_email(row.get("email"))

    if not first_name:
        report.errors.append(f"Ligne {row_number}: prenom obligatoire.")
    if not last_name:
        report.errors.append(f"Ligne {row_number}: nom obligatoire.")
    if not email or "@" not in email:
        report.errors.append(f"Ligne {row_number}: email invalide.")

    status_value = normalize_role(row.get("statut") or "active")
    if status_value not in VALID_STATUSES:
        report.errors.append(
            f"Ligne {row_number}: statut '{status_value}' invalide. Valeurs: {sorted(VALID_STATUSES)}."
        )

    roles = [normalize_role(role) for role in split_values(row.get("role"))]
    if status_value == "alumni" and "alumni" not in roles:
        roles.append("alumni")
    if status_value != "alumni" and "enacteur" not in roles:
        roles.append("enacteur")

    joined_at = parse_date(row.get("date_adhesion"), report, row_number)
    if len(report.errors) > error_count_before:
        return None

    return MemberRow(
        row_number=row_number,
        first_name=first_name,
        last_name=last_name,
        email=email,
        phone=normalize_phone(row.get("telephone")),
        gender=normalize_role(row.get("genre") or "") or None,
        roles=roles,
        status=status_value,
        core_pole=normalize_text(row.get("pole_coeur")) or None,
        support_poles=split_values(row.get("poles_support")),
        project=normalize_text(row.get("projet")) or None,
        responsibility=normalize_role(row.get("responsabilite") or "membre"),
        joined_at=joined_at,
    )


def load_csv(path: Path, report: ImportReport) -> list[MemberRow]:
    if not path.exists():
        report.errors.append(f"Fichier introuvable: {path}")
        return []

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        headers = set(reader.fieldnames or [])
        missing = REQUIRED_COLUMNS - headers
        unknown = headers - ALL_COLUMNS
        if missing:
            report.errors.append(f"Colonnes obligatoires manquantes: {sorted(missing)}")
            return []
        if unknown:
            report.warnings.append(f"Colonnes ignorees: {sorted(unknown)}")

        rows = []
        seen_emails: set[str] = set()
        seen_phones: set[str] = set()
        for row_number, row in enumerate(reader, start=2):
            report.rows += 1
            member = parse_member_row(row, row_number, report)
            if member is None:
                continue
            if member.email in seen_emails:
                report.errors.append(f"Ligne {row_number}: email duplique dans le CSV.")
                continue
            seen_emails.add(member.email)
            if member.phone:
                if member.phone in seen_phones:
                    report.errors.append(f"Ligne {row_number}: telephone duplique dans le CSV.")
                    continue
                seen_phones.add(member.phone)
            rows.append(member)

    return rows


def find_pole(db: Session, name: str | None) -> Pole | None:
    if not name:
        return None
    key = name.strip().lower()
    for pole in db.query(Pole).all():
        names = {pole.name.strip().lower()}
        if pole.short_name:
            names.add(pole.short_name.strip().lower())
        if key in names:
            return pole
    return None


def find_project(db: Session, name: str | None) -> Project | None:
    if not name:
        return None
    key = name.strip().lower()
    for project in db.query(Project).all():
        if project.name.strip().lower() == key:
            return project
    return None


def ensure_roles(db: Session, role_names: list[str], report: ImportReport, row_number: int) -> list[Role]:
    roles = []
    for role_name in role_names:
        role = db.query(Role).filter(Role.name == role_name).first()
        if not role:
            report.errors.append(f"Ligne {row_number}: role inconnu '{role_name}'.")
            continue
        roles.append(role)
    return roles


def upsert_user(db: Session, member: MemberRow, report: ImportReport, update_existing: bool) -> User | None:
    existing = db.query(User).filter(User.email == member.email).first()
    phone_owner = None
    if member.phone:
        phone_owner = (
            db.query(User)
            .filter(User.phone == member.phone, User.email != member.email)
            .first()
        )
    if phone_owner:
        report.errors.append(
            f"Ligne {member.row_number}: telephone deja utilise par {phone_owner.email}."
        )
        return None

    profile_type = "alumni" if member.status == "alumni" or "alumni" in member.roles else "enacteur"

    if existing:
        if not update_existing:
            report.warnings.append(
                f"Ligne {member.row_number}: utilisateur existant ignore ({member.email})."
            )
            return existing
        existing.first_name = member.first_name
        existing.last_name = member.last_name
        existing.phone = member.phone
        existing.gender = member.gender
        existing.profile_type = profile_type
        existing.status = member.status
        existing.department = existing.department or member.core_pole
        existing.is_active = member.status != "inactive"
        report.updated_users += 1
        return existing

    user = User(
        first_name=member.first_name,
        last_name=member.last_name,
        email=member.email,
        phone=member.phone,
        gender=member.gender,
        profile_type=profile_type,
        password_hash=hash_password(secrets.token_urlsafe(24)),
        department=member.core_pole,
        status=member.status,
        email_verified=False,
        is_active=member.status != "inactive",
    )
    db.add(user)
    db.flush()
    report.created_users += 1
    return user


def link_roles(db: Session, user: User, roles: list[Role], report: ImportReport) -> None:
    existing_ids = {
        role_id
        for (role_id,) in db.query(UserRole.role_id)
        .filter(UserRole.user_id == user.id)
        .all()
    }
    for role in roles:
        if role.id in existing_ids:
            continue
        db.add(UserRole(user_id=user.id, role_id=role.id))
        report.role_links += 1


def link_pole(db: Session, user: User, pole: Pole, position: str, joined_at: date | None, report: ImportReport) -> None:
    existing = (
        db.query(PoleMember)
        .filter(PoleMember.user_id == user.id, PoleMember.pole_id == pole.id)
        .first()
    )
    if existing:
        if not existing.is_active:
            existing.is_active = True
            existing.left_at = None
        existing.position = position or existing.position
        return
    db.add(
        PoleMember(
            user_id=user.id,
            pole_id=pole.id,
            position=position or "membre",
            joined_at=joined_at or date.today(),
            is_active=True,
        )
    )
    report.pole_links += 1


def link_project(db: Session, user: User, project: Project, position: str, joined_at: date | None, report: ImportReport) -> None:
    existing = (
        db.query(ProjectMember)
        .filter(ProjectMember.user_id == user.id, ProjectMember.project_id == project.id)
        .first()
    )
    if existing:
        if not existing.is_active:
            existing.is_active = True
            existing.left_at = None
        existing.position = position or existing.position
        return
    db.add(
        ProjectMember(
            user_id=user.id,
            project_id=project.id,
            position=position or "membre",
            joined_at=joined_at or date.today(),
            is_active=True,
        )
    )
    report.project_links += 1


def import_members(
    db: Session,
    rows: list[MemberRow],
    report: ImportReport,
    *,
    update_existing: bool,
) -> None:
    for member in rows:
        error_count_before = len(report.errors)
        roles = ensure_roles(db, member.roles, report, member.row_number)
        if len(report.errors) > error_count_before:
            continue

        user = upsert_user(db, member, report, update_existing)
        if not user:
            continue

        link_roles(db, user, roles, report)

        core_pole = find_pole(db, member.core_pole)
        if member.core_pole and not core_pole:
            report.errors.append(
                f"Ligne {member.row_number}: pole_coeur inconnu '{member.core_pole}'."
            )
        if core_pole:
            link_pole(db, user, core_pole, member.responsibility, member.joined_at, report)

        for support_pole_name in member.support_poles:
            support_pole = find_pole(db, support_pole_name)
            if not support_pole:
                report.errors.append(
                    f"Ligne {member.row_number}: pole support inconnu '{support_pole_name}'."
                )
                continue
            link_pole(db, user, support_pole, "support", member.joined_at, report)

        project = find_project(db, member.project)
        if member.project and not project:
            report.errors.append(
                f"Ligne {member.row_number}: projet inconnu '{member.project}'."
            )
        if project:
            link_project(db, user, project, member.responsibility, member.joined_at, report)


def print_report(report: ImportReport, *, dry_run: bool) -> None:
    mode = "DRY-RUN" if dry_run else "APPLY"
    print(f"Mode: {mode}")
    print(f"Lignes lues: {report.rows}")
    print(f"Utilisateurs crees: {report.created_users}")
    print(f"Utilisateurs mis a jour: {report.updated_users}")
    print(f"Roles ajoutes: {report.role_links}")
    print(f"Liaisons poles ajoutees: {report.pole_links}")
    print(f"Liaisons projets ajoutees: {report.project_links}")
    if report.warnings:
        print("\nWarnings:")
        for warning in report.warnings:
            print(f"- {warning}")
    if report.errors:
        print("\nErrors:")
        for error in report.errors:
            print(f"- {error}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import Enactus ESP members from CSV.")
    parser.add_argument("--file", required=True, help="Path to the CSV file.")
    parser.add_argument("--dry-run", action="store_true", help="Validate without committing.")
    parser.add_argument("--apply", action="store_true", help="Commit valid imports.")
    parser.add_argument(
        "--update-existing",
        action="store_true",
        help="Update existing users matched by email.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.apply == args.dry_run:
        print("Use exactly one mode: --dry-run or --apply.", file=sys.stderr)
        return 2

    report = ImportReport()
    rows = load_csv(Path(args.file), report)
    if report.has_errors:
        print_report(report, dry_run=args.dry_run)
        return 1

    ensure_compatibility_columns()
    db = SessionLocal()
    try:
        import_members(
            db,
            rows,
            report,
            update_existing=args.update_existing,
        )
        if report.has_errors or args.dry_run:
            db.rollback()
        else:
            db.commit()
    finally:
        db.close()

    print_report(report, dry_run=args.dry_run)
    return 1 if report.has_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
