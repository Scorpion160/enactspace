"""Operational follow-up, scoped evidence, and human decision workflows."""
import uuid
from datetime import date, datetime, time, timedelta

from fastapi import HTTPException
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.api.deps import get_user_role_names
from app.core.roles import normalize_role_name, is_veille_pole_name
from app.core.time import utc_now
from app.models.user import User
from app.models.role import Role, UserRole
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember
from app.models.season import Season
from app.models.task import Task, TaskAssignee
from app.models.attendance import AttendanceExpectedMember, AttendanceRecord, AttendanceSession
from app.models.academy import AcademyCourse
from app.models.finance import Fee
from app.models.veille import (VeilleSettings, VeilleRule, VeillePlan, VeilleBlocker,
    VeilleReview, VeilleReport, VeilleLeave, VeilleCase, VeilleEvent)
from app.services.operational_integrity import to_naive_utc, lock_row
from app.services.audit_service import create_audit_log
from app.services.notification_service import notify_user, notify_users

VEILLE_ROLES = {"pole_veille", "veille", "chef_pole_veille", "adjoint_pole_veille"}
GLOBAL_COORDINATORS = {"administrateur", "team_leader", "secretaire_generale"}
DECIDERS = {"administrateur", "team_leader"}
ENACCHEF = {"team_leader", "secretaire_generale", "financier", "chef_pole", "adjoint_chef_pole", "chef_projet", "adjoint_chef_projet"}
TERMINAL_TASKS = {"termine", "valide", "annule"}
SUPPORT_ACTIONS = {"accompagnement", "clarification", "classement_sans_suite"}


def json_value(value):
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, datetime):
        return to_naive_utc(value).isoformat() + "Z"
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, (str, bool, int, float, list, dict)) or value is None:
        return value
    return float(value)


def record(row):
    return {c.name: json_value(getattr(row, c.name)) for c in row.__table__.columns}


def member_name(user):
    return " ".join(v for v in (user.first_name, user.last_name) if v)


def fail(code, message):
    raise HTTPException(code, message)


def require_version(row, version):
    if row.version != version:
        fail(409, "Ce dossier a changé. Actualisez-le avant de poursuivre.")


def get_record(db, model, ident, locked=False):
    item = lock_row(db, model, ident) if locked else db.get(model, ident)
    if item is None:
        fail(404, "Ce dossier est introuvable.")
    return item


def settings(db):
    row = db.get(VeilleSettings, 1)
    if row:
        return row
    row = VeilleSettings(id=1, version=1, reminders_enabled=True, effective_at=utc_now(),
        quiet_start_hour=21, quiet_end_hour=7, escalation_days=2, response_days=7,
        appeal_days=14, weekly_day=0, report_hour=8, auto_reports=True)
    db.add(row)
    db.flush()
    return row


class VeilleAccess:
    def __init__(self, db: Session, user: User):
        self.db, self.user = db, user
        self.operational = user.status == "active" and user.is_active
        self.roles = get_user_role_names(db, user.id) if self.operational else set()
        memberships = db.query(PoleMember, Pole.name).join(Pole, Pole.id==PoleMember.pole_id).filter(
            PoleMember.user_id==user.id, PoleMember.is_active.is_(True), PoleMember.left_at.is_(None)).all() if self.operational else []
        self.veille = bool(self.roles & VEILLE_ROLES) or any(is_veille_pole_name(name) for _, name in memberships)
        self.full = bool(self.roles & GLOBAL_COORDINATORS) or self.veille
        self.decider = bool(self.roles & DECIDERS)
        self.poles = {m.pole_id for m, _ in memberships if m.position in {"chef_pole", "adjoint_chef_pole"}}
        projects = db.query(ProjectMember).filter(ProjectMember.user_id==user.id,
            ProjectMember.is_active.is_(True), ProjectMember.left_at.is_(None)).all() if self.operational else []
        self.projects = {m.project_id for m in projects if m.position in {"chef_projet", "adjoint_chef_projet"}}
        self.joined_poles = {m.pole_id for m, _ in memberships}
        self.joined_projects = {m.project_id for m in projects}
        self.coordinate = self.full or bool(self.poles or self.projects)
        self.member_ids = {user.id}
        if self.full:
            self.member_ids.update(r[0] for r in db.query(User.id).filter(User.status=="active", User.is_active.is_(True)).all())
        else:
            self.member_ids.update(r[0] for r in db.query(PoleMember.user_id).filter(PoleMember.pole_id.in_(self.poles), PoleMember.is_active.is_(True), PoleMember.left_at.is_(None)).all())
            self.member_ids.update(r[0] for r in db.query(ProjectMember.user_id).filter(ProjectMember.project_id.in_(self.projects), ProjectMember.is_active.is_(True), ProjectMember.left_at.is_(None)).all())

    def require_member(self, ident):
        if ident not in self.member_ids:
            fail(403, "Ce membre ne relève pas de votre périmètre de suivi.")
        user = self.db.get(User, ident)
        if not user or not user.is_active or user.status != "active":
            fail(400, "Choisissez un membre actif.")
        return user

    def scope(self, pole_id=None, project_id=None, season_id=None, manage=False):
        if pole_id and project_id:
            fail(400, "Choisissez un seul périmètre.")
        for ident, model, allowed in ((pole_id, Pole, self.poles if manage else self.poles | self.joined_poles),
                                      (project_id, Project, self.projects if manage else self.projects | self.joined_projects)):
            if ident and not self.db.get(model, ident):
                fail(404, "Le périmètre choisi est introuvable.")
            if ident and not self.full and ident not in allowed:
                fail(403, "Ce périmètre ne vous est pas accessible.")
        if season_id and not self.db.get(Season, season_id):
            fail(404, "L’année choisie est introuvable.")

    def task_query(self):
        if self.full:
            return self.db.query(Task)
        from app.api.routes.tasks import visible_tasks_query
        return visible_tasks_query(self.db, self.user)

    def task(self, ident, manage=False, locked=False):
        item = get_record(self.db, Task, ident, locked)
        if not self.task_query().filter(Task.id==ident).first():
            fail(403, "Cette tâche ne vous est pas accessible.")
        if manage:
            from app.api.routes.tasks import user_can_manage_task
            if not self.full and not user_can_manage_task(self.db, item, self.user):
                fail(403, "Cette action revient au responsable de la tâche.")
        return item

    def can_case(self, item):
        return self.veille or self.decider or item.created_by_id==self.user.id or item.bureau_reviewer_id==self.user.id or (item.member_id==self.user.id and item.status!="draft")

    def case_query(self):
        q = self.db.query(VeilleCase)
        if self.veille or self.decider:
            return q
        return q.filter(or_(VeilleCase.created_by_id==self.user.id,
            VeilleCase.bureau_reviewer_id==self.user.id,
            (VeilleCase.member_id==self.user.id) & (VeilleCase.status!="draft")))

    def plan_query(self):
        q = self.db.query(VeillePlan)
        if self.full:
            return q
        return q.filter(or_(VeillePlan.owner_id==self.user.id, VeillePlan.pole_id.in_(self.poles), VeillePlan.project_id.in_(self.projects)))

    def report_query(self):
        q = self.db.query(VeilleReport)
        if self.full:
            return q
        return q.filter(or_(VeilleReport.created_by_id==self.user.id,
            VeilleReport.pole_id.in_(self.poles), VeilleReport.project_id.in_(self.projects)))


