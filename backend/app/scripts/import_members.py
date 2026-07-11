import argparse
import csv
import io
import re
import secrets
import sys
from dataclasses import asdict, dataclass, field
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
}
OPTIONAL_COLUMNS = {
    "email",
    "telephone",
    "genre",
    "niveau_etude",
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
STATUS_ALIASES = {
    "actif": "active",
    "active": "active",
    "inactif": "inactive",
    "inactive": "inactive",
    "alumni": "alumni",
    "pending": "pending",
    "en_attente": "pending",
}
GENDER_ALIASES = {
    "m": "masculin",
    "homme": "masculin",
    "masculin": "masculin",
    "f": "feminin",
    "femme": "feminin",
    "feminin": "feminin",
}
RESPONSIBILITY_ROLE_ALIASES = {
    "team_leader": "team_leader",
    "tl": "team_leader",
    "chef_pole": "chef_pole",
    "chef_de_pole": "chef_pole",
    "adjoint": "adjoint_chef_pole",
    "adjoint_chef_pole": "adjoint_chef_pole",
    "chef_projet": "chef_projet",
    "chef_de_projet": "chef_projet",
    "adjoint_chef_projet": "adjoint_chef_projet",
    "sg": "secretaire_generale",
    "secretaire_generale": "secretaire_generale",
    "secretaire_general": "secretaire_generale",
    "financier": "financier",
    "finance": "financier",
}


@dataclass
class ImportIssue:
    row: int | None
    field: str | None
    message: str

    def as_text(self) -> str:
        prefix = f"Ligne {self.row}: " if self.row is not None else ""
        field = f"{self.field}: " if self.field else ""
        return f"{prefix}{field}{self.message}"


@dataclass
class ImportReport:
    rows: int = 0
    created_users: int = 0
    updated_users: int = 0
    role_links: int = 0
    pole_links: int = 0
    project_links: int = 0
    errors: list[ImportIssue] = field(default_factory=list)
    warnings: list[ImportIssue] = field(default_factory=list)
    duplicates: int = 0
    preview: list[dict] = field(default_factory=list)

    @property
    def has_errors(self) -> bool:
        return bool(self.errors)

    def error_rows(self) -> int:
        return len({issue.row for issue in self.errors if issue.row is not None})

    def warning_rows(self) -> int:
        return len({issue.row for issue in self.warnings if issue.row is not None})

    def to_dict(self) -> dict:
        valid_rows = max(self.rows - self.error_rows(), 0)
        return {
            "total_rows": self.rows,
            "valid_rows": valid_rows,
            "error_rows": self.error_rows(),
            "warning_rows": self.warning_rows(),
            "duplicates": self.duplicates,
            "created_users": self.created_users,
            "updated_users": self.updated_users,
            "role_links": self.role_links,
            "pole_links": self.pole_links,
            "project_links": self.project_links,
            "errors": [asdict(issue) for issue in self.errors],
            "warnings": [asdict(issue) for issue in self.warnings],
            "preview": self.preview[:50],
        }


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
    study_level: str | None = None

    def preview_item(self) -> dict:
        return {
            "row": self.row_number,
            "name": f"{self.first_name} {self.last_name}".strip(),
            "email": self.email,
            "phone": self.phone,
            "status": self.status,
            "roles": self.roles,
            "core_pole": self.core_pole,
            "support_poles": self.support_poles,
            "project": self.project,
            "responsibility": self.responsibility,
        }


def normalize_text(value: str | None) -> str:
    return " ".join((value or "").strip().split())


def normalize_email(value: str | None) -> str:
    return normalize_text(value).lower()


def make_internal_email(first_name: str, last_name: str) -> str:
    base = normalize_role(f"{first_name}.{last_name}").strip("_") or "membre"
    base = re.sub(r"[^a-z0-9._-]+", "", base)
    return f"{base}@enactspace.local"


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


def normalize_gender(value: str | None) -> str | None:
    normalized = normalize_role(value or "")
    if not normalized:
        return None
    return GENDER_ALIASES.get(normalized, normalized)


def normalize_status(value: str | None, report: ImportReport, row_number: int) -> str:
    raw = normalize_role(value or "")
    if not raw:
        report.warnings.append(
            ImportIssue(
                row=row_number,
                field="statut",
                message="Statut manquant: active utilise par defaut.",
            )
        )
        return "active"
    return STATUS_ALIASES.get(raw, raw)


def roles_from_responsibility(value: str | None) -> tuple[str, list[str]]:
    responsibility = normalize_role(value or "membre") or "membre"
    roles = []
    for key, role in RESPONSIBILITY_ROLE_ALIASES.items():
        if key in responsibility and role not in roles:
            roles.append(role)
    return responsibility, roles


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
        ImportIssue(
            row=row_number,
            field="date_adhesion",
            message=f"Date invalide '{raw}'. Formats: YYYY-MM-DD, DD/MM/YYYY.",
        )
    )
    return None


