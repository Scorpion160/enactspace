"""Campaign-scoped operational juror constraints, derived from audited decisions.

Past campaign events are intentionally interpreted only for their own campaign.
No e-mail or candidate appointment is changed by this read-only module.
"""
from app.models.audit import AuditLog


def constraints_from_events(events):
    """Return date blackouts and remote-only users, supporting historical logs."""
    blackouts = {}
    remote_only = set()
    for event in events:
        data = event.new_value if isinstance(event.new_value, dict) else {}
        action = event.action
        if action == "indisponibilite_jure_exceptionnelle_20261117":
            uid = data.get("user_id")
            day = data.get("date")
            if uid and day and data.get("available") is False:
                blackouts.setdefault(str(uid), set()).add(str(day))
        elif action == "restriction_jure_distanciel":
            uid = data.get("jury_user_id")
            if uid and data.get("allowed_participation") == "online_only":
                remote_only.add(str(uid))
        elif action == "contrainte_jure_jour_definie":
            uid = data.get("user_id")
            day = data.get("date")
            if uid and day:
                affected = blackouts.setdefault(str(uid), set())
                if data.get("available") is False:
                    affected.add(str(day))
                elif data.get("available") is True:
                    affected.discard(str(day))
        elif action == "contrainte_jure_participation_definie":
            uid = data.get("user_id")
            if uid:
                if data.get("participation") == "online_only":
                    remote_only.add(str(uid))
                elif data.get("participation") == "any":
                    remote_only.discard(str(uid))
    return blackouts, remote_only


def jury_constraints(db, campaign_id):
    events = db.query(AuditLog).filter(
        AuditLog.entity_type == "recruitment_campaign",
        AuditLog.entity_id == campaign_id,
        AuditLog.action.in_([
            "indisponibilite_jure_exceptionnelle_20261117",
            "restriction_jure_distanciel",
            "contrainte_jure_jour_definie",
            "contrainte_jure_participation_definie",
        ]),
    ).order_by(AuditLog.created_at, AuditLog.id).all()
    return constraints_from_events(events)


def juror_respects_constraints(user_id, start, mode, blackouts, remote_only):
    if start.date().isoformat() in blackouts.get(str(user_id), set()):
        return False
    if str(user_id) in remote_only and mode == "in_person":
        return False
    return True
