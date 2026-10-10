"""Execute approved dismissal notices at their effective date, once only."""
from datetime import date
from uuid import UUID
from fastapi import HTTPException
from app.core.time import utc_now
from app.models.institutional_document import InstitutionalDocumentRequest
from app.services.operational_integrity import lock_user, reconcile_user_lifecycle
from app.services.session_service import revoke_user_sessions
from app.services.audit_service import create_audit_log
from app.api.deps import get_user_role_names


def apply_approved_dismissal(db, item, today=None):
    if item.template_code != "notification_renvoi" or item.status != "validated":
        return False
    payload = dict(item.payload_json or {})
    if payload.get("dismissal_executed_at"):
        return False
    try:
        effective = date.fromisoformat(str(payload["effective_date"]))
        member_id = UUID(str(payload["member_id"]))
    except (KeyError, ValueError, TypeError):
        raise HTTPException(409, "La date d’effet et le membre concerné doivent être valides.")
    user = lock_user(db, member_id)
    if user.id in {item.requested_by, item.sg_validated_by, item.approved_by}:
        raise HTTPException(409, "Le membre concerné doit être distinct des responsables de validation.")
    if "administrateur" in get_user_role_names(db, user.id):
        raise HTTPException(409, "Ce parcours ne peut pas désactiver un administrateur.")
    if user.profile_type not in {"enacteur", "enactrice"} or user.status not in {"active", "suspended"}:
        raise HTTPException(409, "Ce renvoi exige un profil enacteur ou enactrice actif ou suspendu.")
    if effective > (today or utc_now().date()):
        return False
    old = {"status": user.status, "is_active": user.is_active}
    reconcile_user_lifecycle(db, user, "suspended")
    revoke_user_sessions(db, user.id)
    payload["dismissal_executed_at"] = utc_now().isoformat()
    item.payload_json = payload
    create_audit_log(db, action="renvoi_execute", user_id=item.approved_by,
                     entity_type="user", entity_id=user.id, old_value=old,
                     new_value={"status": user.status, "is_active": False,
                                "document_id": str(item.id), "effective_date": str(effective)})
    return True


def execute_due_dismissals(db):
    count = 0
    rows = db.query(InstitutionalDocumentRequest).filter(
        InstitutionalDocumentRequest.template_code == "notification_renvoi",
        InstitutionalDocumentRequest.status == "validated",
    ).order_by(InstitutionalDocumentRequest.id).with_for_update().all()
    for item in rows:
        # Legacy approvals must be reviewed explicitly before enabling execution.
        if (item.payload_json or {}).get("dismissal_execution_enabled") is True:
            count += int(apply_approved_dismissal(db, item))
    db.commit()
    return count