def parse_member_row(row: dict[str, str], row_number: int, report: ImportReport) -> MemberRow | None:
    error_count_before = len(report.errors)
    first_name = normalize_text(row.get("prenom"))
    last_name = normalize_text(row.get("nom"))
    email = normalize_email(row.get("email"))

    if not first_name:
        report.errors.append(
            ImportIssue(row=row_number, field="prenom", message="Prenom obligatoire.")
        )
    if not last_name:
        report.errors.append(
            ImportIssue(row=row_number, field="nom", message="Nom obligatoire.")
        )
    if not email:
        email = make_internal_email(first_name, last_name)
        report.warnings.append(
            ImportIssue(
                row=row_number,
                field="email",
                message=(
                    "Email manquant: un identifiant interne temporaire sera propose."
                ),
            )
        )
    elif "@" not in email:
        report.errors.append(
            ImportIssue(row=row_number, field="email", message="Email invalide.")
        )

    status_value = normalize_status(row.get("statut"), report, row_number)
    if status_value not in VALID_STATUSES:
        report.errors.append(
            ImportIssue(
                row=row_number,
                field="statut",
                message=f"Statut '{status_value}' invalide. Valeurs: {sorted(VALID_STATUSES)}.",
            )
        )

    roles = [normalize_role(role) for role in split_values(row.get("role"))]
    responsibility, responsibility_roles = roles_from_responsibility(
        row.get("responsabilite")
    )
    for role in responsibility_roles:
        if role not in roles:
            roles.append(role)
    if status_value == "alumni" and "alumni" not in roles:
        roles.append("alumni")
    if status_value != "alumni" and "enacteur" not in roles:
        roles.append("enacteur")

    core_pole = normalize_text(row.get("pole_coeur")) or None
    if not core_pole:
        report.errors.append(
            ImportIssue(
                row=row_number,
                field="pole_coeur",
                message="Pole coeur obligatoire.",
            )
        )

    phone = normalize_phone(row.get("telephone"))
    if not phone:
        report.warnings.append(
            ImportIssue(
                row=row_number,
                field="telephone",
                message="Telephone manquant.",
            )
        )

    joined_at = parse_date(row.get("date_adhesion"), report, row_number)
    if len(report.errors) > error_count_before:
        return None

    return MemberRow(
        row_number=row_number,
        first_name=first_name,
        last_name=last_name,
        email=email,
        phone=phone,
        gender=normalize_gender(row.get("genre")),
        roles=roles,
        status=status_value,
        core_pole=core_pole,
        support_poles=split_values(row.get("poles_support")),
        project=normalize_text(row.get("projet")) or None,
        responsibility=responsibility,
        joined_at=joined_at,
        study_level=normalize_text(row.get("niveau_etude")) or None,
    )