def event_log(db, user, kind, ident, action, message, details=None):
    db.add(VeilleEvent(entity_type=kind, entity_id=ident, action=action, message=message,
        created_by_id=user.id if user else None, details=details or {}))
    create_audit_log(db, "veille_"+action, user_id=user.id if user else None,
        entity_type="veille_"+kind, entity_id=ident, new_value={"action": action})


def notify(db, ids, title, body, kind, ident):
    active_ids = [r[0] for r in db.query(User.id).filter(User.id.in_(set(ids)), User.is_active.is_(True), User.status=="active").all()]
    notify_users(db, user_ids=active_ids, title=title, message=body,
        notification_type="veille_update", related_type="veille_"+kind, related_id=ident, dedupe=False)


def role_user_ids(db,names):
    role_ids=[r.id for r in db.query(Role).all() if normalize_role_name(r.name) in names]
    return {row[0] for row in db.query(UserRole.user_id).filter(UserRole.role_id.in_(role_ids)).all()}


def enacchef_ids(db):
    ids = role_user_ids(db, ENACCHEF)
    ids.update(row[0] for row in db.query(PoleMember.user_id).filter(PoleMember.is_active.is_(True), PoleMember.left_at.is_(None), PoleMember.position.in_({"chef_pole", "adjoint_chef_pole"})).all())
    ids.update(row[0] for row in db.query(ProjectMember.user_id).filter(ProjectMember.is_active.is_(True), ProjectMember.left_at.is_(None), ProjectMember.position.in_({"chef_projet", "adjoint_chef_projet"})).all())
    return {row[0] for row in db.query(User.id).filter(User.id.in_(ids), User.status=="active", User.is_active.is_(True)).all()}


def context(db, user):
    a = VeilleAccess(db, user)
    users = db.query(User).filter(User.id.in_(a.member_ids), User.status=="active", User.is_active.is_(True)).order_by(User.last_name, User.first_name).all()
    bureau = db.query(User).filter(User.id.in_(enacchef_ids(db)),
        User.is_active.is_(True),User.status=="active").order_by(User.last_name,User.first_name).all() if a.coordinate else []
    poles = db.query(Pole).all() if a.full else db.query(Pole).filter(Pole.id.in_(a.poles | a.joined_poles)).all()
    projects = db.query(Project).all() if a.full else db.query(Project).filter(Project.id.in_(a.projects | a.joined_projects)).all()
    member_poles={u.id:[] for u in users};member_projects={u.id:[] for u in users}
    for m in db.query(PoleMember).filter(PoleMember.user_id.in_(member_poles),PoleMember.is_active.is_(True),PoleMember.left_at.is_(None)).all(): member_poles[m.user_id].append(str(m.pole_id))
    for m in db.query(ProjectMember).filter(ProjectMember.user_id.in_(member_projects),ProjectMember.is_active.is_(True),ProjectMember.left_at.is_(None)).all(): member_projects[m.user_id].append(str(m.project_id))
    return {"user_id": str(user.id), "can_coordinate": a.coordinate, "global_scope": a.full,
        "can_decide": a.decider, "can_manage_settings": a.decider,
        "members": [{"id":str(u.id),"name":member_name(u),"pole_ids":member_poles[u.id],"project_ids":member_projects[u.id]} for u in users],
        "managed_pole_ids":[str(i) for i in a.poles],"managed_project_ids":[str(i) for i in a.projects],
        "bureau": [{"id":str(u.id),"name":member_name(u)} for u in bureau],
        "poles": [{"id":str(x.id),"name":x.name} for x in poles],
        "projects": [{"id":str(x.id),"name":x.name} for x in projects],
        "seasons": [{"id":str(x.id),"name":x.name,"current":x.is_current} for x in db.query(Season).order_by(Season.start_date.desc()).all()],
        "courses": [{"id":str(x.id),"name":x.title} for x in db.query(AcademyCourse).filter(AcademyCourse.is_published.is_(True), AcademyCourse.is_archived.is_(False)).order_by(AcademyCourse.title).all()],
        "rules": [record(x) for x in db.query(VeilleRule).order_by(VeilleRule.created_at.desc()).all()],
        "settings": record(settings(db)) if a.decider else None}


