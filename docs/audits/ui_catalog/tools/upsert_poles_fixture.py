"""Fiabilise les fixtures Pôles de l'audit UI PostgreSQL isolé.

Le script est déterministe et idempotent. Il ne contacte aucun service
externe, ne supprime aucune donnée et refuse toute exécution hors ui_audit.
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
from app.models.document import Document
from app.models.event import Event
from app.models.pole import Pole, PoleMember
from app.models.post import Post
from app.models.project import ProjectPole
from app.models.role import Role, UserRole
from app.models.task import Task, TaskAssignee
from app.models.user import User


NAMESPACE = uuid.UUID("926a86f6-0a6c-4bb8-a96f-53b7879023e6")
FIXTURE_NOW = datetime(2026, 8, 27, 12, 0, 0)
FUTURE_TASK_DUE = datetime(2027, 4, 15, 17, 0, 0)
FUTURE_EVENT_START = datetime(2027, 4, 20, 10, 0, 0)
FUTURE_EVENT_END = datetime(2027, 4, 20, 12, 0, 0)

TECHNIQUE_NAME = "Technique"
EMPTY_POLE_NAME = "Audit Pôle Sans Équipe"
FUTURE_TASK_REFERENCE = "AUDIT-POLE-NEXT-ACTION-001"
FUTURE_EVENT_REFERENCE = "AUDIT-POLE-EVENT-FUTURE-001"

LEAD_EMAIL = "audit.polelead@example.test"
DEPUTY_EMAIL = "audit.poledeputy@example.test"
ASSIGNEE_EMAIL = "audit.member@example.test"
INACTIVE_MEMBER_EMAIL = "audit.active01@example.test"
ADMIN_EMAIL = "audit.admin@example.test"

CANONICAL_POSITIONS = {"membre", "chef_pole", "adjoint_chef_pole"}
CANONICAL_TASK_STATUSES = {
    "a_faire",
    "en_cours",
    "bloque",
    "termine",
    "valide",
    "annule",
}
CANONICAL_PRIORITIES = {"basse", "normale", "haute", "urgente"}
TERMINAL_TASK_STATUSES = {"termine", "valide", "annule"}


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


def get_active_user(db, email: str) -> User:
    user = db.query(User).filter(User.email == email).one_or_none()
    if user is None:
        raise RuntimeError(f"Utilisateur synthétique requis introuvable : {email}")
    if user.status != "active" or not user.is_active:
        raise RuntimeError(f"Utilisateur synthétique non actif : {email}")
    return user


def set_fields(instance, expected: dict) -> bool:
    changed = False
    for field, value in expected.items():
        if getattr(instance, field) != value:
            setattr(instance, field, value)
            changed = True
    return changed


def ensure_unique_fixture(db, model, *, fixture_id, field, value):
    by_id = db.query(model).filter(model.id == fixture_id).one_or_none()
    by_value = db.query(model).filter(field == value).all()
    conflicting = [item for item in by_value if item.id != fixture_id]
    if conflicting:
        raise RuntimeError(
            f"ABORT : fixture en doublon pour {value!r}, UUID déterministe attendu."
        )
    return by_id


def has_role(db, user: User, role_name: str) -> bool:
    return (
        db.query(UserRole.id)
        .join(Role, Role.id == UserRole.role_id)
        .filter(UserRole.user_id == user.id, Role.name == role_name)
        .first()
        is not None
    )


def main() -> None:
    guards = require_isolated_database()
    db = SessionLocal()
    counters = {
        "created": {
            "poles": 0,
            "memberships": 0,
            "tasks": 0,
            "task_assignees": 0,
            "events": 0,
        },
        "updated": {
            "poles": 0,
            "memberships": 0,
            "tasks": 0,
            "events": 0,
        },
    }

    try:
        poles_before = db.query(Pole).count()
        project_poles_before = db.query(ProjectPole).count()

        technique = (
            db.query(Pole).filter(Pole.name == TECHNIQUE_NAME).one_or_none()
        )
        if technique is None:
            raise RuntimeError("Pôle synthétique Technique introuvable.")

        lead = get_active_user(db, LEAD_EMAIL)
        deputy = get_active_user(db, DEPUTY_EMAIL)
        assignee = get_active_user(db, ASSIGNEE_EMAIL)
        inactive_user = get_active_user(db, INACTIVE_MEMBER_EMAIL)
        admin = get_active_user(db, ADMIN_EMAIL)

        expected_legacy = {
            lead.id: ("chef", "chef_pole"),
            deputy.id: ("adjoint", "adjoint_chef_pole"),
        }
        normalized = []
        for user_id, (legacy, canonical) in expected_legacy.items():
            membership = (
                db.query(PoleMember)
                .filter(
                    PoleMember.pole_id == technique.id,
                    PoleMember.user_id == user_id,
                )
                .one_or_none()
            )
            if membership is None:
                raise RuntimeError(
                    "Membership de gouvernance Technique requise introuvable."
                )
            if membership.position == legacy:
                membership.position = canonical
                counters["updated"]["memberships"] += 1
                normalized.append(
                    {
                        "membership_id": str(membership.id),
                        "user_id": str(user_id),
                        "before": legacy,
                        "after": canonical,
                    }
                )
            elif membership.position != canonical:
                raise RuntimeError(
                    f"Position inattendue sur Technique : {membership.position!r}."
                )
            if not membership.is_active or membership.left_at is not None:
                raise RuntimeError("Responsable Technique attendu actif.")

        # SessionLocal désactive autoflush : matérialiser les normalisations
        # avant de vérifier qu'aucune valeur legacy ne subsiste.
        db.flush()
        foreign_legacy = (
            db.query(PoleMember)
            .filter(PoleMember.position.in_({"chef", "adjoint"}))
            .all()
        )
        if foreign_legacy:
            raise RuntimeError(
                "ABORT : positions legacy hors cibles Technique détectées : "
                + json.dumps([str(item.id) for item in foreign_legacy])
            )

        if not has_role(db, lead, "chef_pole"):
            raise RuntimeError("Le compte chef Technique ne porte pas chef_pole.")
        if not has_role(db, deputy, "adjoint_chef_pole"):
            raise RuntimeError("Le compte adjoint Technique ne porte pas adjoint_chef_pole.")

        empty_pole_id = uid("poles-fixture:empty-pole")
        empty_pole = ensure_unique_fixture(
            db,
            Pole,
            fixture_id=empty_pole_id,
            field=Pole.name,
            value=EMPTY_POLE_NAME,
        )
        empty_expected = {
            "season_id": technique.season_id,
            "name": EMPTY_POLE_NAME,
            "short_name": "Audit vide",
            "type": "support",
            "description": None,
            "objectives": None,
            "created_at": FIXTURE_NOW,
            "updated_at": FIXTURE_NOW,
        }
        if empty_pole is None:
            empty_pole = Pole(id=empty_pole_id, **empty_expected)
            db.add(empty_pole)
            counters["created"]["poles"] += 1
        elif set_fields(empty_pole, empty_expected):
            counters["updated"]["poles"] += 1
        db.flush()

        empty_active_members = (
            db.query(PoleMember)
            .filter(
                PoleMember.pole_id == empty_pole.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
            )
            .count()
        )
        if empty_active_members != 0:
            raise RuntimeError("ABORT : le pôle sans équipe a un membre actif.")

        inactive_membership_id = uid("poles-fixture:inactive-membership")
        inactive_membership = (
            db.query(PoleMember)
            .filter(
                PoleMember.pole_id == technique.id,
                PoleMember.user_id == inactive_user.id,
            )
            .one_or_none()
        )
        inactive_expected = {
            "position": "membre",
            "joined_at": date(2026, 5, 1),
            "left_at": date(2026, 7, 1),
            "is_active": False,
        }
        if inactive_membership is None:
            inactive_membership = PoleMember(
                id=inactive_membership_id,
                pole_id=technique.id,
                user_id=inactive_user.id,
                **inactive_expected,
            )
            db.add(inactive_membership)
            counters["created"]["memberships"] += 1
        else:
            if inactive_membership.id != inactive_membership_id:
                raise RuntimeError(
                    "ABORT : le couple de membership inactive existe avec un UUID inattendu."
                )
            if set_fields(inactive_membership, inactive_expected):
                counters["updated"]["memberships"] += 1

        future_task_id = uid("poles-fixture:future-task")
        future_task = ensure_unique_fixture(
            db,
            Task,
            fixture_id=future_task_id,
            field=Task.title,
            value=FUTURE_TASK_REFERENCE,
        )
        future_task_expected = {
            "title": FUTURE_TASK_REFERENCE,
            "description": "Prochaine action synthétique du pôle Technique.",
            "creator_id": admin.id,
            "assigned_by": admin.id,
            "pole_id": technique.id,
            "project_id": None,
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

        future_assignee_id = uid("poles-fixture:future-task-assignee")
        future_assignee = (
            db.query(TaskAssignee)
            .filter(
                TaskAssignee.task_id == future_task.id,
                TaskAssignee.user_id == assignee.id,
            )
            .one_or_none()
        )
        if future_assignee is None:
            future_assignee = TaskAssignee(
                id=future_assignee_id,
                task_id=future_task.id,
                user_id=assignee.id,
                assigned_at=FIXTURE_NOW,
            )
            db.add(future_assignee)
            counters["created"]["task_assignees"] += 1
        elif future_assignee.id != future_assignee_id:
            raise RuntimeError("ABORT : assignation future dupliquée ou non déterministe.")

        assignee_membership = (
            db.query(PoleMember)
            .filter(
                PoleMember.pole_id == technique.id,
                PoleMember.user_id == assignee.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
            )
            .one_or_none()
        )
        if assignee_membership is None:
            raise RuntimeError("L'assigné de la tâche future n'est pas membre de Technique.")

        future_event_id = uid("poles-fixture:future-event")
        future_event = ensure_unique_fixture(
            db,
            Event,
            fixture_id=future_event_id,
            field=Event.title,
            value=FUTURE_EVENT_REFERENCE,
        )
        future_event_expected = {
            "season_id": technique.season_id,
            "title": FUTURE_EVENT_REFERENCE,
            "description": "Événement synthétique futur du pôle Technique.",
            "event_type": "atelier",
            "location": "Salle Audit Pôle A1",
            "start_time": FUTURE_EVENT_START,
            "end_time": FUTURE_EVENT_END,
            "created_by": admin.id,
            "pole_id": technique.id,
            "project_id": None,
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

        db.flush()

        technique_leads = (
            db.query(PoleMember)
            .filter(
                PoleMember.pole_id == technique.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position == "chef_pole",
            )
            .all()
        )
        technique_deputies = (
            db.query(PoleMember)
            .filter(
                PoleMember.pole_id == technique.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position == "adjoint_chef_pole",
            )
            .all()
        )
        technique_ordinary = (
            db.query(PoleMember)
            .filter(
                PoleMember.pole_id == technique.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position == "membre",
            )
            .count()
        )
        if len(technique_leads) != 1 or len(technique_deputies) != 1:
            raise RuntimeError("ABORT : gouvernance Technique non unique.")
        if technique_ordinary < 1:
            raise RuntimeError("ABORT : Technique doit conserver des membres ordinaires.")

        invalid_positions = sorted(
            {
                membership.position
                for membership in db.query(PoleMember).all()
                if membership.position not in CANONICAL_POSITIONS
            }
        )
        if invalid_positions:
            raise RuntimeError(
                "ABORT : positions Pôles non canoniques restantes : "
                + json.dumps(invalid_positions, ensure_ascii=False)
            )

        invalid_task_statuses = sorted(
            {
                task.status
                for task in db.query(Task).filter(Task.pole_id.isnot(None)).all()
                if task.status not in CANONICAL_TASK_STATUSES
            }
        )
        invalid_priorities = sorted(
            {
                task.priority
                for task in db.query(Task).filter(Task.pole_id.isnot(None)).all()
                if task.priority not in CANONICAL_PRIORITIES
            }
        )
        if invalid_task_statuses or invalid_priorities:
            raise RuntimeError(
                "ABORT : tâches de pôle non canoniques : "
                + json.dumps(
                    {
                        "statuses": invalid_task_statuses,
                        "priorities": invalid_priorities,
                    },
                    ensure_ascii=False,
                    sort_keys=True,
                )
            )

        blocked_task = (
            db.query(Task)
            .filter(Task.pole_id.isnot(None), Task.status == "bloque")
            .order_by(Task.due_date.asc())
            .first()
        )
        overdue_task = (
            db.query(Task)
            .filter(
                Task.pole_id.isnot(None),
                Task.due_date < FIXTURE_NOW,
                Task.status.notin_(TERMINAL_TASK_STATUSES),
            )
            .order_by(Task.due_date.asc())
            .first()
        )
        if blocked_task is None:
            raise RuntimeError("ABORT : aucune tâche bloque canonique de pôle.")
        if overdue_task is None:
            raise RuntimeError("ABORT : aucune tâche de pôle en retard.")

        document = (
            db.query(Document)
            .filter(Document.pole_id.isnot(None))
            .order_by(Document.created_at.asc())
            .first()
        )
        activity = (
            db.query(Post)
            .filter(Post.pole_id.isnot(None))
            .order_by(Post.created_at.asc())
            .first()
        )
        if document is None:
            raise RuntimeError("ABORT : aucun document de pôle disponible.")
        if activity is None:
            raise RuntimeError("ABORT : aucune publication de pôle disponible.")

        duplicate_checks = {
            "empty_pole": db.query(Pole).filter(Pole.name == EMPTY_POLE_NAME).count(),
            "future_task": db.query(Task)
            .filter(Task.title == FUTURE_TASK_REFERENCE)
            .count(),
            "future_event": db.query(Event)
            .filter(Event.title == FUTURE_EVENT_REFERENCE)
            .count(),
            "inactive_membership": db.query(PoleMember)
            .filter(
                PoleMember.pole_id == technique.id,
                PoleMember.user_id == inactive_user.id,
            )
            .count(),
        }
        if any(value != 1 for value in duplicate_checks.values()):
            raise RuntimeError(
                "ABORT : doublon de fixture détecté : "
                + json.dumps(duplicate_checks, sort_keys=True)
            )

        if db.query(ProjectPole).count() != project_poles_before:
            raise RuntimeError("ABORT : les liens project_poles ont changé.")

        db.commit()

        poles_after = db.query(Pole).count()
        created_total = sum(counters["created"].values())
        updated_total = sum(counters["updated"].values())
        result = {
            "environment": guards["APP_ENV"],
            "database": {
                "host": guards["DB_HOST"],
                "name": guards["DB_NAME"],
                "file_storage_path": guards["FILE_STORAGE_PATH"],
            },
            "guards_verified": True,
            "created": {**counters["created"], "total": created_total},
            "updated": {**counters["updated"], "total": updated_total},
            "duplicate_rows": sum(value - 1 for value in duplicate_checks.values()),
            "duplicates": duplicate_checks,
            "poles_before": poles_before,
            "poles_after": poles_after,
            "positions_normalized": normalized,
            "legacy_positions_present": False,
            "technique": {
                "id": str(technique.id),
                "lead_membership_id": str(technique_leads[0].id),
                "lead_user_id": str(technique_leads[0].user_id),
                "lead_position": technique_leads[0].position,
                "deputy_membership_id": str(technique_deputies[0].id),
                "deputy_user_id": str(technique_deputies[0].user_id),
                "deputy_position": technique_deputies[0].position,
                "ordinary_active_members": technique_ordinary,
                "lead_can_satisfy_pole_manager": True,
                "deputy_can_satisfy_pole_manager": True,
            },
            "empty_pole": {
                "id": str(empty_pole.id),
                "name": empty_pole.name,
                "type": empty_pole.type,
                "description": empty_pole.description,
                "objectives": empty_pole.objectives,
                "active_memberships": empty_active_members,
                "project_links": db.query(ProjectPole)
                .filter(ProjectPole.pole_id == empty_pole.id)
                .count(),
            },
            "inactive_membership": {
                "id": str(inactive_membership.id),
                "pole_id": str(inactive_membership.pole_id),
                "user_id": str(inactive_membership.user_id),
                "position": inactive_membership.position,
                "is_active": inactive_membership.is_active,
                "left_at": inactive_membership.left_at.isoformat(),
                "reactivable_by_post_contract": True,
            },
            "future_task": {
                "id": str(future_task.id),
                "reference": future_task.title,
                "pole_id": str(future_task.pole_id),
                "project_id": future_task.project_id,
                "status": future_task.status,
                "priority": future_task.priority,
                "due_date": future_task.due_date.isoformat(),
                "assignee_id": str(future_assignee.user_id),
            },
            "canonical_blockage": {
                "id": str(blocked_task.id),
                "pole_id": str(blocked_task.pole_id),
                "status": blocked_task.status,
                "due_date": blocked_task.due_date.isoformat()
                if blocked_task.due_date
                else None,
            },
            "overdue_task": {
                "id": str(overdue_task.id),
                "pole_id": str(overdue_task.pole_id),
                "status": overdue_task.status,
                "due_date": overdue_task.due_date.isoformat(),
            },
            "future_event": {
                "id": str(future_event.id),
                "reference": future_event.title,
                "pole_id": str(future_event.pole_id),
                "project_id": future_event.project_id,
                "start_time": future_event.start_time.isoformat(),
                "end_time": future_event.end_time.isoformat(),
            },
            "document": {
                "id": str(document.id),
                "pole_id": str(document.pole_id),
                "status": document.status,
                "visibility": document.visibility,
            },
            "activity": {
                "id": str(activity.id),
                "pole_id": str(activity.pole_id),
                "visibility": activity.visibility,
            },
            "project_poles_unchanged": True,
        }
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
