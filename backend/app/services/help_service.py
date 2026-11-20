"""Support and suggestions: fresh authorization, serialized writes and private notes."""
import hashlib
import json
from datetime import timedelta
from uuid import UUID
from fastapi import HTTPException
from sqlalchemy.orm import Session
from app.core.time import utc_now
from app.core.roles import SECRETARIAT_ROLES
from app.api.deps import get_user_role_names
from app.models.user import User
from app.models.role import Role, UserRole
from app.models.product_services import SupportTicket, SupportTicketMessage, ProductFeedback
from app.services.audit_service import create_audit_log
from app.services.notification_service import create_notifications

SUPPORT_TRANSITIONS = {
    "open": {"in_progress", "resolved", "closed"},
    "in_progress": {"open", "resolved", "closed"},
    "resolved": {"in_progress", "closed"},
    "closed": {"open"},
}
FEEDBACK_TRANSITIONS = {
    "new": {"reviewed", "planned", "closed"},
    "reviewed": {"new", "planned", "closed"},
    "planned": {"reviewed", "closed"},
    "closed": {"reviewed"},
}
STATUS_LABELS = {"open":"Ouverte", "in_progress":"En cours", "resolved":"Résolue", "closed":"Clôturée",
                 "new":"Reçu", "reviewed":"Étudié", "planned":"Prévu"}
def _id(value):
    try: return UUID(str(value))
    except (ValueError, TypeError, AttributeError) as exc:
        raise HTTPException(404, "Cette demande est introuvable.") from exc

def _eligible(user):
    return bool(user and user.is_active and user.email_verified and not user.credential_setup_required and (
        (user.status=="active" and user.profile_type in {"enacteur","enactrice"})
        or (user.status=="alumni" and user.profile_type=="alumni")))

def _staff(db, user):
    return bool(_eligible(user) and user.status=="active"
                and not (user.onboarding_required and user.onboarding_completed_at is None)
                and get_user_role_names(db,user.id).intersection(SECRETARIAT_ROLES))

def _lock(db, actor_id, *, model=None, item_id=None, manager=False, assigned_id=None):
    ids={actor_id,*_staff_ids(db)}
    snapshot=None
    if model is not None:
        item_id=_id(item_id)
        columns=[model.user_id]
        if model is SupportTicket: columns.append(model.assigned_to_id)
        snapshot=db.query(*columns).filter(model.id==item_id).first()
        if snapshot is None: raise HTTPException(404,"Cette demande est introuvable.")
        ids.update(value for value in snapshot if value is not None)
    if assigned_id is not None: ids.add(assigned_id)
    users={u.id:u for u in db.query(User).filter(User.id.in_(ids))
           .order_by(User.id.asc()).populate_existing().with_for_update().all()}
    db.info["help_locked_users"]=set(users)
    actor=users.get(actor_id)
    if not _eligible(actor) or (manager and not _staff(db,actor)):
        raise HTTPException(403,"Cette action est réservée aux comptes habilités.")
    item=None
    if model is not None:
        item=db.query(model).filter(model.id==item_id).populate_existing().with_for_update().first()
        if item is None or (not manager and item.user_id!=actor.id):
            raise HTTPException(404,"Cette demande est introuvable.")
        involved={item.user_id}
        if model is SupportTicket and item.assigned_to_id: involved.add(item.assigned_to_id)
        if not involved.issubset(users):
            raise HTTPException(409,"La prise en charge a changé. Actualisez la demande.")
    return actor,item,users

def _fingerprint(payload, *, ticket_id=None):
    values=payload.model_dump(mode="json",exclude={"client_request_id"})
    if ticket_id is not None: values["ticket_id"]=str(ticket_id)
    return hashlib.sha256(json.dumps(values,ensure_ascii=False,sort_keys=True,separators=(",",":")).encode()).hexdigest()

def _replay(db, model, author_id, payload, digest):
    key=payload.client_request_id
    if key is None: return None
    column=model.author_id if model is SupportTicketMessage else model.user_id
    item=db.query(model).filter(column==author_id,model.client_request_id==key).first()
    if item is not None and item.submission_hash!=digest:
        raise HTTPException(409,"Cette tentative correspond à un autre contenu. Reprenez l'envoi.")
    return item

def _limit(db,model,actor_id,maximum):
    author=model.author_id if model is SupportTicketMessage else model.user_id
    since=utc_now()-timedelta(minutes=15)
    if db.query(model.id).filter(author==actor_id,model.created_at>=since).count()>=maximum:
        raise HTTPException(429,"Vous avez déjà envoyé plusieurs messages. Patientez avant de réessayer.")

def _staff_ids(db):
    return {row[0] for row in db.query(User.id).join(UserRole,UserRole.user_id==User.id)
            .join(Role,Role.id==UserRole.role_id).filter(Role.name.in_(SECRETARIAT_ROLES),
            User.status=="active",User.profile_type.in_({"enacteur","enactrice"}),
            User.is_active.is_(True),User.email_verified.is_(True),User.credential_setup_required.is_(False)).distinct().all()}