def period_bounds(start, end):
    if end < start or (end-start).days > 366 or end>utc_now().date():
        fail(400, "Choisissez une période passée ou en cours, de 366 jours au maximum.")
    return datetime.combine(start,time.min), datetime.combine(end+timedelta(days=1),time.min)


def summary(db, user, start, end, pole_id=None, project_id=None, member_id=None, season_id=None):
    begin, stop = period_bounds(start,end)
    a = VeilleAccess(db,user)
    a.scope(pole_id,project_id,season_id)
    if member_id:
        a.require_member(member_id)
    q = a.task_query().filter(Task.created_at < stop)
    if pole_id: q=q.filter(Task.pole_id==pole_id)
    if project_id: q=q.filter(Task.project_id==project_id)
    if season_id:
        pids=db.query(Pole.id).filter(Pole.season_id==season_id)
        jids=db.query(Project.id).filter(Project.season_id==season_id)
        plan_ids=db.query(VeillePlan.id).filter(VeillePlan.season_id==season_id)
        q=q.filter(or_(Task.veille_season_id==season_id,and_(Task.veille_season_id.is_(None),or_(Task.pole_id.in_(pids),Task.project_id.in_(jids),Task.veille_plan_id.in_(plan_ids)))))
    if member_id:
        q=q.filter(Task.id.in_(db.query(TaskAssignee.task_id).filter(TaskAssignee.user_id==member_id)))
    tasks=q.order_by(Task.due_date,Task.created_at).all()
    ids={x.id for x in tasks}
    assignees={ident:[] for ident in ids}
    for tid,uid in db.query(TaskAssignee.task_id,TaskAssignee.user_id).filter(TaskAssignee.task_id.in_(ids)).all():
        assignees[tid].append(uid)
    leaves=db.query(VeilleLeave).filter(VeilleLeave.member_id.in_(a.member_ids),VeilleLeave.status=="approved",
        VeilleLeave.start_date<=end).all()
    def exempt(t,uid=None):
        if not t.due_date: return False
        members=[uid] if uid else assignees[t.id]
        return bool(members) and all(any(l.member_id==member and l.start_date<=t.due_date.date()<=l.end_date for l in leaves) for member in members)
    due=[t for t in tasks if t.status!="annule" and t.due_date and begin<=t.due_date<stop and not exempt(t)]
    accepted=[t for t in due if t.status=="valide" and t.validated_at and t.validated_at<stop]
    punctual=[t for t in accepted if t.completed_at and t.completed_at<=t.due_date]
    now=utc_now()
    late=[t for t in tasks if t.due_date and t.due_date<min(now,stop) and t.status not in TERMINAL_TASKS and not exempt(t)]
    awaiting=[t for t in tasks if t.status=="termine"]
    reviews=db.query(VeilleReview).filter(VeilleReview.task_id.in_(ids), VeilleReview.created_at>=begin,VeilleReview.created_at<stop).all()
    ratings=[r.quality for r in reviews if r.verdict=="accepted" and r.quality is not None]
    people=[]
    target_ids=({member_id} if member_id else a.member_ids)
    for u in db.query(User).filter(User.id.in_(target_ids),User.is_active.is_(True),User.status=="active").order_by(User.last_name,User.first_name).all():
        assigned=[t for t in tasks if u.id in assignees[t.id]]
        person_due=[t for t in assigned if t.status!="annule" and t.due_date and begin<=t.due_date<stop and not exempt(t,u.id)]
        person_accepted=[t for t in person_due if t in accepted]
        people.append({"id":str(u.id),"name":member_name(u),"assigned":len(assigned),"due":len(person_due),
            "accepted":len(person_accepted),"on_time":sum(t in punctual for t in person_accepted),
            "late":sum(t in late and not exempt(t,u.id) for t in assigned),
            "rate":round(100*len(person_accepted)/len(person_due),1) if person_due else None,
            "limited_sample":len(person_due)<3})
    blockers=db.query(VeilleBlocker).filter(VeilleBlocker.task_id.in_(ids),VeilleBlocker.status=="open").all()
    # Only compulsory, closed sessions in the viewer's operational perimeter count.
    aq=db.query(AttendanceExpectedMember,AttendanceSession).join(AttendanceSession,AttendanceSession.id==AttendanceExpectedMember.session_id).filter(
        AttendanceExpectedMember.user_id.in_(target_ids),AttendanceExpectedMember.is_required.is_(True),
        AttendanceSession.is_closed.is_(True), AttendanceSession.scheduled_at>=begin,AttendanceSession.scheduled_at<stop)
    if not a.full:
        aq=aq.filter(or_(AttendanceExpectedMember.user_id==user.id,
            AttendanceSession.pole_id.in_(a.poles),AttendanceSession.project_id.in_(a.projects)))
    if pole_id: aq=aq.filter(AttendanceSession.pole_id==pole_id)
    if project_id: aq=aq.filter(AttendanceSession.project_id==project_id)
    attendance_due=attendance_present=attendance_excused=0
    attendance_rows=aq.all()
    attendance_ids={session.id for _,session in attendance_rows}
    records={(r.session_id,r.user_id):r for r in db.query(AttendanceRecord).filter(AttendanceRecord.session_id.in_(attendance_ids),AttendanceRecord.user_id.in_(target_ids)).all()}
    for expected,session in attendance_rows:
        ar=records.get((session.id,expected.user_id))
        leave=any(l.member_id==expected.user_id and l.start_date<=session.scheduled_at.date()<=l.end_date for l in leaves)
        if leave or (ar and (ar.is_justified or ar.justification_status=="approved")):
            attendance_excused+=1
            continue
        attendance_due+=1
        if ar and ar.status in {"present","late","retard","en_retard"}: attendance_present+=1
    names={u.id:member_name(u) for u in db.query(User).filter(User.id.in_({i for values in assignees.values() for i in values})).all()}
    poles={x.id:x.name for x in db.query(Pole).all()}
    projects={x.id:x.name for x in db.query(Project).all()}
    task_rows=[]
    originals={}
    for e in db.query(VeilleEvent).filter(VeilleEvent.entity_type=="task",VeilleEvent.entity_id.in_(ids),VeilleEvent.action.in_(["created","baseline"])).order_by(VeilleEvent.created_at).all(): originals.setdefault(e.entity_id,e)
    for t in tasks:
        original=originals.get(t.id)
        original_due=(original.details.get("after",{}).get("due_date") if original else None)
        task_rows.append({**record(t),"assignees":[{"id":str(i),"name":names.get(i,"Membre")} for i in assignees[t.id]],
            "pole_name":poles.get(t.pole_id),"project_name":projects.get(t.project_id),
            "original_due_date":original_due,"late":t in late,"leave_exempt":exempt(t),"due_in_period":t in due,"accepted_in_period":t in accepted,
            "can_review":(user.id==(t.assigned_by or t.creator_id) or a.decider) and user.id not in assignees[t.id] and t.status=="termine",
            "can_change_deadline":a.full or t.pole_id in a.poles or t.project_id in a.projects or t.creator_id==user.id})
    group_rows=[]
    for kind,groups in (("pole",poles),("project",projects)):
        for ident,name in groups.items():
            selected=[t for t in tasks if (t.pole_id if kind=="pole" else t.project_id)==ident]
            if selected:
                group_rows.append({"kind":kind,"id":str(ident),"name":name,"tasks":len(selected),
                    "due":sum(t in due for t in selected),"accepted":sum(t in accepted for t in selected),
                    "late":sum(t in late for t in selected),"blocked":sum(b.task_id in {t.id for t in selected} for b in blockers)})
    return {"period_start":start.isoformat(),"period_end":end.isoformat(),"generated_at":json_value(now),
        "totals":{"tasks":len(tasks),"due":len(due),"accepted":len(accepted),"on_time":len(punctual),
            "late":len(late),"awaiting_review":len(awaiting),"blockers":len(blockers),
            "acceptance_rate":round(100*len(accepted)/len(due),1) if due else None,
            "quality":round(sum(ratings)/len(ratings),1) if ratings else None,"quality_samples":len(ratings),
            "attendance_due":attendance_due,"attendance_present":attendance_present,"attendance_excused":attendance_excused,
            "attendance_rate":round(100*attendance_present/attendance_due,1) if attendance_due else None},
        "tasks":task_rows,"members":people,"groups":group_rows,
        "method":"Les livrables acceptés sont rapportés aux tâches dues sur la période. La ponctualité utilise la date de remise, et non le délai de relecture. Les tâches annulées et les indisponibilités approuvées sont exclues. Les données décrivent l’état connu au moment du bilan ; elles ne reconstituent pas un historique antérieur non enregistré. Un faible effectif appelle une lecture prudente. Aucun score global ni sanction automatique n’est calculé."}


