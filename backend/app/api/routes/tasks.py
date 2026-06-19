from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.task import (
    Task,
    TaskAssignee,
    TaskChecklistItem,
    TaskComment,
)
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
    require_enacchef_or_admin,
    user_has_any_role,
)
from app.services.notification_service import notify_user, notify_users

router = APIRouter(prefix="/tasks", tags=["Tâches"])


VALID_TASK_STATUSES = {
    "a_faire",
    "en_cours",
    "bloque",
    "termine",
    "valide",
    "annule",
}

VALID_TASK_PRIORITIES = {
    "basse",
    "normale",
    "haute",
    "urgente",
}

TASK_MANAGER_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
    "chef_pole",
    "adjoint_chef_pole",
    "chef_projet",
    "adjoint_chef_projet",
}


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


def ensure_task_actor(db: Session, task: Task, user: User) -> bool:
    is_manager = user_has_any_role(db, user.id, TASK_MANAGER_ROLES)
    is_assignee = (
        db.query(TaskAssignee.id)
        .filter(
            TaskAssignee.task_id == task.id,
            TaskAssignee.user_id == user.id,
        )
        .first()
        is not None
    )

    if not is_manager and not is_assignee:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée aux responsables et aux membres assignés",
        )
    return is_manager


def visible_tasks_query(db: Session, user: User):
    query = db.query(Task)
    if user_has_any_role(db, user.id, TASK_MANAGER_ROLES):
        return query

    task_ids = db.query(TaskAssignee.task_id).filter(
        TaskAssignee.user_id == user.id
    )
    return query.filter(Task.id.in_(task_ids))


@router.post("/", response_model=TaskRead)
def create_task(
    payload: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
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
        due_date=payload.due_date,
        proof_required=payload.proof_required,
    )

    db.add(task)
    db.flush()

    for user_id in payload.assignee_ids:
        assignee = TaskAssignee(
            task_id=task.id,
            user_id=user_id,
        )
        db.add(assignee)

    notify_users(
        db,
        user_ids=payload.assignee_ids,
        title="Nouvelle tâche assignée",
        message=f"Vous êtes assigné à la tâche « {task.title} ».",
        notification_type="task_assigned",
        related_type="task",
        related_id=task.id,
    )

    db.commit()
    db.refresh(task)

    return task


@router.get("/", response_model=list[TaskRead])
def list_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return visible_tasks_query(db, current_user).order_by(
        Task.created_at.desc()
    ).all()


@router.get("/my", response_model=list[TaskRead])
def list_my_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task_ids = db.query(TaskAssignee.task_id).filter(
        TaskAssignee.user_id == current_user.id
    )

    return db.query(Task).filter(
        Task.id.in_(task_ids)
    ).order_by(Task.created_at.desc()).all()


@router.get("/late", response_model=list[TaskRead])
def list_late_tasks(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    now = datetime.utcnow()

    return visible_tasks_query(db, current_user).filter(
        Task.due_date.isnot(None),
        Task.due_date < now,
        Task.status.notin_(["termine", "valide", "annule"]),
    ).order_by(Task.due_date.asc()).all()


@router.get("/project/{project_id}", response_model=list[TaskRead])
def list_project_tasks(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return visible_tasks_query(db, current_user).filter(
        Task.project_id == project_id
    ).order_by(Task.created_at.desc()).all()


@router.get("/pole/{pole_id}", response_model=list[TaskRead])
def list_pole_tasks(
    pole_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return visible_tasks_query(db, current_user).filter(
        Task.pole_id == pole_id
    ).order_by(Task.created_at.desc()).all()


@router.get("/{task_id}", response_model=TaskRead)
def get_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_actor(db, task, current_user)
    return task


@router.patch("/{task_id}", response_model=TaskRead)
def update_task(
    task_id: str,
    payload: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    task = get_task_or_404(db, task_id)

    if payload.priority is not None:
        if payload.priority not in VALID_TASK_PRIORITIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Priorité invalide",
            )
        task.priority = payload.priority

    if payload.status is not None:
        if payload.status not in VALID_TASK_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Statut invalide",
            )

        task.status = payload.status

        if payload.status == "termine":
            task.completed_at = datetime.utcnow()

        if payload.status not in {"termine", "valide"}:
            task.completed_at = None
            task.validated_at = None
            task.validated_by = None

    if payload.title is not None:
        task.title = payload.title

    if payload.description is not None:
        task.description = payload.description

    if payload.due_date is not None:
        task.due_date = payload.due_date

    if payload.proof_required is not None:
        task.proof_required = payload.proof_required

    if payload.proof_url is not None:
        task.proof_url = payload.proof_url

    task.updated_at = datetime.utcnow()

    assignee_ids = db.query(TaskAssignee.user_id).filter(
        TaskAssignee.task_id == task.id
    ).all()
    notify_users(
        db,
        user_ids=[row[0] for row in assignee_ids],
        title="Tâche mise à jour",
        message=f"La tâche « {task.title} » a été modifiée.",
        notification_type="task_updated",
        related_type="task",
        related_id=task.id,
    )

    db.commit()
    db.refresh(task)

    return task


@router.post("/{task_id}/status", response_model=TaskRead)
def change_task_status(
    task_id: str,
    payload: TaskStatusChange,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    is_manager = ensure_task_actor(db, task, current_user)

    if payload.status not in VALID_TASK_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut invalide",
        )
    if not is_manager and payload.status not in {
        "a_faire",
        "en_cours",
        "bloque",
        "termine",
    }:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Ce statut doit être appliqué par un responsable",
        )

    if payload.status == "termine" and task.proof_required and not task.proof_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Une preuve est requise avant de marquer cette tâche comme terminée",
        )

    task.status = payload.status

    if payload.status == "termine":
        task.completed_at = datetime.utcnow()

    if payload.status in {"a_faire", "en_cours", "bloque"}:
        task.completed_at = None
        task.validated_at = None
        task.validated_by = None

    task.updated_at = datetime.utcnow()

    assignee_ids = db.query(TaskAssignee.user_id).filter(
        TaskAssignee.task_id == task.id
    ).all()
    notify_users(
        db,
        user_ids=[row[0] for row in assignee_ids],
        title="Statut de tâche modifié",
        message=f"La tâche « {task.title} » est maintenant {task.status}.",
        notification_type="task_updated",
        related_type="task",
        related_id=task.id,
    )

    db.commit()
    db.refresh(task)

    return task


