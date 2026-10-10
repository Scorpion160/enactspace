from app.core.time import utc_now
from datetime import datetime, timedelta
from urllib.parse import urlsplit
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status, File, UploadFile
from sqlalchemy import and_, or_, inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.task import (
    Task,
    TaskAssignee,
    TaskChecklistItem,
    TaskComment,
)
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.schemas.task import (
    TaskCreate,
    TaskUpdate,
    TaskRead,
    TaskAssigneeCreate,
    TaskAssigneeRead,
    TaskChecklistItemCreate,
    TaskChecklistItemUpdate,
    TaskChecklistItemRead,
    TaskCommentCreate,
    TaskCommentRead,
    TaskProofSubmit,
    TaskStatusChange,
)
from app.api.deps import (
    get_current_active_validated_user,
    user_has_any_role,
)
from app.services.notification_service import notify_user, notify_users
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.operational_integrity import (
    assert_active_operational_member,
    lock_row,
    to_naive_utc,
)

router = APIRouter(prefix="/tasks", tags=["Tâches"])


VALID_TASK_STATUSES = {
    "a_faire",
    "en_cours",
    "bloque",
    "termine",
    "valide",
    "annule",
}
TASK_STATUS_TRANSITIONS = {
    "a_faire": {"en_cours", "bloque"},
    "en_cours": {"bloque", "termine"},
    "bloque": {"en_cours", "termine"},
    "termine": {"valide", "en_cours"},
    "valide": set(),
    "annule": set(),
}

VALID_TASK_PRIORITIES = {
    "basse",
    "normale",
    "haute",
    "urgente",
}

GLOBAL_TASK_MANAGER_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}
POLE_LEAD_POSITIONS = {"chef_pole", "adjoint_chef_pole"}
PROJECT_LEAD_POSITIONS = {"chef_projet", "adjoint_chef_projet"}


def get_task_or_404(db: Session, task_id: str) -> Task:
    try:
        task_id = UUID(str(task_id))
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    task = db.query(Task).filter(Task.id == task_id).first()

    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Tâche introuvable",
        )

    return task


def task_is_late(task: Task) -> bool:
    if not task.due_date:
        return False

    if task.status in {"termine", "valide", "annule"}:
        return False

    return utc_now() > task.due_date


def task_assignee_user_ids(db: Session, task: Task) -> list:
    return [
        row[0]
        for row in db.query(TaskAssignee.user_id)
        .filter(TaskAssignee.task_id == task.id)
        .all()
    ]


def notify_task_assignees(
    db: Session,
    task: Task,
    *,
    title: str,
    message: str,
    notification_type: str,
    actor_id=None,
    dedupe: bool = False,
) -> None:
    reviewer_id = task.assigned_by or task.creator_id
    if task.status == "termine" and reviewer_id and reviewer_id != actor_id:
        notify_users(
            db, user_ids=[reviewer_id],
            title="Travail remis · validation attendue",
            message=f"Le travail pour « {task.title} » est terminé. Consultez le justificatif et validez ou demandez une reprise.",
            notification_type="task_review_requested", related_type="task",
            related_id=task.id, dedupe=True,
        )
    user_ids = [
        user_id for user_id in task_assignee_user_ids(db, task) if user_id != actor_id
    ]
    if not user_ids:
        return
    notify_users(
        db,
        user_ids=user_ids,
        title=title,
        message=message,
        notification_type=notification_type,
        related_type="task",
        related_id=task.id,
        dedupe=dedupe,
    )


def notify_task_due_soon(db: Session, task: Task, *, actor_id=None) -> None:
    # Once configured, Veille owns scheduled alerts, including their pause switch.
    # Keep the legacy fallback only for databases that have not activated Veille.
    from app.models.veille import VeilleSettings
    if inspect(db.connection()).has_table("veille_settings") and db.get(VeilleSettings,1) is not None:
        return
    if not task.due_date or task.status in {"termine", "valide", "annule"}:
        return

    now = utc_now()
    if not now <= task.due_date <= now + timedelta(hours=48):
        return

    notify_task_assignees(
        db,
        task,
        title="Echeance proche",
        message=f"La tache {task.title} arrive bientot a echeance.",
        notification_type="task_due_soon",
        actor_id=actor_id,
        dedupe=True,
    )