def load_csv_text(content: str, report: ImportReport) -> list[MemberRow]:
    with io.StringIO(content, newline="") as handle:
        reader = csv.DictReader(handle)
        headers = set(reader.fieldnames or [])
        missing = REQUIRED_COLUMNS - headers
        unknown = headers - ALL_COLUMNS
        if missing:
            report.errors.append(
                ImportIssue(
                    row=None,
                    field=None,
                    message=f"Colonnes obligatoires manquantes: {sorted(missing)}",
                )
            )
            return []
        if unknown:
            report.warnings.append(
                ImportIssue(
                    row=None,
                    field=None,
                    message=f"Colonnes ignorees: {sorted(unknown)}",
                )
            )

        rows = []
        seen_emails: set[str] = set()
        seen_phones: set[str] = set()
        for row_number, row in enumerate(reader, start=2):
            report.rows += 1
            member = parse_member_row(row, row_number, report)
            if member is None:
                continue
            if member.email in seen_emails:
                report.duplicates += 1
                report.errors.append(
                    ImportIssue(
                        row=row_number,
                        field="email",
                        message="Email duplique dans le CSV.",
                    )
                )
                continue
            seen_emails.add(member.email)
            if member.phone:
                if member.phone in seen_phones:
                    report.duplicates += 1
                    report.errors.append(
                        ImportIssue(
                            row=row_number,
                            field="telephone",
                            message="Telephone duplique dans le CSV.",
                        )
                    )
                    continue
                seen_phones.add(member.phone)
            rows.append(member)

    return rows


def load_csv(path: Path, report: ImportReport) -> list[MemberRow]:
    if not path.exists():
        report.errors.append(
            ImportIssue(row=None, field=None, message=f"Fichier introuvable: {path}")
        )
        return []

    return load_csv_text(path.read_text(encoding="utf-8-sig"), report)


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
            report.errors.append(
                ImportIssue(
                    row=row_number,
                    field="role",
                    message=f"Role inconnu '{role_name}'.",
                )
            )
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
            ImportIssue(
                row=member.row_number,
                field="telephone",
                message="Telephone deja utilise par un autre compte.",
            )
        )
        return None

    profile_type = "alumni" if member.status == "alumni" or "alumni" in member.roles else "enacteur"

    if existing:
        if not update_existing:
            report.warnings.append(
                ImportIssue(
                    row=member.row_number,
                    field="email",
                    message="Utilisateur existant ignore.",
                )
            )
            return existing
        existing.first_name = member.first_name
        existing.last_name = member.last_name
        existing.phone = member.phone
        existing.gender = member.gender
        existing.profile_type = profile_type
        existing.status = member.status
        existing.department = existing.department or member.core_pole
        existing.study_level = member.study_level or existing.study_level
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
        study_level=member.study_level,
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
        report.preview.append(member.preview_item())
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
                ImportIssue(
                    row=member.row_number,
                    field="pole_coeur",
                    message=f"Pole coeur inconnu '{member.core_pole}'.",
                )
            )
        if core_pole:
            link_pole(db, user, core_pole, member.responsibility, member.joined_at, report)

        for support_pole_name in member.support_poles:
            support_pole = find_pole(db, support_pole_name)
            if not support_pole:
                report.errors.append(
                    ImportIssue(
                        row=member.row_number,
                        field="poles_support",
                        message=f"Pole support inconnu '{support_pole_name}'.",
                    )
                )
                continue
            link_pole(db, user, support_pole, "support", member.joined_at, report)

        project = find_project(db, member.project)
        if member.project and not project:
            report.errors.append(
                ImportIssue(
                    row=member.row_number,
                    field="projet",
                    message=f"Projet inconnu '{member.project}'.",
                )
            )
        if project:
            link_project(db, user, project, member.responsibility, member.joined_at, report)


def run_members_import(
    db: Session,
    csv_content: str,
    *,
    dry_run: bool,
    update_existing: bool = False,
) -> ImportReport:
    report = ImportReport()
    rows = load_csv_text(csv_content, report)
    if report.has_errors:
        return report

    import_members(
        db,
        rows,
        report,
        update_existing=update_existing,
    )
    if report.has_errors or dry_run:
        db.rollback()
    else:
        db.commit()
    return report


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
            print(f"- {warning.as_text()}")
    if report.errors:
        print("\nErrors:")
        for error in report.errors:
            print(f"- {error.as_text()}")


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
        import_members(db, rows, report, update_existing=args.update_existing)
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