@router.post("/{task_id}/proof", response_model=TaskRead)
def submit_task_proof(
    task_id: str,
    payload: TaskProofSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    task = get_task_or_404(db, task_id)
    ensure_task_actor(db, task, current_user)

    task.proof_url = payload.proof_url
    task.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(task)

    return task


@router.post("/{task_id}/validate", response_model=TaskRead)
def validate_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    task = get_task_or_404(db, task_id)

    if task.status != "termine":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La tâche doit d'abord être marquée comme terminée",
        )

    if task.proof_required and not task.proof_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de valider une tâche sans preuve",
        )

    task.status = "valide"
    task.validated_by = current_user.id
    task.validated_at = datetime.utcnow()
    task.updated_at = datetime.utcnow()

    assignee_ids = db.query(TaskAssignee.user_id).filter(
        TaskAssignee.task_id == task.id
    ).all()
    notify_users(
        db,
        user_ids=[row[0] for row in assignee_ids],
        title="Tâche validée",
        message=f"La tâche « {task.title} » a été validée.",
        notification_type="task_validated",
        related_type="task",
        related_id=task.id,
    )

    db.commit()
    db.refresh(task)

    return task


@router.delete("/{task_id}")
def delete_task(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    task = get_task_or_404(db, task_id)

    db.delete(task)
    db.commit()

    return {
        "ok": True,
        "message": "Tâche supprimée",
    }


@router.post("/assignees", response_model=list[TaskAssigneeRead])
def add_task_assignees(
    payload: TaskAssigneeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    task = get_task_or_404(db, str(payload.task_id))

    created = []

    for user_id in payload.user_ids:
        existing = db.query(TaskAssignee).filter(
            TaskAssignee.task_id == task.id,
            TaskAssignee.user_id == user_id,
        ).first()

        if existing:
            continue

        assignee = TaskAssignee(
            task_id=task.id,
            user_id=user_id,
        )

        db.add(assignee)
        created.append(assignee)
        notify_user(
            db,
            user_id=user_id,
            title="Nouvelle tâche assignée",
            message=f"Vous êtes assigné à la tâche « {task.title} ».",
            notification_type="task_assigned",
            related_type="task",
            related_id=task.id,
        )

    db.commit()

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
    current_user: User = Depends(require_enacchef_or_admin),
):
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
    current_user: User = Depends(require_enacchef_or_admin),
):
    get_task_or_404(db, str(payload.task_id))

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
    current_user: User = Depends(require_enacchef_or_admin),
):
    item = db.query(TaskChecklistItem).filter(
        TaskChecklistItem.id == item_id
    ).first()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Élément de checklist introuvable",
        )

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
    current_user: User = Depends(require_enacchef_or_admin),
):
    item = db.query(TaskChecklistItem).filter(
        TaskChecklistItem.id == item_id
    ).first()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Élément de checklist introuvable",
        )

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