def create_plan(db,user,payload):
    a=VeilleAccess(db,user)
    a.require_member(payload.owner_id)
    a.scope(payload.pole_id,payload.project_id,payload.season_id,manage=payload.owner_id!=user.id)
    if payload.owner_id!=user.id and not a.coordinate: fail(403,"Vous pouvez définir vos propres engagements.")
    if payload.pole_id and not db.query(PoleMember).filter(PoleMember.pole_id==payload.pole_id,PoleMember.user_id==payload.owner_id,PoleMember.is_active.is_(True),PoleMember.left_at.is_(None)).first(): fail(400,"Le responsable doit appartenir au pôle choisi.")
    if payload.project_id and not db.query(ProjectMember).filter(ProjectMember.project_id==payload.project_id,ProjectMember.user_id==payload.owner_id,ProjectMember.is_active.is_(True),ProjectMember.left_at.is_(None)).first(): fail(400,"Le responsable doit appartenir au projet choisi.")
    due=to_naive_utc(payload.due_date)
    if due<=utc_now(): fail(400,"Choisissez une échéance future.")
    for ident in payload.course_ids:
        course=db.get(AcademyCourse,ident)
        if not course or not course.is_published or course.is_archived: fail(400,"Une formation choisie est indisponible.")
    data=payload.model_dump();data["due_date"]=due;data["course_ids"]=[str(i) for i in dict.fromkeys(payload.course_ids)]
    item=VeillePlan(**data,created_by_id=user.id)
    db.add(item);db.flush()
    event_log(db,user,"plan",item.id,"created","Engagement défini",{"due_date":json_value(due)})
    if item.owner_id!=user.id: notify(db,[item.owner_id],"Un engagement à préparer",item.title,"plan",item.id)
    return item


