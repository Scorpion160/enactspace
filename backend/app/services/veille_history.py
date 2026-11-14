"""Capture task changes through every API, not just the Veille screen."""
import uuid
from datetime import datetime
from sqlalchemy import event, inspect
from sqlalchemy.orm import Session
from app.models.task import Task, TaskAssignee
from app.models.veille import VeilleEvent


def scalar(value):
    if isinstance(value, datetime):
        return value.isoformat() + ("Z" if value.tzinfo is None else "")
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value) if isinstance(value, uuid.UUID) else value


@event.listens_for(Session, "before_flush")
def capture_task_changes(db, _context, _instances):
    if "veille_history_ready" not in db.info:
        db.info["veille_history_ready"] = inspect(db.connection()).has_table("veille_events")
    if not db.info["veille_history_ready"]:
        return  # Historical migration fixtures may intentionally use an older schema.
    for obj in list(db.new) + list(db.dirty) + list(db.deleted):
        if isinstance(obj, Task):
            if obj.id is None:
                obj.id = uuid.uuid4()
            fields = ("title", "status", "due_date", "pole_id", "project_id", "veille_plan_id", "veille_season_id", "creator_id", "proof_url", "completed_at", "validated_at", "validated_by")
            action = "created" if obj in db.new else "deleted" if obj in db.deleted else "changed"
            before, after = {}, {}
            state = inspect(obj)
            for field in fields:
                history = state.attrs[field].history
                if action != "changed" or history.has_changes():
                    before[field] = scalar(history.deleted[0]) if history.deleted else None
                    after[field] = scalar(getattr(obj, field))
            if after:
                db.add(VeilleEvent(entity_type="task", entity_id=obj.id, action=action,
                    message="Création de la tâche" if action=="created" else "Suppression de la tâche" if action=="deleted" else "Mise à jour de la tâche",
                    created_by_id=db.info.get("actor_id"), details={"before": before, "after": after}))
        elif isinstance(obj, TaskAssignee) and (obj in db.new or obj in db.deleted):
            if obj.task_id:
                db.add(VeilleEvent(entity_type="task", entity_id=obj.task_id,
                    action="assigned" if obj in db.new else "unassigned", message="Affectation mise à jour",
                    created_by_id=db.info.get("actor_id"), details={"member_id": str(obj.user_id)}))