def user_can_manage_task(db: Session, task: Task, user: User) -> bool:
    if user.status != "active" or not user.is_active:
        return False
    if user_has_any_role(db, user.id, GLOBAL_TASK_MANAGER_ROLES):
        return True
    if task.creator_id == user.id:
        return True
    if task.pole_id is not None:
        if (
            db.query(PoleMember.id)
            .filter(
                PoleMember.pole_id == task.pole_id,
                PoleMember.user_id == user.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position.in_(POLE_LEAD_POSITIONS),
            )
            .first()
        ):
            return True
    if task.project_id is not None:
        if (
            db.query(ProjectMember.id)
            .filter(
                ProjectMember.project_id == task.project_id,
                ProjectMember.user_id == user.id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
                ProjectMember.position.in_(PROJECT_LEAD_POSITIONS),
            )
            .first()
        ):
            return True
    return False


def user_is_assigned(db: Session, task: Task, user: User) -> bool:
    return (
        db.query(TaskAssignee.id)
        .filter(
            TaskAssignee.task_id == task.id,
            TaskAssignee.user_id == user.id,
        )
        .first()
        is not None
    )


def task_payload(db: Session, task: Task, user: User) -> dict:
    data = TaskRead.model_validate(task).model_dump()
    data["can_manage"] = user_can_manage_task(db, task, user)
    data["can_validate"] = data["can_manage"] and not user_is_assigned(db, task, user) and (user.id == (task.assigned_by or task.creator_id) or user_has_any_role(db, user.id, {"administrateur", "team_leader"}))
    data["current_user_assigned"] = user.status == "active" and user_is_assigned(db, task, user)
    from app.models.stored_file import StoredFile
    stored = db.query(StoredFile).filter(StoredFile.entity_type == "task", StoredFile.entity_id == task.id).all()
    attachment = next((f for f in stored if task.proof_url == f"/api/files/{f.id}/download"), None)
    data["proof_filename"] = attachment.original_filename if attachment else None
    return data


def ensure_task_manager(db: Session, task: Task, user: User) -> None:
    assert_active_operational_member(user)
    if not user_can_manage_task(db, task, user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Gestion réservée au responsable de ce périmètre",
        )


def ensure_task_actor(db: Session, task: Task, user: User) -> bool:
    assert_active_operational_member(user)
    is_manager = user_can_manage_task(db, task, user)
    is_assignee = user_is_assigned(db, task, user)

    if not is_manager and not is_assignee:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée aux responsables et aux membres assignés",
        )
    return is_manager


def ensure_task_viewer(db: Session, task: Task, user: User) -> None:
    if user_can_manage_task(db, task, user) or user_is_assigned(db, task, user) or task.creator_id == user.id:
        return
    from app.services.veille_service import VeilleAccess
    if not VeilleAccess(db, user).veille:
        raise HTTPException(403, "Cette tâche ne vous est pas accessible.")


def ensure_independent_reviewer(db: Session, task: Task, user: User) -> None:
    if user.id != (task.assigned_by or task.creator_id) and not user_has_any_role(db, user.id, {"administrateur", "team_leader"}):
        raise HTTPException(403, "La validation revient à la personne qui a confié la tâche ou à la direction en cas de relais.")
    if user_is_assigned(db, task, user):
        raise HTTPException(403, "Un autre responsable doit relire votre livrable.")


def ensure_task_work_editable(task: Task) -> None:
    if task.status in {"termine", "valide", "annule"}:
        raise HTTPException(409, "Le livrable est remis ou clôturé. Demandez une reprise avant de modifier ses étapes ou affectations.")


