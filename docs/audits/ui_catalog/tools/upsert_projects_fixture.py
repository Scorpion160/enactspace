"""Normalise et complète les fixtures Projets de l'audit UI isolé.

Le script est idempotent, sans accès réseau, sans suppression et sans reset de
schéma. Il refuse toute exécution hors de la base PostgreSQL locale ui_audit.
"""

from __future__ import annotations

import json
import os
import uuid
from datetime import date, datetime
from decimal import Decimal

import app.models.base  # noqa: F401  # importe tous les modèles avant requête
from sqlalchemy.engine import make_url

from app.db.database import SessionLocal
from app.models.event import Event
from app.models.project import Project, ProjectMember
from app.models.task import Task, TaskAssignee
from app.models.user import User


NAMESPACE = uuid.UUID("c7b11b65-6718-4d5d-a2db-a47224a6a729")
FIXTURE_NOW = datetime(2026, 8, 23, 12, 0, 0)
FUTURE_TASK_DUE = datetime(2027, 3, 15, 17, 0, 0)
BLOCKED_TASK_DUE = datetime(2026, 9, 15, 17, 0, 0)
FUTURE_EVENT_START = datetime(2027, 3, 20, 10, 0, 0)
FUTURE_EVENT_END = datetime(2027, 3, 20, 12, 0, 0)

PROJECT_WITHOUT_TEAM_NAME = "Audit Projet Sans Équipe"
FUTURE_TASK_REFERENCE = "AUDIT-PROJECT-NEXT-ACTION-001"
FUTURE_EVENT_REFERENCE = "AUDIT-PROJECT-EVENT-FUTURE-001"

PROJECT_STATUS_TARGETS = {
    "Audit Horizon": "idee",
    "Audit Rivage": "etude",
    "Audit Passage": "prototype",
    "Audit Mosaic": "test",
    "Audit Dense Budget": "deploiement",
    "Audit Solstice": "termine",
    "Audit Canopée": "suspendu",
    "Audit Sans Impact": "suspendu",
}

CANONICAL_PROJECT_STATUSES = {
    "idee",
    "etude",
    "prototype",
    "test",
    "deploiement",
    "termine",
    "suspendu",
}
CANONICAL_PROJECT_POSITIONS = {
    "membre",
    "chef_projet",
    "adjoint_chef_projet",
}
CANONICAL_TASK_STATUSES = {
    "a_faire",
    "en_cours",
    "bloque",
    "termine",
    "valide",
    "annule",
}
CANONICAL_PRIORITIES = {"basse", "normale", "haute", "urgente"}

LEAD_EMAIL = "audit.projectlead@example.test"
DEPUTY_EMAIL = "audit.active03@example.test"
ASSIGNEE_EMAIL = "audit.member@example.test"
ADMIN_EMAIL = "audit.admin@example.test"


def uid(key: str) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE, key)


def require_isolated_database() -> dict[str, str]:
    expected = {
        "APP_ENV": "ui_audit",
        "DB_HOST": "postgres",
        "DB_NAME": "enactspace_ui_audit",
        "FILE_STORAGE_PATH": "/audit/uploads",
    }
    actual = {name: os.environ.get(name, "") for name in expected}
    failures = {
        name: {"expected": value, "actual": actual[name]}
        for name, value in expected.items()
        if actual[name] != value
    }
    if failures:
        raise RuntimeError(
            "ABORT : gardes ui_audit invalides : "
            + json.dumps(failures, ensure_ascii=False, sort_keys=True)
        )

    url = make_url(os.environ.get("DATABASE_URL", ""))
    if url.drivername not in {"postgresql", "postgresql+psycopg"}:
        raise RuntimeError("ABORT : pilote PostgreSQL audit attendu.")
    if url.host != actual["DB_HOST"] or url.database != actual["DB_NAME"]:
        raise RuntimeError(
            "ABORT : DATABASE_URL ne correspond pas aux gardes DB_HOST/DB_NAME."
        )
    return actual


def get_one_user(db, email: str) -> User:
    user = db.query(User).filter(User.email == email).one_or_none()
    if user is None:
        raise RuntimeError(f"Utilisateur synthétique requis introuvable : {email}")
    if user.status != "active" or not user.is_active:
        raise RuntimeError(f"Utilisateur synthétique non actif : {email}")
    return user