def _notify(db,ids,title,message,kind,item_id,actor_id):
    recipients=(set(ids)-{actor_id}).intersection(db.info.get("help_locked_users",set()))
    if recipients:
        create_notifications(db,recipient_ids=recipients,title=title,body=message,
            type="support",related_type=kind,related_id=item_id,dedupe=False)

def _audit(db,actor,action,item,values=None):
    create_audit_log(db,action,actor.id,"support_ticket" if isinstance(item,SupportTicket) else "product_feedback",
                     item.id,new_value=values)

def _check_expected(item,payload):
    expected=getattr(payload,"expected_updated_at",None)
    if expected is not None:
        from app.services.operational_integrity import to_naive_utc
        if to_naive_utc(expected)!=item.updated_at:
            raise HTTPException(409,"Cette demande a changé. Actualisez-la avant de poursuivre.")

def create_ticket(db,actor,payload):
    actor,_,_=_lock(db,actor.id)
    digest=_fingerprint(payload)
    existing=_replay(db,SupportTicket,actor.id,payload,digest)
    if existing is not None: return existing
    _limit(db,SupportTicket,actor.id,10)
    ticket=SupportTicket(user_id=actor.id,subject=payload.subject.strip(),category=payload.category.value,
        priority=payload.priority.value,client_request_id=payload.client_request_id,submission_hash=digest)
    db.add(ticket);db.flush()
    db.add(SupportTicketMessage(ticket_id=ticket.id,author_id=actor.id,message=payload.message.strip()))
    _audit(db,actor,"support_ticket_created",ticket)
    _notify(db,_staff_ids(db),"Nouvelle demande d'aide","Une demande attend une prise en charge dans le centre d'aide.",
            "support_ticket_management",ticket.id,actor.id)
    db.commit();db.refresh(ticket);return ticket

def list_tickets(db,actor,manager=False):
    actor,_,_=_lock(db,actor.id,manager=manager)
    query=db.query(SupportTicket)
    if not manager: query=query.filter(SupportTicket.user_id==actor.id)
    return query.order_by(SupportTicket.updated_at.desc(),SupportTicket.id).all()

def read_ticket(db,actor,item_id,manager=False):
    actor,ticket,users=_lock(db,actor.id,model=SupportTicket,item_id=item_id,manager=manager)
    return {column.name:getattr(ticket,column.name) for column in SupportTicket.__table__.columns} | {
        "messages":db.query(SupportTicketMessage).filter_by(ticket_id=ticket.id)
            .order_by(SupportTicketMessage.created_at,SupportTicketMessage.id).all(),
        "requester_name":f"{users[ticket.user_id].first_name} {users[ticket.user_id].last_name}"}

def reply(db,actor,item_id,payload,manager=False):
    actor,ticket,_=_lock(db,actor.id,model=SupportTicket,item_id=item_id,manager=manager)
    digest=_fingerprint(payload,ticket_id=ticket.id)
    existing=_replay(db,SupportTicketMessage,actor.id,payload,digest)
    if existing is not None: return existing
    if not manager and ticket.status=="closed":
        raise HTTPException(409,"Cette demande est clôturée. Ouvrez une nouvelle demande si nécessaire.")
    _limit(db,SupportTicketMessage,actor.id,60)
    item=SupportTicketMessage(ticket_id=ticket.id,author_id=actor.id,message=payload.message.strip(),
        client_request_id=payload.client_request_id,submission_hash=digest)
    db.add(item)
    if not manager and ticket.status=="resolved":
        ticket.status="in_progress";ticket.resolved_at=None;ticket.closed_at=None
    ticket.updated_at=utc_now()
    _audit(db,actor,"support_ticket_replied",ticket,{"management":manager})
    recipients={ticket.user_id} if manager else ({ticket.assigned_to_id} if ticket.assigned_to_id else _staff_ids(db))
    _notify(db,recipients,"Une réponse à votre demande" if manager else "Une demande d'aide a été complétée",
        "Retrouvez le nouvel échange dans le centre d'aide.","support_ticket" if manager else "support_ticket_management",ticket.id,actor.id)
    db.commit();db.refresh(item);return item