def apply_task_status(
    task: Task,
    next_status: str,
    *,
    is_manager: bool,
    actor_id,
) -> bool:
    if next_status not in VALID_TASK_STATUSES:
        raise HTTPException(status_code=400, detail="Statut invalide")
    if next_status == task.status:
        return False
    if task.status in {"valide", "annule"}:
        raise HTTPException(status_code=409, detail="Cette tâche est terminale")

    allowed = set(TASK_STATUS_TRANSITIONS.get(task.status, set()))
    if is_manager and task.status in {"a_faire", "en_cours", "bloque"}:
        allowed.add("annule")
    if not is_manager:
        allowed.discard("valide")
        allowed.discard("annule")
        if task.status == "termine":
            allowed.clear()
    if next_status not in allowed:
        raise HTTPException(
            status_code=409,
            detail=f"Transition de tâche interdite : {task.status} -> {next_status}",
        )
    if next_status == "termine" and task.proof_required and not task.proof_url:
        raise HTTPException(
            status_code=400,
            detail="Une preuve est requise avant de marquer cette tâche comme terminée",
        )

    previous = task.status
    task.status = next_status
    now = utc_now()
    if next_status == "termine":
        task.completed_at = now
        task.validated_at = None
        task.validated_by = None
    elif next_status == "valide":
        task.validated_at = now
        task.validated_by = actor_id
    elif next_status in {"a_faire", "en_cours", "bloque", "annule"}:
        task.completed_at = None
        task.validated_at = None
        task.validated_by = None
    if previous == "termine" and next_status == "en_cours":
        task.completed_at = None
    task.updated_at = now
    return True


def visible_tasks_query(db: Session, user: User):
    query = db.query(Task)
    if user.status != "active" or not user.is_active:
        own_tasks = db.query(TaskAssignee.task_id).filter(TaskAssignee.user_id == user.id)
        return query.filter(or_(Task.id.in_(own_tasks), Task.creator_id == user.id))
    from app.services.veille_service import VeilleAccess
    if user_has_any_role(db, user.id, GLOBAL_TASK_MANAGER_ROLES) or VeilleAccess(db, user).veille:
        return query

    assigned_task_ids = db.query(TaskAssignee.task_id).filter(
        TaskAssignee.user_id == user.id
    )
    pole_ids = db.query(PoleMember.pole_id).filter(
        PoleMember.user_id == user.id,
        PoleMember.is_active.is_(True),
        PoleMember.left_at.is_(None),
        PoleMember.position.in_(POLE_LEAD_POSITIONS),
    )
    project_ids = db.query(ProjectMember.project_id).filter(
        ProjectMember.user_id == user.id,
        ProjectMember.is_active.is_(True),
        ProjectMember.left_at.is_(None),
        ProjectMember.position.in_(PROJECT_LEAD_POSITIONS),
    )
    return query.filter(
        or_(
            Task.id.in_(assigned_task_ids),
            Task.creator_id == user.id,
            and_(Task.pole_id.isnot(None), Task.pole_id.in_(pole_ids)),
            and_(
                Task.project_id.isnot(None),
                Task.project_id.in_(project_ids),
            ),
        )
    )


def ensure_task_creation_scope(
    db: Session,
    user: User,
    payload: TaskCreate,
) -> None:
    assert_active_operational_member(user)
    if payload.pole_id is not None and payload.project_id is not None:
        raise HTTPException(400, "Choisissez un seul périmètre : pôle ou projet.")
    if user_has_any_role(db, user.id, GLOBAL_TASK_MANAGER_ROLES):
        return
    if payload.pole_id is not None:
        if (
            db.query(PoleMember.id)
            .filter(
                PoleMember.pole_id == payload.pole_id,
                PoleMember.user_id == user.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position.in_(POLE_LEAD_POSITIONS),
            )
            .first()
        ):
            return
    if payload.project_id is not None:
        if (
            db.query(ProjectMember.id)
            .filter(
                ProjectMember.project_id == payload.project_id,
                ProjectMember.user_id == user.id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
                ProjectMember.position.in_(PROJECT_LEAD_POSITIONS),
            )
            .first()
        ):
            return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Sélectionnez un pôle ou projet que vous dirigez",
    )


def ensure_assignees_in_scope(
    db: Session,
    user: User,
    pole_id,
    project_id,
    user_ids,
) -> None:
    if user_has_any_role(db, user.id, GLOBAL_TASK_MANAGER_ROLES):
        return
    requested_ids = set(user_ids)
    if not requested_ids:
        return
    if pole_id is not None:
        allowed_ids = {
            row[0]
            for row in db.query(PoleMember.user_id)
            .filter(
                PoleMember.pole_id == pole_id,
                PoleMember.user_id.in_(requested_ids),
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
            )
            .all()
        }
    elif project_id is not None:
        allowed_ids = {
            row[0]
            for row in db.query(ProjectMember.user_id)
            .filter(
                ProjectMember.project_id == project_id,
                ProjectMember.user_id.in_(requested_ids),
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
            )
            .all()
        }
    else:
        allowed_ids = set()
    if allowed_ids != requested_ids:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tous les assignés doivent appartenir au périmètre",
        )