def create_action(db,user,payload):
    a=VeilleAccess(db,user)
    if not a.coordinate: fail(403,"La création des actions revient aux responsables du suivi.")
    a.require_member(payload.owner_id);a.scope(payload.pole_id,payload.project_id,payload.season_id,manage=True)
    for ident,model,field in ((payload.pole_id,PoleMember,"pole_id"),(payload.project_id,ProjectMember,"project_id")):
        if ident and not db.query(model).filter(getattr(model,field)==ident,model.user_id==payload.owner_id,model.is_active.is_(True),model.left_at.is_(None)).first(): fail(400,"Le responsable doit appartenir au périmètre choisi.")
    due=to_naive_utc(payload.due_date)
    if due<=utc_now(): fail(400,"Choisissez une échéance future.")
    if payload.plan_id:
        plan=get_record(db,VeillePlan,payload.plan_id)
        if not a.plan_query().filter(VeillePlan.id==plan.id).first(): fail(403,"Cet engagement n’est pas accessible.")
        if plan.status!="active" or plan.owner_id!=payload.owner_id or plan.pole_id!=payload.pole_id or plan.project_id!=payload.project_id or plan.season_id!=payload.season_id: fail(400,"L’action doit correspondre au responsable et au périmètre d’un engagement actif.")
        if due>plan.due_date: fail(400,"Ajustez d’abord l’engagement si cette action doit dépasser son échéance.")
    task=Task(title=payload.title,description=payload.description,creator_id=user.id,assigned_by=user.id,
        pole_id=payload.pole_id,project_id=payload.project_id,veille_plan_id=payload.plan_id,veille_season_id=payload.season_id,
        priority=payload.priority,status="a_faire",due_date=due,proof_required=payload.proof_required)
    db.add(task);db.flush();db.add(TaskAssignee(task_id=task.id,user_id=payload.owner_id));db.flush()
    notify(db,[payload.owner_id],"Une action vous est confiée",task.title,"task",task.id)
    return task


def change_plan(db,user,item,payload):
    a=VeilleAccess(db,user)
    if not a.plan_query().filter(VeillePlan.id==item.id).first(): fail(403,"Cet engagement ne vous est pas accessible.")
    if item.owner_id!=user.id and not a.coordinate: fail(403,"Cette action revient au responsable du suivi.")
    require_version(item,payload.version)
    from app.schemas.veille import PlanCreate
    validated=PlanCreate(**payload.model_dump(exclude={"version","reason","status"}))
    if not a.coordinate:
        structural_change=(validated.owner_id!=item.owner_id or validated.pole_id!=item.pole_id or
            validated.project_id!=item.project_id or validated.season_id!=item.season_id or
            validated.title!=item.title or validated.expected_result!=item.expected_result or
            to_naive_utc(validated.due_date)!=item.due_date or
            set(map(str,validated.course_ids))!=set(item.course_ids) or payload.status=="cancelled")
        if structural_change: fail(403,"Le responsable du suivi doit approuver une modification du résultat, de l’échéance, des formations ou du périmètre.")
    # Reuse all membership/course checks, without creating a second commitment.
    a.require_member(validated.owner_id);a.scope(validated.pole_id,validated.project_id,validated.season_id,manage=validated.owner_id!=user.id)
    if validated.owner_id!=item.owner_id and item.owner_id==user.id and not a.coordinate: fail(403,"Un responsable doit approuver la réaffectation.")
    for pid,model,field in ((validated.pole_id,PoleMember,"pole_id"),(validated.project_id,ProjectMember,"project_id")):
        if pid and not db.query(model).filter(getattr(model,field)==pid,model.user_id==validated.owner_id,model.is_active.is_(True),model.left_at.is_(None)).first(): fail(400,"Le responsable doit appartenir au périmètre choisi.")
    for cid in validated.course_ids:
        c=db.get(AcademyCourse,cid)
        if not c or not c.is_published or c.is_archived: fail(400,"Une formation choisie est indisponible.")
    if payload.status=="completed":
        if db.query(Task).filter(Task.veille_plan_id==item.id,Task.status.notin_({"valide","annule"})).first(): fail(409,"Les actions liées doivent être acceptées avant de terminer cet engagement.")
        from app.services.academy_progression import LearningAccess
        access=LearningAccess(db,validated.owner_id)
        if any(not access.mastered(cid) for cid in validated.course_ids): fail(409,"Les formations assignées doivent être réussies avant de terminer cet engagement.")
    before={"owner_id":str(item.owner_id),"due_date":json_value(item.due_date),"status":item.status}
    data=validated.model_dump();data["due_date"]=to_naive_utc(validated.due_date);data["course_ids"]=[str(i) for i in dict.fromkeys(validated.course_ids)]
    for key,value in data.items(): setattr(item,key,value)
    item.status=payload.status;item.version+=1;item.updated_at=utc_now()
    event_log(db,user,"plan",item.id,"changed",payload.reason,{"before":before,"after":{"owner_id":str(item.owner_id),"due_date":json_value(item.due_date),"status":item.status}})
    notify(db,[item.owner_id],"Engagement mis à jour",payload.reason,"plan",item.id)
    return item


def create_blocker(db,user,payload):
    a=VeilleAccess(db,user);task=a.task(payload.task_id,locked=True);a.require_member(payload.owner_id)
    if task.status in {"termine","valide","annule"}: fail(409,"Cette tâche n’est plus en cours de réalisation.")
    if db.query(VeilleBlocker).filter(VeilleBlocker.task_id==task.id,VeilleBlocker.status=="open").first(): fail(409,"Un blocage est déjà ouvert pour cette tâche. Mettez-le à jour.")
    if to_naive_utc(payload.review_at)<=utc_now(): fail(400,"Choisissez une prochaine date de revue.")
    data=payload.model_dump();data["review_at"]=to_naive_utc(payload.review_at)
    item=VeilleBlocker(**data,created_by_id=user.id);db.add(item);db.flush()
    task.status="bloque";task.updated_at=utc_now()
    event_log(db,user,"blocker",item.id,"created",payload.description)
    notify(db,[item.owner_id,task.creator_id] if task.creator_id else [item.owner_id],"Une aide est attendue",item.title,"blocker",item.id)
    return item