def manage_ticket(db,actor,item_id,payload):
    actor,ticket,users=_lock(db,actor.id,model=SupportTicket,item_id=item_id,manager=True,assigned_id=payload.assigned_to_id)
    _check_expected(ticket,payload);fields=payload.model_fields_set;changes={}
    for name in ("status","priority"):
        if name in fields and getattr(payload,name) is None:
            raise HTTPException(422,"Choisissez un statut et une priorité valides.")
    if "assigned_to_id" in fields and payload.assigned_to_id is not None:
        if not _staff(db,users.get(payload.assigned_to_id)):
            raise HTTPException(422,"Choisissez un responsable actif et habilité au centre d'aide.")
    if "status" in fields:
        nxt=payload.status.value
        if nxt!=ticket.status and nxt not in SUPPORT_TRANSITIONS[ticket.status]:
            raise HTTPException(409,"Ce changement de statut n'est pas disponible.")
        if nxt!=ticket.status:
            changes["status"]={"old":ticket.status,"new":nxt};ticket.status=nxt
            if nxt=="resolved":ticket.resolved_at=utc_now();ticket.closed_at=None
            elif nxt=="closed":ticket.closed_at=utc_now()
            else:ticket.resolved_at=None;ticket.closed_at=None
    if "priority" in fields and payload.priority.value!=ticket.priority:
        changes["priority"]={"old":ticket.priority,"new":payload.priority.value};ticket.priority=payload.priority.value
    if "assigned_to_id" in fields:
        target=users.get(payload.assigned_to_id) if payload.assigned_to_id is not None else None
        if payload.assigned_to_id is not None and not _staff(db,target):
            raise HTTPException(422,"Choisissez un responsable actif et habilité au centre d'aide.")
        if payload.assigned_to_id!=ticket.assigned_to_id:
            changes["assigned_to_id"]={"old":str(ticket.assigned_to_id) if ticket.assigned_to_id else None,
                                      "new":str(payload.assigned_to_id) if payload.assigned_to_id else None}
            ticket.assigned_to_id=payload.assigned_to_id
    if changes:
        ticket.updated_at=utc_now();_audit(db,actor,"support_ticket_managed",ticket,changes)
        if "status" in changes:
            _notify(db,{ticket.user_id},"Votre demande a évolué",
                "Son état est maintenant : "+STATUS_LABELS[ticket.status]+". Retrouvez le suivi dans le centre d'aide.",
                "support_ticket",ticket.id,actor.id)
        if "assigned_to_id" in changes and ticket.assigned_to_id:
            _notify(db,{ticket.assigned_to_id},"Une demande vous est confiée",
                "Retrouvez la demande à traiter dans le centre d'aide.","support_ticket_management",ticket.id,actor.id)
        db.commit();db.refresh(ticket)
    return ticket

def create_feedback(db,actor,payload):
    actor,_,_=_lock(db,actor.id);digest=_fingerprint(payload)
    existing=_replay(db,ProductFeedback,actor.id,payload,digest)
    if existing is not None:return existing
    _limit(db,ProductFeedback,actor.id,20)
    item=ProductFeedback(user_id=actor.id,category=payload.category.value,message=payload.message.strip(),
        rating=payload.rating,platform=payload.platform.value if payload.platform else None,
        app_version=(payload.app_version or "").strip() or None,build_number=payload.build_number,
        client_request_id=payload.client_request_id,submission_hash=digest)
    db.add(item);db.flush();_audit(db,actor,"product_feedback_created",item)
    _notify(db,_staff_ids(db),"Un retour sur EnactSpace","Un problème ou une suggestion attend une lecture dans le centre d'aide.",
            "product_feedback_management",item.id,actor.id)
    db.commit();db.refresh(item);return item

def list_feedback(db,actor,manager=False):
    actor,_,_=_lock(db,actor.id,manager=manager)
    query=db.query(ProductFeedback)
    if not manager:query=query.filter_by(user_id=actor.id)
    return query.order_by(ProductFeedback.updated_at.desc(),ProductFeedback.id).all()

def read_feedback(db,actor,item_id,manager=False):
    _,item,_=_lock(db,actor.id,model=ProductFeedback,item_id=item_id,manager=manager)
    return item

def manage_feedback(db,actor,item_id,payload):
    actor,item,_=_lock(db,actor.id,model=ProductFeedback,item_id=item_id,manager=True)
    _check_expected(item,payload);changes={}
    if "status" in payload.model_fields_set and payload.status is None:
        raise HTTPException(400,"Choisissez un statut valide.")
    for field,value in payload.model_dump(exclude_unset=True,exclude={"expected_updated_at"}).items():
        value=(getattr(value,"value",value) if field=="status" else (value or "").strip() or None)
        if field=="status" and value!=item.status and value not in FEEDBACK_TRANSITIONS[item.status]:
            raise HTTPException(409,"Ce changement de statut n'est pas disponible.")
        if value!=getattr(item,field):
            changes[field]={"old":getattr(item,field),"new":value};setattr(item,field,value)
    if changes:
        item.updated_at=utc_now();_audit(db,actor,"product_feedback_managed",item,changes)
        if {"status","public_reply"}.intersection(changes):
            _notify(db,{item.user_id},"Votre remarque a été étudiée",
                "Retrouvez son état et les réponses de l'équipe dans le centre d'aide.",
                "product_feedback",item.id,actor.id)
        db.commit();db.refresh(item)
    return item