@router.post("/", response_model=TaskRead)
def create_task(
    payload: TaskCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if len(payload.assignee_ids) != len(set(payload.assignee_ids)):
        raise HTTPException(status_code=409, detail="Un assigné est présent plusieurs fois")
    ensure_task_creation_scope(db, current_user, payload)
    ensure_assignees_in_scope(
        db,
        current_user,
        payload.pole_id,
        payload.project_id,
        payload.assignee_ids,
    )
    if payload.priority not in VALID_TASK_PRIORITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Priorité invalide",
        )

    task = Task(
        title=payload.title,
        description=payload.description,
        creator_id=current_user.id,
        assigned_by=current_user.id,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        priority=payload.priority,
        status="a_faire",
        due_date=to_naive_utc(payload.due_date),
        proof_required=payload.proof_required,
    )

    db.add(task)
    db.flush()

    target_users = db.query(User).filter(User.id.in_(set(payload.assignee_ids))).all()
    if len(target_users) != len(set(payload.assignee_ids)):
        raise HTTPException(status_code=404, detail="Un membre assigné est introuvable")
    for target_user in target_users:
        assert_active_operational_member(target_user)

    for user_id in payload.assignee_ids:
        assignee = TaskAssignee(
            task_id=task.id,
            user_id=user_id,
        )
        db.add(assignee)

    db.flush()
    notify_task_assignees(
        db,
        task,
        title="Nouvelle tache assignee",
        message=f"Une nouvelle tache vous a ete assignee : {task.title}.",
        notification_type="task_assigned",
        actor_id=current_user.id,
        dedupe=True,
    )
    notify_task_due_soon(db, task, actor_id=current_user.id)
    create_audit_log(
        db=db,
        action="creation_tache",
        user_id=current_user.id,
        entity_type="task",
        entity_id=task.id,
        new_value={"status": task.status, "assignee_count": len(set(payload.assignee_ids))},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(task)

    return task_payload(db, task, current_user)


@router.get("/", response_model=list[TaskRead])
def list_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    tasks = (
        visible_tasks_query(db, current_user)
        .order_by(Task.created_at.desc())
        .all()
    )
    return [task_payload(db, task, current_user) for task in tasks]


@router.get("/my", response_model=list[TaskRead])
def list_my_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task_ids = db.query(TaskAssignee.task_id).filter(
        TaskAssignee.user_id == current_user.id
    )

    tasks = (
        db.query(Task)
        .filter(Task.id.in_(task_ids))
        .order_by(Task.created_at.desc())
        .all()
    )
    return [task_payload(db, task, current_user) for task in tasks]


@router.get("/late", response_model=list[TaskRead])
def list_late_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    now = utc_now()

    tasks = (
        visible_tasks_query(db, current_user)
        .filter(
            Task.due_date.isnot(None),
            Task.due_date < now,
            Task.status.notin_(["termine", "valide", "annule"]),
        )
        .order_by(Task.due_date.asc())
        .all()
    )
    return [task_payload(db, task, current_user) for task in tasks]


@router.get("/project/{project_id}", response_model=list[TaskRead])
def list_project_tasks(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    tasks = (
        visible_tasks_query(db, current_user)
        .filter(Task.project_id == project_id)
        .order_by(Task.created_at.desc())
        .all()
    )
    return [task_payload(db, task, current_user) for task in tasks]


@router.get("/pole/{pole_id}", response_model=list[TaskRead])
def list_pole_tasks(
    pole_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    tasks = (
        visible_tasks_query(db, current_user)
        .filter(Task.pole_id == pole_id)
        .order_by(Task.created_at.desc())
        .all()
    )
    return [task_payload(db, task, current_user) for task in tasks]


@router.get("/{task_id}", response_model=TaskRead)
def get_task(
    task_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_viewer(db, task, current_user)
    return task_payload(db, task, current_user)


@router.patch("/{task_id}", response_model=TaskRead)
def update_task(
    task_id: UUID,
    payload: TaskUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    ensure_task_manager(db, task, current_user)
    old_status = task.status

    if payload.priority is not None:
        if payload.priority not in VALID_TASK_PRIORITIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Priorité invalide",
            )
        task.priority = payload.priority

    if payload.title is not None:
        task.title = payload.title

    if payload.description is not None:
        task.description = payload.description

    if payload.due_date is not None:
        due = to_naive_utc(payload.due_date)
        if due != task.due_date:
            ensure_task_work_editable(task)
            reason = (payload.deadline_change_reason or "").strip()
            if len(reason) < 6:
                raise HTTPException(400, "Expliquez le changement d’échéance.")
            from app.services.veille_service import event_log, json_value
            event_log(db, current_user, "task", task.id, "deadline_changed", reason,
                {"previous_due_date": json_value(task.due_date), "due_date": json_value(due)})
            task.due_date = due
            task.is_late_alert_sent = False

    if payload.proof_required is not None:
        if payload.proof_required != task.proof_required:
            ensure_task_work_editable(task)
        task.proof_required = payload.proof_required

    if payload.proof_url is not None and payload.proof_url != task.proof_url:
        if task.status in {"termine", "valide", "annule"}:
            raise HTTPException(status_code=409, detail="La preuve d’un livrable remis est immuable avant une demande de reprise.")
        validate_task_proof_reference(db, task, payload.proof_url)
        task.proof_url = payload.proof_url

    status_changed = False
    if payload.status is not None:
        if payload.status == "valide":
            ensure_independent_reviewer(db, task, current_user)
        status_changed = apply_task_status(
            task,
            payload.status,
            is_manager=True,
            actor_id=current_user.id,
        )

    task.updated_at = utc_now()

    if status_changed:
        notify_task_assignees(
            db,
            task,
            title="Statut de tache modifie",
            message=f"La tache {task.title} est maintenant {task.status}.",
            notification_type="task_updated",
            actor_id=current_user.id,
        )
    elif payload.status is None:
        notify_task_assignees(
            db,
            task,
            title="Tache mise a jour",
            message=f"La tache {task.title} a ete modifiee.",
            notification_type="task_updated",
            actor_id=current_user.id,
        )
    notify_task_due_soon(db, task, actor_id=current_user.id)

    create_audit_log(
        db=db,
        action="changement_statut_tache" if status_changed else "modification_tache",
        user_id=current_user.id,
        entity_type="task",
        entity_id=task.id,
        old_value={"status": old_status},
        new_value={"status": task.status},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(task)

    return task_payload(db, task, current_user)


@router.post("/{task_id}/status", response_model=TaskRead)
def change_task_status(
    task_id: UUID,
    payload: TaskStatusChange,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    is_manager = ensure_task_actor(db, task, current_user)
    old_status = task.status
    if payload.status == "valide":
        ensure_independent_reviewer(db, task, current_user)
    changed = apply_task_status(
        task,
        payload.status,
        is_manager=is_manager,
        actor_id=current_user.id,
    )

    if changed:
        notify_task_assignees(
            db,
            task,
            title="Statut de tache modifie",
            message=f"La tache {task.title} est maintenant {task.status}.",
            notification_type="task_updated",
            actor_id=current_user.id,
            dedupe=True,
        )
        create_audit_log(
            db=db,
            action="changement_statut_tache",
            user_id=current_user.id,
            entity_type="task",
            entity_id=task.id,
            old_value={"status": old_status},
            new_value={"status": task.status},
            ip_address=get_client_ip(request),
        )
    notify_task_due_soon(db, task, actor_id=current_user.id)

    db.commit()
    db.refresh(task)

    return task_payload(db, task, current_user)


def validate_task_proof_reference(db: Session, task: Task, value: str) -> None:
    """Keep historical web links, but prevent copying another dossier's private file."""
    from app.models.stored_file import StoredFile
    parsed = urlsplit(value)
    if parsed.path.startswith("/api/files/"):
        parts = parsed.path.strip("/").split("/")
        try:
            file_id = UUID(parts[2])
        except (ValueError, IndexError):
            raise HTTPException(400, "Pièce jointe invalide.")
        stored = db.get(StoredFile, file_id)
        if len(parts) != 4 or parts[3] != "download" or not stored or stored.entity_type != "task" or stored.entity_id != task.id:
            raise HTTPException(400, "Joignez le justificatif depuis cette tâche.")
    elif parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise HTTPException(400, "Justificatif invalide.")


@router.post("/{task_id}/proof", response_model=TaskRead)
def submit_task_proof(
    task_id: UUID,
    payload: TaskProofSubmit,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    ensure_task_actor(db, task, current_user)

    if task.status in {"termine", "valide", "annule"}:
        raise HTTPException(status_code=409, detail="La preuve d’un livrable remis est immuable avant une demande de reprise.")

    validate_task_proof_reference(db, task, payload.proof_url)
    task.proof_url = payload.proof_url
    task.updated_at = utc_now()
    create_audit_log(
        db=db,
        action="preuve_tache",
        user_id=current_user.id,
        entity_type="task",
        entity_id=task.id,
        new_value={"proof_present": True},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(task)

    return task_payload(db, task, current_user)


@router.post("/{task_id}/proof-file", response_model=TaskRead)
async def attach_task_proof(
    task_id: UUID, request: Request, file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(404, "Tâche introuvable")
    ensure_task_actor(db, task, current_user)
    if task.status in {"termine", "valide", "annule"}:
        raise HTTPException(409, "Un livrable remis ne peut plus être remplacé avant une demande de reprise.")
    from app.services.attachment_service import read_attachment
    from app.services.file_storage_service import store_bytes, delete_physical_file
    name, data = await read_attachment(file)
    stored = None
    try:
        stored = store_bytes(db, data=data, original_filename=name, uploaded_by=current_user,
            storage_scope="document", visibility="private", entity_type="task", entity_id=task.id,
            is_temporary=False)
        task.proof_url = f"/api/files/{stored.id}/download"
        task.updated_at = utc_now()
        create_audit_log(db, action="preuve_tache", user_id=current_user.id, entity_type="task",
            entity_id=task.id, new_value={"file_id": str(stored.id)}, ip_address=get_client_ip(request))
        db.commit()
    except Exception:
        db.rollback()
        if stored is not None:
            delete_physical_file(stored)
        raise
    db.refresh(task)
    return task_payload(db, task, current_user)


@router.post("/{task_id}/validate", response_model=TaskRead)
def validate_task(
    task_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    ensure_task_manager(db, task, current_user)
    old_status = task.status
    ensure_independent_reviewer(db, task, current_user)
    apply_task_status(task, "valide", is_manager=True, actor_id=current_user.id)

    notify_task_assignees(
        db,
        task,
        title="Tache validee",
        message=f"La tache {task.title} a ete validee.",
        notification_type="task_validated",
        actor_id=current_user.id,
        dedupe=True,
    )
    create_audit_log(
        db=db,
        action="validation_tache",
        user_id=current_user.id,
        entity_type="task",
        entity_id=task.id,
        old_value={"status": old_status},
        new_value={"status": task.status, "validated_by": str(current_user.id)},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(task)

    return task_payload(db, task, current_user)


@router.delete("/{task_id}")
def delete_task(
    task_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_manager(db, task, current_user)

    db.delete(task)
    db.commit()

    return {
        "ok": True,
        "message": "Tâche supprimée",
    }


@router.post("/assignees", response_model=list[TaskAssigneeRead])
def add_task_assignees(
    payload: TaskAssigneeCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, payload.task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    ensure_task_manager(db, task, current_user)
    ensure_task_work_editable(task)
    ensure_assignees_in_scope(
        db,
        current_user,
        task.pole_id,
        task.project_id,
        payload.user_ids,
    )

    created = []

    targets = db.query(User).filter(User.id.in_(set(payload.user_ids))).all()
    if len(targets) != len(set(payload.user_ids)):
        raise HTTPException(status_code=404, detail="Un membre assigné est introuvable")
    for target in targets:
        assert_active_operational_member(target)

    for user_id in payload.user_ids:
        existing = db.query(TaskAssignee).filter(
            TaskAssignee.task_id == task.id,
            TaskAssignee.user_id == user_id,
        ).first()

        if existing:
            raise HTTPException(status_code=409, detail="Ce membre est déjà assigné")

        assignee = TaskAssignee(
            task_id=task.id,
            user_id=user_id,
        )

        db.add(assignee)
        created.append(assignee)
        if user_id != current_user.id:
            notify_user(
                db,
                user_id=user_id,
                title="Nouvelle tache assignee",
                message=f"Une nouvelle tache vous a ete assignee : {task.title}.",
                notification_type="task_assigned",
                related_type="task",
                related_id=task.id,
                dedupe=True,
            )

    create_audit_log(
        db=db,
        action="affectation_tache",
        user_id=current_user.id,
        entity_type="task",
        entity_id=task.id,
        new_value={"user_ids": [str(value) for value in payload.user_ids]},
        ip_address=get_client_ip(request),
    )
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Assignation concurrente en conflit") from exc

    for assignee in created:
        db.refresh(assignee)

    return created


@router.get("/{task_id}/assignees", response_model=list[TaskAssigneeRead])
def list_task_assignees(
    task_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_viewer(db, task, current_user)

    return db.query(TaskAssignee).filter(
        TaskAssignee.task_id == task_id
    ).order_by(TaskAssignee.assigned_at.asc()).all()


@router.delete("/{task_id}/assignees/{user_id}")
def remove_task_assignee(
    task_id: UUID,
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(404, "Tâche introuvable")
    ensure_task_manager(db, task, current_user)
    ensure_task_work_editable(task)
    assignee = db.query(TaskAssignee).filter(
        TaskAssignee.task_id == task_id,
        TaskAssignee.user_id == user_id,
    ).first()

    if not assignee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Assignation introuvable",
        )

    db.delete(assignee)
    db.commit()

    return {
        "ok": True,
        "message": "Assignation supprimée",
    }


@router.post("/checklist", response_model=TaskChecklistItemRead)
def create_checklist_item(
    payload: TaskChecklistItemCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, payload.task_id)
    if task is None:
        raise HTTPException(404, "Tâche introuvable")
    ensure_task_manager(db, task, current_user)
    ensure_task_work_editable(task)

    item = TaskChecklistItem(
        task_id=payload.task_id,
        title=payload.title,
        is_done=False,
    )

    db.add(item)
    db.commit()
    db.refresh(item)

    return item


@router.get("/{task_id}/checklist", response_model=list[TaskChecklistItemRead])
def list_checklist_items(
    task_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(404, "Tâche introuvable")
    ensure_task_viewer(db, task, current_user)

    return db.query(TaskChecklistItem).filter(
        TaskChecklistItem.task_id == task_id
    ).order_by(TaskChecklistItem.created_at.asc()).all()


@router.patch("/checklist/{item_id}", response_model=TaskChecklistItemRead)
def update_checklist_item(
    item_id: UUID,
    payload: TaskChecklistItemUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = db.query(TaskChecklistItem).filter(
        TaskChecklistItem.id == item_id
    ).first()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Élément de checklist introuvable",
        )
    task = lock_row(db, Task, item.task_id)
    if task is None:
        raise HTTPException(404, "Tâche introuvable")
    if task.status in {"termine","valide","annule"}:
        raise HTTPException(status_code=409,detail="Les étapes d’un livrable remis ou clôturé ne peuvent plus être modifiées.")
    if payload.title is not None:
        ensure_task_manager(db, task, current_user)
    else:
        ensure_task_actor(db, task, current_user)

    if payload.title is not None:
        item.title = payload.title

    if payload.is_done is not None:
        item.is_done = payload.is_done

    item.updated_at = utc_now()

    db.commit()
    db.refresh(item)

    return item


@router.delete("/checklist/{item_id}")
def delete_checklist_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = db.query(TaskChecklistItem).filter(
        TaskChecklistItem.id == item_id
    ).first()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Élément de checklist introuvable",
        )
    task = lock_row(db, Task, item.task_id)
    if task is None:
        raise HTTPException(404, "Tâche introuvable")
    ensure_task_manager(db, task, current_user)
    ensure_task_work_editable(task)

    db.delete(item)
    db.commit()

    return {
        "ok": True,
        "message": "Élément supprimé",
    }


@router.post("/comments", response_model=TaskCommentRead)
def create_task_comment(
    payload: TaskCommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, payload.task_id)
    if task is None:
        raise HTTPException(404, "Tâche introuvable")
    ensure_task_viewer(db, task, current_user)

    comment = TaskComment(
        task_id=payload.task_id,
        user_id=current_user.id,
        content=payload.content,
    )

    db.add(comment)
    db.commit()
    db.refresh(comment)

    return comment


@router.get("/{task_id}/comments", response_model=list[TaskCommentRead])
def list_task_comments(
    task_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(404, "Tâche introuvable")
    ensure_task_viewer(db, task, current_user)

    return db.query(TaskComment).filter(
        TaskComment.task_id == task_id
    ).order_by(TaskComment.created_at.asc()).all()
