from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import and_, or_
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

    return datetime.utcnow() > task.due_date


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
    if not task.due_date or task.status in {"termine", "valide", "annule"}:
        return

    now = datetime.utcnow()
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
    data["current_user_assigned"] = user_is_assigned(db, task, user)
    return data


def ensure_task_manager(db: Session, task: Task, user: User) -> None:
    if not user_can_manage_task(db, task, user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Gestion réservée au responsable de ce périmètre",
        )


def ensure_task_actor(db: Session, task: Task, user: User) -> bool:
    is_manager = user_can_manage_task(db, task, user)
    is_assignee = user_is_assigned(db, task, user)

    if not is_manager and not is_assignee:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée aux responsables et aux membres assignés",
        )
    return is_manager


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
    now = datetime.utcnow()
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
    if user_has_any_role(db, user.id, GLOBAL_TASK_MANAGER_ROLES):
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
    now = datetime.utcnow()

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
    project_id: str,
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
    pole_id: str,
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
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_actor(db, task, current_user)
    return task_payload(db, task, current_user)


@router.patch("/{task_id}", response_model=TaskRead)
def update_task(
    task_id: str,
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
        task.due_date = to_naive_utc(payload.due_date)

    if payload.proof_required is not None:
        task.proof_required = payload.proof_required

    if payload.proof_url is not None:
        if task.status in {"valide", "annule"}:
            raise HTTPException(status_code=409, detail="La preuve d'une tâche terminale est immuable")
        task.proof_url = payload.proof_url

    status_changed = False
    if payload.status is not None:
        status_changed = apply_task_status(
            task,
            payload.status,
            is_manager=True,
            actor_id=current_user.id,
        )

    task.updated_at = datetime.utcnow()

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
    task_id: str,
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


@router.post("/{task_id}/proof", response_model=TaskRead)
def submit_task_proof(
    task_id: str,
    payload: TaskProofSubmit,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    ensure_task_actor(db, task, current_user)

    if task.status in {"valide", "annule"}:
        raise HTTPException(status_code=409, detail="La preuve d'une tâche terminale est immuable")

    task.proof_url = payload.proof_url
    task.updated_at = datetime.utcnow()
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


@router.post("/{task_id}/validate", response_model=TaskRead)
def validate_task(
    task_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = lock_row(db, Task, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Tâche introuvable")
    ensure_task_manager(db, task, current_user)
    old_status = task.status
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
    task_id: str,
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
    if task.status in {"valide", "annule"}:
        raise HTTPException(status_code=409, detail="Aucun assigné ne peut être ajouté à une tâche terminale")
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
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_actor(db, task, current_user)

    return db.query(TaskAssignee).filter(
        TaskAssignee.task_id == task_id
    ).order_by(TaskAssignee.assigned_at.asc()).all()


@router.delete("/{task_id}/assignees/{user_id}")
def remove_task_assignee(
    task_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_manager(db, task, current_user)
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
    task = get_task_or_404(db, str(payload.task_id))
    ensure_task_manager(db, task, current_user)

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
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_actor(db, task, current_user)

    return db.query(TaskChecklistItem).filter(
        TaskChecklistItem.task_id == task_id
    ).order_by(TaskChecklistItem.created_at.asc()).all()


@router.patch("/checklist/{item_id}", response_model=TaskChecklistItemRead)
def update_checklist_item(
    item_id: str,
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
    task = get_task_or_404(db, str(item.task_id))
    ensure_task_manager(db, task, current_user)

    if payload.title is not None:
        item.title = payload.title

    if payload.is_done is not None:
        item.is_done = payload.is_done

    item.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(item)

    return item


@router.delete("/checklist/{item_id}")
def delete_checklist_item(
    item_id: str,
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
    task = get_task_or_404(db, str(item.task_id))
    ensure_task_manager(db, task, current_user)

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
    task = get_task_or_404(db, str(payload.task_id))
    ensure_task_actor(db, task, current_user)

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
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_actor(db, task, current_user)

    return db.query(TaskComment).filter(
        TaskComment.task_id == task_id
    ).order_by(TaskComment.created_at.asc()).all()