def get_project(db, name: str) -> Project:
    project = db.query(Project).filter(Project.name == name).one_or_none()
    if project is None:
        raise RuntimeError(f"Projet synthétique requis introuvable : {name}")
    return project


def set_fields(instance, expected: dict) -> bool:
    changed = False
    for field, value in expected.items():
        if getattr(instance, field) != value:
            setattr(instance, field, value)
            changed = True
    return changed


def ensure_membership(
    db,
    *,
    project: Project,
    user: User,
    position: str,
    key: str,
    counters: dict,
) -> ProjectMember:
    membership = (
        db.query(ProjectMember)
        .filter(
            ProjectMember.project_id == project.id,
            ProjectMember.user_id == user.id,
        )
        .one_or_none()
    )
    expected = {
        "position": position,
        "joined_at": date(2026, 6, 1),
        "left_at": None,
        "is_active": True,
    }
    if membership is None:
        membership = ProjectMember(
            id=uid(key),
            project_id=project.id,
            user_id=user.id,
            **expected,
        )
        db.add(membership)
        counters["created"]["memberships"] += 1
    elif set_fields(membership, expected):
        counters["updated"]["memberships"] += 1
    return membership


def ensure_task_assignee(
    db,
    *,
    task: Task,
    user: User,
    key: str,
    counters: dict,
) -> TaskAssignee:
    assignee = (
        db.query(TaskAssignee)
        .filter(TaskAssignee.task_id == task.id, TaskAssignee.user_id == user.id)
        .one_or_none()
    )
    if assignee is None:
        assignee = TaskAssignee(
            id=uid(key),
            task_id=task.id,
            user_id=user.id,
            assigned_at=FIXTURE_NOW,
        )
        db.add(assignee)
        counters["created"]["task_assignees"] += 1
    return assignee


def duplicate_count(db, model, field, value) -> int:
    return db.query(model).filter(field == value).count()