def change_blocker(db,user,item,payload):
    a=VeilleAccess(db,user)
    if item.task_id: a.task(item.task_id,locked=True)
    elif not a.full and item.created_by_id!=user.id and item.owner_id!=user.id: fail(403,"Ce blocage ne vous est pas accessible.")
    if not a.coordinate and user.id not in {item.created_by_id,item.owner_id}: fail(403,"Cette action revient au responsable du blocage.")
    require_version(item,payload.version);a.require_member(payload.owner_id)
    if item.status=="resolved": fail(409,"Ce blocage est déjà résolu.")
    if payload.status=="resolved" and not payload.resolution: fail(400,"Expliquez comment le blocage a été résolu.")
    if payload.status=="open" and to_naive_utc(payload.review_at)<=utc_now(): fail(400,"Choisissez une prochaine date de revue.")
    for key,value in payload.model_dump(exclude={"version"}).items(): setattr(item,key,to_naive_utc(value) if key=="review_at" else value)
    item.version+=1
    if item.status=="resolved":
        item.resolved_at=utc_now()
        task=db.get(Task,item.task_id) if item.task_id else None
        if task and task.status=="bloque": task.status="en_cours";task.updated_at=utc_now()
    event_log(db,user,"blocker",item.id,"resolved" if item.status=="resolved" else "changed",payload.resolution or payload.next_action)
    return item


def review_task(db,user,ident,payload):
    a=VeilleAccess(db,user);task=a.task(ident,manage=True,locked=True)
    from app.api.routes.tasks import ensure_independent_reviewer
    ensure_independent_reviewer(db,task,user)
    if to_naive_utc(payload.expected_updated_at)!=task.updated_at: fail(409,"La tâche a changé. Actualisez-la avant la relecture.")
    if task.status!="termine": fail(409,"La tâche doit être remise avant sa relecture.")
    if task.proof_required and not task.proof_url: fail(400,"Le justificatif attendu n’a pas été fourni.")
    from app.api.routes.tasks import apply_task_status,task_assignee_user_ids
    submitted=task.completed_at
    apply_task_status(task,"valide" if payload.verdict=="accepted" else "en_cours",is_manager=True,actor_id=user.id)
    item=VeilleReview(task_id=task.id,task_title=task.title,verdict=payload.verdict,feedback=payload.feedback,quality=payload.quality,submitted_at=submitted,created_by_id=user.id)
    db.add(item);db.flush()
    event_log(db,user,"task",task.id,"review_"+payload.verdict,payload.feedback,{"quality":payload.quality,"submitted_at":json_value(submitted)})
    notify(db,task_assignee_user_ids(db,task),"Livrable accepté" if payload.verdict=="accepted" else "Livrable à reprendre",payload.feedback,"task",task.id)
    return item


def change_deadline(db,user,ident,payload):
    task=VeilleAccess(db,user).task(ident,manage=True,locked=True)
    if task.status in TERMINAL_TASKS: fail(409,"L’échéance d’une tâche remise ou clôturée ne peut plus être changée.")
    if to_naive_utc(payload.expected_updated_at)!=task.updated_at: fail(409,"Cette tâche a changé. Actualisez-la.")
    due=to_naive_utc(payload.due_date)
    if due<=utc_now(): fail(400,"Choisissez une nouvelle échéance future.")
    previous=task.due_date;task.due_date=due;task.updated_at=utc_now();task.is_late_alert_sent=False
    event_log(db,user,"task",task.id,"deadline_changed",payload.reason,{"previous_due_date":json_value(previous),"due_date":json_value(due)})
    ids=[r[0] for r in db.query(TaskAssignee.user_id).filter(TaskAssignee.task_id==task.id).all()]
    notify(db,ids,"Échéance ajustée",payload.reason,"task",task.id)
    return task


def create_report(db,user,payload):
    a=VeilleAccess(db,user)
    if not a.coordinate: fail(403,"La préparation des bilans revient aux responsables du suivi.")
    a.scope(payload.pole_id,payload.project_id,payload.season_id,manage=True)
    snap=summary(db,user,payload.period_start,payload.period_end,payload.pole_id,payload.project_id,season_id=payload.season_id)
    item=VeilleReport(**payload.model_dump(),snapshot=snap,created_by_id=user.id)
    db.add(item);db.flush();event_log(db,user,"report",item.id,"created","Bilan enregistré")
    return item


def create_leave(db,user,payload):
    a=VeilleAccess(db,user);a.require_member(payload.member_id)
    if payload.end_date<utc_now().date(): fail(400,"Une indisponibilité passée ne peut pas être créée rétroactivement.")
    item=VeilleLeave(**payload.model_dump(),created_by_id=user.id);db.add(item);db.flush()
    event_log(db,user,"leave",item.id,"requested","Indisponibilité signalée")
    from app.services.veille_scheduler import coordinator_ids
    ids=coordinator_ids(db)
    pole_ids=db.query(PoleMember.pole_id).filter(PoleMember.user_id==payload.member_id,PoleMember.is_active.is_(True),PoleMember.left_at.is_(None))
    project_ids=db.query(ProjectMember.project_id).filter(ProjectMember.user_id==payload.member_id,ProjectMember.is_active.is_(True),ProjectMember.left_at.is_(None))
    ids.update(row[0] for row in db.query(PoleMember.user_id).filter(PoleMember.pole_id.in_(pole_ids),PoleMember.position.in_({"chef_pole","adjoint_chef_pole"}),PoleMember.is_active.is_(True),PoleMember.left_at.is_(None)).all())
    ids.update(row[0] for row in db.query(ProjectMember.user_id).filter(ProjectMember.project_id.in_(project_ids),ProjectMember.position.in_({"chef_projet","adjoint_chef_projet"}),ProjectMember.is_active.is_(True),ProjectMember.left_at.is_(None)).all())
    notify(db,ids,"Indisponibilité à examiner",member_name(a.require_member(payload.member_id)),"leave",item.id)
    return item


def change_leave(db,user,item,payload):
    a=VeilleAccess(db,user);a.require_member(item.member_id);require_version(item,payload.version)
    if payload.status=="cancelled":
        if not a.coordinate and user.id!=item.member_id: fail(403,"Cette action ne vous est pas autorisée.")
    elif not a.coordinate or user.id==item.member_id:
        fail(403,"Un autre responsable doit examiner l’indisponibilité.")
    if item.status in {"rejected","cancelled"}: fail(409,"Cette demande est clôturée.")
    item.status=payload.status;item.response=payload.response;item.reviewed_by_id=user.id;item.version+=1
    event_log(db,user,"leave",item.id,payload.status,payload.response)
    notify(db,[item.member_id],"Indisponibilité mise à jour",payload.response,"leave",item.id)
    return item


def create_case(db,user,payload):
    a=VeilleAccess(db,user)
    if not a.coordinate: fail(403,"L’ouverture d’un dossier revient à Veille ou au responsable du périmètre.")
    a.require_member(payload.member_id)
    if payload.member_id==user.id: fail(403,"Un autre responsable doit préparer un dossier qui vous concerne.")
    if payload.observed_at>utc_now().date(): fail(400,"La date des faits ne peut pas être future.")
    if payload.task_id:
        a.task(payload.task_id,manage=True)
        if not db.query(TaskAssignee).filter(TaskAssignee.task_id==payload.task_id,TaskAssignee.user_id==payload.member_id).first(): fail(400,"Le membre doit être assigné à la tâche concernée.")
    if payload.attendance_id:
        ar=db.get(AttendanceRecord,payload.attendance_id)
        if not ar or ar.user_id!=payload.member_id: fail(400,"La présence ne correspond pas au membre concerné.")
        sess=db.get(AttendanceSession,ar.session_id)
        if not a.full: a.scope(sess.pole_id,sess.project_id,manage=True)
        if not a.full and not (sess.pole_id in a.poles or sess.project_id in a.projects): fail(403,"Cette présence ne relève pas de votre périmètre.")
    if payload.rule_id:
        rule=get_record(db,VeilleRule,payload.rule_id)
        if rule.retired: fail(400,"Cette règle a été remplacée. Choisissez une règle en vigueur.")
    if payload.bureau_reviewer_id:
        reviewer=db.get(User,payload.bureau_reviewer_id)
        if not reviewer or not reviewer.is_active or reviewer.status!="active" or reviewer.id not in enacchef_ids(db) or reviewer.id==payload.member_id: fail(400,"Choisissez un membre d’EnacChef distinct de la personne concernée.")
    item=VeilleCase(**payload.model_dump(),created_by_id=user.id);db.add(item);db.flush()
    event_log(db,user,"case",item.id,"created","Dossier préparé")
    return item


def validate_outcome(db,item,outcome,amount,now):
    if not outcome: fail(400,"Précisez l’action proposée.")
    rule=db.get(VeilleRule,item.rule_id) if item.rule_id else None
    if outcome not in SUPPORT_ACTIONS:
        if not rule or outcome not in rule.allowed_actions: fail(400,"Cette mesure exige une règle adoptée qui l’autorise explicitement.")
        if rule.effective_from>item.observed_at or rule.effective_from>now.date(): fail(400,"Cette règle ne peut pas être appliquée rétroactivement aux faits concernés.")
    if outcome=="penalite_financiere":
        if not amount or amount>float(rule.maximum_amount): fail(400,"Le montant doit respecter la limite prévue par la règle.")
        if item.attendance_id:
            existing=db.query(Fee).filter(Fee.related_attendance_id==item.attendance_id).first()
            if existing and existing.status=="cancelled": fail(409,"La pénalité de cette présence a été annulée. Le financier doit examiner ce rapprochement avant une nouvelle décision.")
            if existing and float(existing.amount)!=amount: fail(409,"Une pénalité existe déjà pour cette présence. Le financier doit la rapprocher avant toute décision différente.")
    elif amount:
        fail(400,"Un montant ne concerne qu’une pénalité financière.")