def main() -> None:
    guards = require_isolated_database()
    db = SessionLocal()
    counters = {
        "created": {
            "projects": 0,
            "memberships": 0,
            "tasks": 0,
            "task_assignees": 0,
            "events": 0,
        },
        "updated": {
            "projects": 0,
            "memberships": 0,
            "tasks": 0,
            "events": 0,
        },
    }

    try:
        admin = get_one_user(db, ADMIN_EMAIL)
        lead = get_one_user(db, LEAD_EMAIL)
        deputy = get_one_user(db, DEPUTY_EMAIL)
        assignee_user = get_one_user(db, ASSIGNEE_EMAIL)

        projects = {
            name: get_project(db, name) for name in PROJECT_STATUS_TARGETS
        }
        statuses_before = {
            name: project.status for name, project in projects.items()
        }
        project_changes = []
        for name, target_status in PROJECT_STATUS_TARGETS.items():
            project = projects[name]
            expected_end = (
                project.ended_at or date(2026, 6, 5)
                if target_status == "termine"
                else None
            )
            changed = set_fields(
                project,
                {
                    "status": target_status,
                    "ended_at": expected_end,
                },
            )
            if changed:
                project.updated_at = FIXTURE_NOW
                counters["updated"]["projects"] += 1
                project_changes.append(
                    {
                        "name": name,
                        "before": statuses_before[name],
                        "after": target_status,
                    }
                )

        legacy_memberships = (
            db.query(ProjectMember)
            .join(Project, Project.id == ProjectMember.project_id)
            .filter(
                Project.name.in_(list(PROJECT_STATUS_TARGETS)),
                ProjectMember.position == "chef",
            )
            .all()
        )
        normalized_memberships = []
        for membership in legacy_memberships:
            membership.position = "chef_projet"
            counters["updated"]["memberships"] += 1
            normalized_memberships.append(str(membership.id))

        horizon = projects["Audit Horizon"]
        lead_membership = ensure_membership(
            db,
            project=horizon,
            user=lead,
            position="chef_projet",
            key="projects-fixture:horizon:lead",
            counters=counters,
        )
        deputy_membership = ensure_membership(
            db,
            project=horizon,
            user=deputy,
            position="adjoint_chef_projet",
            key="projects-fixture:horizon:deputy",
            counters=counters,
        )

        # Garantit un titulaire déterministe par responsabilité sur Horizon.
        other_leaders = (
            db.query(ProjectMember)
            .filter(
                ProjectMember.project_id == horizon.id,
                ProjectMember.is_active.is_(True),
                ProjectMember.position.in_(
                    {"chef_projet", "adjoint_chef_projet"}
                ),
                ProjectMember.id.notin_({lead_membership.id, deputy_membership.id}),
            )
            .all()
        )
        for membership in other_leaders:
            membership.position = "membre"
            counters["updated"]["memberships"] += 1

        # Normalise uniquement les tâches rattachées aux projets synthétiques.
        audit_tasks = (
            db.query(Task)
            .join(Project, Project.id == Task.project_id)
            .filter(Project.name.in_(list(PROJECT_STATUS_TARGETS)))
            .all()
        )
        task_legacy_counts = {
            "terminee": sum(task.status == "terminee" for task in audit_tasks),
            "bloquee": sum(task.status == "bloquee" for task in audit_tasks),
        }
        for task in audit_tasks:
            target = {"terminee": "termine", "bloquee": "bloque"}.get(
                task.status
            )
            if target is not None:
                task.status = target
                task.updated_at = FIXTURE_NOW
                counters["updated"]["tasks"] += 1

        solstice = projects["Audit Solstice"]
        solstice_tasks = (
            db.query(Task)
            .filter(Task.project_id == solstice.id)
            .order_by(Task.id.asc())
            .all()
        )
        for index, task in enumerate(solstice_tasks):
            target_status = "termine" if index % 2 == 0 else "valide"
            expected = {
                "status": target_status,
                "completed_at": FIXTURE_NOW,
                "validated_at": FIXTURE_NOW if target_status == "valide" else None,
                "validated_by": admin.id if target_status == "valide" else None,
            }
            if set_fields(task, expected):
                task.updated_at = FIXTURE_NOW
                counters["updated"]["tasks"] += 1

        canopee = projects["Audit Canopée"]
        blocked_task = (
            db.query(Task)
            .filter(Task.project_id == canopee.id)
            .order_by(Task.id.asc())
            .first()
        )
        if blocked_task is None:
            raise RuntimeError("Aucune tâche synthétique disponible pour Audit Canopée.")
        if set_fields(
            blocked_task,
            {
                "status": "bloque",
                "priority": "urgente",
                "due_date": BLOCKED_TASK_DUE,
                "completed_at": None,
                "validated_at": None,
                "validated_by": None,
            },
        ):
            blocked_task.updated_at = FIXTURE_NOW
            counters["updated"]["tasks"] += 1
        blocked_assignee = ensure_task_assignee(
            db,
            task=blocked_task,
            user=assignee_user,
            key="projects-fixture:blocked-task:assignee",
            counters=counters,
        )

        project_without_team_id = uid("projects-fixture:project-without-team")
        project_without_team = (
            db.query(Project).filter(Project.id == project_without_team_id).one_or_none()
        )
        project_without_team_expected = {
            "season_id": horizon.season_id,
            "name": PROJECT_WITHOUT_TEAM_NAME,
            "description": "Projet synthétique sans équipe pour validation UI.",
            "problem_statement": "Vérifier la présentation d'un projet sans membre.",
            "solution": "État de lecture déterministe, sans affectation.",
            "objectives": "Tester l'état équipe vide sans retirer de membre existant.",
            "expected_impact": "Validation ergonomique uniquement.",
            "budget_estimated": Decimal("0"),
            "status": "idee",
            "started_at": None,
            "ended_at": None,
            "created_at": FIXTURE_NOW,
            "updated_at": FIXTURE_NOW,
        }
        if project_without_team is None:
            project_without_team = Project(
                id=project_without_team_id,
                **project_without_team_expected,
            )
            db.add(project_without_team)
            counters["created"]["projects"] += 1
        elif set_fields(project_without_team, project_without_team_expected):
            counters["updated"]["projects"] += 1
        db.flush()
        active_team_count = (
            db.query(ProjectMember)
            .filter(
                ProjectMember.project_id == project_without_team.id,
                ProjectMember.is_active.is_(True),
            )
            .count()
        )
        if active_team_count != 0:
            raise RuntimeError(
                "ABORT : le projet sans équipe possède déjà un membership actif."
            )

        future_task_id = uid("projects-fixture:future-task")
        future_task = db.query(Task).filter(Task.id == future_task_id).one_or_none()
        future_task_expected = {
            "title": FUTURE_TASK_REFERENCE,
            "description": "Prochaine action synthétique du projet Audit Horizon.",
            "creator_id": admin.id,
            "assigned_by": admin.id,
            "pole_id": None,
            "project_id": horizon.id,
            "priority": "haute",
            "status": "a_faire",
            "due_date": FUTURE_TASK_DUE,
            "completed_at": None,
            "validated_at": None,
            "validated_by": None,
            "proof_required": False,
            "proof_url": None,
            "is_late_alert_sent": False,
            "created_at": FIXTURE_NOW,
            "updated_at": FIXTURE_NOW,
        }
        if future_task is None:
            future_task = Task(id=future_task_id, **future_task_expected)
            db.add(future_task)
            counters["created"]["tasks"] += 1
        elif set_fields(future_task, future_task_expected):
            counters["updated"]["tasks"] += 1
        db.flush()
        future_assignee = ensure_task_assignee(
            db,
            task=future_task,
            user=lead,
            key="projects-fixture:future-task:assignee",
            counters=counters,
        )

        future_event_id = uid("projects-fixture:future-event")
        future_event = (
            db.query(Event).filter(Event.id == future_event_id).one_or_none()
        )
        future_event_expected = {
            "season_id": horizon.season_id,
            "title": FUTURE_EVENT_REFERENCE,
            "description": "Événement synthétique futur lié à Audit Horizon.",
            "event_type": "atelier",
            "location": "Salle Audit Projet A1",
            "start_time": FUTURE_EVENT_START,
            "end_time": FUTURE_EVENT_END,
            "created_by": admin.id,
            "pole_id": None,
            "project_id": horizon.id,
            "budget": Decimal("0"),
            "max_participants": 30,
            "requires_registration": False,
            "attendance_enabled": True,
            "report_url": None,
            "created_at": FIXTURE_NOW,
            "updated_at": FIXTURE_NOW,
        }
        if future_event is None:
            future_event = Event(id=future_event_id, **future_event_expected)
            db.add(future_event)
            counters["created"]["events"] += 1
        elif set_fields(future_event, future_event_expected):
            counters["updated"]["events"] += 1

        # Audit Sans Impact reste volontairement incomplet.
        sans_impact = projects["Audit Sans Impact"]
        if sans_impact.expected_impact is not None:
            sans_impact.expected_impact = None
            sans_impact.updated_at = FIXTURE_NOW
            counters["updated"]["projects"] += 1

        db.flush()

        duplicate_checks = {
            "project_without_team": duplicate_count(
                db, Project, Project.name, PROJECT_WITHOUT_TEAM_NAME
            ),
            "future_task": duplicate_count(
                db, Task, Task.title, FUTURE_TASK_REFERENCE
            ),
            "future_event": duplicate_count(
                db, Event, Event.title, FUTURE_EVENT_REFERENCE
            ),
        }
        if any(value != 1 for value in duplicate_checks.values()):
            raise RuntimeError(
                "ABORT : doublon de fixture détecté : "
                + json.dumps(duplicate_checks, sort_keys=True)
            )

        all_audit_projects = (
            db.query(Project)
            .filter(
                Project.name.in_(
                    [*PROJECT_STATUS_TARGETS.keys(), PROJECT_WITHOUT_TEAM_NAME]
                )
            )
            .all()
        )
        invalid_project_statuses = sorted(
            {
                project.status
                for project in all_audit_projects
                if project.status not in CANONICAL_PROJECT_STATUSES
            }
        )
        invalid_positions = sorted(
            {
                membership.position
                for membership in db.query(ProjectMember)
                .join(Project, Project.id == ProjectMember.project_id)
                .filter(Project.name.in_([*PROJECT_STATUS_TARGETS.keys(), PROJECT_WITHOUT_TEAM_NAME]))
                .all()
                if membership.position not in CANONICAL_PROJECT_POSITIONS
            }
        )
        invalid_task_statuses = sorted(
            {
                task.status
                for task in db.query(Task)
                .join(Project, Project.id == Task.project_id)
                .filter(Project.name.in_([*PROJECT_STATUS_TARGETS.keys(), PROJECT_WITHOUT_TEAM_NAME]))
                .all()
                if task.status not in CANONICAL_TASK_STATUSES
            }
        )
        invalid_priorities = sorted(
            {
                task.priority
                for task in db.query(Task)
                .join(Project, Project.id == Task.project_id)
                .filter(Project.name.in_([*PROJECT_STATUS_TARGETS.keys(), PROJECT_WITHOUT_TEAM_NAME]))
                .all()
                if task.priority not in CANONICAL_PRIORITIES
            }
        )
        if any(
            [
                invalid_project_statuses,
                invalid_positions,
                invalid_task_statuses,
                invalid_priorities,
            ]
        ):
            raise RuntimeError(
                "ABORT : valeurs non canoniques restantes : "
                + json.dumps(
                    {
                        "project_statuses": invalid_project_statuses,
                        "positions": invalid_positions,
                        "task_statuses": invalid_task_statuses,
                        "priorities": invalid_priorities,
                    },
                    ensure_ascii=False,
                    sort_keys=True,
                )
            )

        db.commit()

        statuses_after = {
            name: get_project(db, name).status for name in PROJECT_STATUS_TARGETS
        }
        created_total = sum(counters["created"].values())
        updated_total = sum(counters["updated"].values())
        result = {
            "environment": guards["APP_ENV"],
            "database_host": guards["DB_HOST"],
            "database_name": guards["DB_NAME"],
            "file_storage_path": guards["FILE_STORAGE_PATH"],
            "created": {**counters["created"], "total": created_total},
            "updated": {**counters["updated"], "total": updated_total},
            "duplicates": duplicate_checks,
            "duplicate_rows": sum(value - 1 for value in duplicate_checks.values()),
            "project_statuses_before": statuses_before,
            "project_statuses_after": statuses_after,
            "projects_normalized": project_changes,
            "memberships_normalized": normalized_memberships,
            "legacy_tasks_found": task_legacy_counts,
            "solstice_task_statuses": {
                status: db.query(Task)
                .filter(Task.project_id == solstice.id, Task.status == status)
                .count()
                for status in ("termine", "valide", "bloque")
            },
            "project_without_team": {
                "id": str(project_without_team.id),
                "name": project_without_team.name,
                "status": project_without_team.status,
                "active_memberships": active_team_count,
            },
            "leadership": {
                "project_id": str(horizon.id),
                "project_name": horizon.name,
                "lead_membership_id": str(lead_membership.id),
                "lead_user_id": str(lead.id),
                "lead_position": lead_membership.position,
                "deputy_membership_id": str(deputy_membership.id),
                "deputy_user_id": str(deputy.id),
                "deputy_position": deputy_membership.position,
            },
            "blocked_task": {
                "id": str(blocked_task.id),
                "project_id": str(canopee.id),
                "project_name": canopee.name,
                "status": blocked_task.status,
                "priority": blocked_task.priority,
                "due_date": blocked_task.due_date.isoformat(),
                "assignee_id": str(blocked_assignee.user_id),
            },
            "future_task": {
                "id": str(future_task.id),
                "reference": future_task.title,
                "project_id": str(horizon.id),
                "status": future_task.status,
                "priority": future_task.priority,
                "due_date": future_task.due_date.isoformat(),
                "assignee_id": str(future_assignee.user_id),
            },
            "future_event": {
                "id": str(future_event.id),
                "reference": future_event.title,
                "project_id": str(horizon.id),
                "start_time": future_event.start_time.isoformat(),
                "end_time": future_event.end_time.isoformat(),
            },
            "audit_sans_impact_preserved": sans_impact.expected_impact is None,
        }
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