def act_case(db,user,item,payload,now=None):
    now=now or utc_now();a=VeilleAccess(db,user)
    if not a.can_case(item): fail(403,"Ce dossier est confidentiel.")
    require_version(item,payload.version)
    action=payload.action;coordinator=(a.veille or a.decider or item.created_by_id==user.id) and user.id!=item.member_id
    subject=user.id==item.member_id
    if item.status=="closed": fail(409,"Ce dossier est clôturé.")
    if action=="notify":
        if not coordinator or item.status!="draft": fail(403,"Ce dossier ne peut pas être notifié par cette action.")
        item.status="notified";item.response_deadline=now+timedelta(days=settings(db).response_days)
    elif action=="respond":
        if not subject or item.status not in {"notified","response_received"}: fail(403,"La réponse revient au membre concerné après notification.")
        item.status="response_received"
    elif action in {"propose","propose_review"}:
        valid={"response_received","notified","proposed"} if action=="propose" else {"appealed","review_proposed"}
        if not coordinator or item.status not in valid: fail(403,"Le dossier n’est pas prêt pour une proposition.")
        if item.status=="notified" and item.response_deadline and now<item.response_deadline: fail(409,"Le membre dispose encore d’un délai pour répondre.")
        validate_outcome(db,item,payload.outcome,payload.amount,now)
        item.proposed_action=payload.outcome;item.proposal=payload.message;item.amount=payload.amount
        item.endorsement=None;item.endorsed_by_id=None
        item.status="proposed" if action=="propose" else "review_proposed"
    elif action=="endorse":
        if user.id!=item.bureau_reviewer_id or user.id not in enacchef_ids(db) or subject or item.status not in {"proposed","review_proposed"}: fail(403,"L’avis revient au membre d’EnacChef désigné.")
        item.endorsement=payload.message;item.endorsed_by_id=user.id
    elif action in {"decide","review_decide"}:
        valid="proposed" if action=="decide" else "review_proposed"
        if not a.decider or subject or item.status!=valid: fail(403,"La décision revient au Team Leader ou à l’administration, hors conflit personnel.")
        if not item.endorsement or not item.endorsed_by_id or item.endorsed_by_id==user.id: fail(409,"Un avis distinct d’EnacChef est nécessaire avant la décision.")
        validate_outcome(db,item,payload.outcome,payload.amount,now)
        if payload.outcome!=item.proposed_action or payload.amount!=int(item.amount or 0): fail(409,"La décision doit porter sur la proposition examinée par EnacChef. Préparez une nouvelle proposition pour la modifier.")
        item.decision_action=payload.outcome;item.decision=payload.message;item.amount=payload.amount
        item.decided_by_id=user.id;item.decided_at=now;item.appeal_until=now+timedelta(days=settings(db).appeal_days)
        item.accepted_at=None;item.status="decided" if action=="decide" else "reviewed"
    elif action=="appeal":
        if not subject or item.status!="decided" or item.appeal_count>=1 or not item.appeal_until or now>item.appeal_until: fail(409,"Le délai ou les conditions de réexamen ne permettent plus cette demande.")
        item.appeal_count+=1;item.status="appealed";item.endorsement=None;item.endorsed_by_id=None;item.accepted_at=None
    elif action=="accept":
        if not subject or item.status not in {"decided","reviewed"}: fail(403,"L’acceptation revient au membre concerné après décision.")
        item.accepted_at=now
    elif action=="close":
        if not a.decider or subject or item.status not in {"decided","reviewed"}: fail(403,"Ce dossier ne peut pas encore être clôturé.")
        if not item.accepted_at and item.appeal_until and now<item.appeal_until: fail(409,"Attendez l’acceptation du membre ou la fin du délai de réexamen.")
        if item.decision_action=="penalite_financiere":
            from app.api.routes.finance import create_fee_record
            lock_row(db,User,str(item.member_id))  # Serialise monetary closures for the same account.
            validate_outcome(db,item,item.decision_action,int(item.amount),now)
            previous=db.query(VeilleCase).filter(VeilleCase.id!=item.id,VeilleCase.member_id==item.member_id,
                VeilleCase.task_id==item.task_id,VeilleCase.observed_at==item.observed_at,VeilleCase.status=="closed",
                VeilleCase.decision_action=="penalite_financiere",VeilleCase.fee_id.isnot(None)).first() if item.task_id else None
            if previous:
                fee=db.get(Fee,previous.fee_id)
                if not fee or fee.status=="cancelled" or float(fee.amount)!=float(item.amount): fail(409,"Une pénalité existe déjà pour ces faits. Le financier doit examiner ce rapprochement.")
            else:
                fee=create_fee_record(db,user_id=item.member_id,current_user=user,fee_type="manual_penalty",category="Décision Veille",
                    label=item.title,description=item.decision,amount=float(item.amount),currency="FCFA",source_type="veille_case",source_id=item.id,
                    related_attendance_id=item.attendance_id,due_date=(now+timedelta(days=14)).date())
            item.fee_id=fee.id
        item.status="closed"
    elif action=="comment":
        if subject and item.status=="draft": fail(403,"Le dossier n’a pas encore été notifié.")
    else: fail(400,"Action inconnue.")
    item.version+=1
    event_log(db,user,"case",item.id,action,payload.message,{"status":item.status,"outcome":payload.outcome,"amount":payload.amount})
    if item.status!="draft":
        ids={item.member_id,item.created_by_id,item.bureau_reviewer_id}
        if action in {"propose","propose_review","appeal"}:
            ids.update(role_user_ids(db,DECIDERS))
        notify(db,[i for i in ids if i and i!=user.id],"Dossier de suivi mis à jour",item.title,"case",item.id)
    return item


def case_actions(db,user,item):
    a=VeilleAccess(db,user);now=utc_now();actions=[]
    if item.status=="closed": return actions
    subject=user.id==item.member_id
    coordinator=(a.veille or a.decider or item.created_by_id==user.id) and not subject
    if coordinator and item.status=="draft": actions.append("notify")
    if subject and item.status in {"notified","response_received"}: actions.append("respond")
    if coordinator and (item.status in {"response_received","proposed"} or (item.status=="notified" and item.response_deadline and now>=item.response_deadline)): actions.append("propose")
    if coordinator and item.status in {"appealed","review_proposed"}: actions.append("propose_review")
    if user.id==item.bureau_reviewer_id and user.id in enacchef_ids(db) and not subject and item.status in {"proposed","review_proposed"}: actions.append("endorse")
    if a.decider and not subject and item.endorsement and item.endorsed_by_id!=user.id:
        if item.status=="proposed": actions.append("decide")
        if item.status=="review_proposed": actions.append("review_decide")
    if subject and item.status=="decided" and item.appeal_count<1 and item.appeal_until and now<=item.appeal_until: actions.append("appeal")
    if subject and item.status in {"decided","reviewed"}: actions.append("accept")
    if a.decider and not subject and item.status in {"decided","reviewed"} and (item.accepted_at or (item.appeal_until and now>=item.appeal_until)): actions.append("close")
    if item.status!="draft" or not subject: actions.append("comment")
    return actions
