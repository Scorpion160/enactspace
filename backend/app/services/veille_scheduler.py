"""One transactional reminder ledger: reading a notification does not re-send it."""
from datetime import datetime, time, timedelta
from sqlalchemy import text

from app.core.time import utc_now
from app.core.roles import is_veille_pole_name
from app.models.user import User
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.task import Task, TaskAssignee
from app.models.veille import VeilleReminder, VeilleLeave, VeilleReport
from app.services.notification_service import notify_user
from app.services.veille_service import settings, summary, DECIDERS, GLOBAL_COORDINATORS, VEILLE_ROLES, role_user_ids


def quiet(hour,start,end):
    if start==end: return False
    return start<=hour<end if start<end else hour>=start or hour<end


def coordinator_ids(db):
    ids=role_user_ids(db,GLOBAL_COORDINATORS|VEILLE_ROLES)
    from app.models.pole import Pole
    ids.update(uid for uid,name in db.query(PoleMember.user_id,Pole.name).join(Pole,Pole.id==PoleMember.pole_id).filter(
        PoleMember.is_active.is_(True),PoleMember.left_at.is_(None)).all() if is_veille_pole_name(name))
    return ids


def run_cycle(db,now=None):
    now=now or utc_now()
    if db.bind.dialect.name=="postgresql":
        # Serialise scheduler replicas; the unique ledger also guards each delivery.
        if not db.execute(text("SELECT pg_try_advisory_xact_lock(24400222026)")).scalar(): return {"reminders":0,"reports":0,"busy":True}
    config=settings(db)
    if quiet(now.hour,config.quiet_start_hour,config.quiet_end_hour):
        db.commit();return {"reminders":0,"reports":0,"quiet":True}
    sent=reports=0
    if config.reminders_enabled:
        tasks=db.query(Task).filter(Task.due_date.isnot(None),Task.due_date>=config.effective_at,
            Task.due_date<=now+timedelta(days=4),Task.status.notin_({"termine","valide","annule"})).with_for_update().all()
        active={u.id for u in db.query(User).filter(User.is_active.is_(True),User.status=="active").all()}
        for task in tasks:
            days=(task.due_date.date()-now.date()).days
            kind="three_days" if days==3 else "one_day" if days==1 else "today" if days==0 else "late" if days<0 and -days<config.escalation_days else "escalation" if days<0 else None
            if not kind: continue
            assignees={r[0] for r in db.query(TaskAssignee.user_id).filter(TaskAssignee.task_id==task.id).all()}
            leaves=db.query(VeilleLeave).filter(VeilleLeave.member_id.in_(assignees),VeilleLeave.status=="approved",
                VeilleLeave.start_date<=task.due_date.date(),VeilleLeave.end_date>=task.due_date.date()).all()
            exempt={l.member_id for l in leaves}
            recipients=assignees-exempt
            if not recipients and assignees: continue
            if kind=="escalation":
                recipients=coordinator_ids(db) | ({task.creator_id} if task.creator_id else set())
                recipients.update(r[0] for r in db.query(PoleMember.user_id).filter(PoleMember.pole_id==task.pole_id,PoleMember.position.in_({"chef_pole","adjoint_chef_pole"}),PoleMember.is_active.is_(True),PoleMember.left_at.is_(None)).all() if task.pole_id)
                recipients.update(r[0] for r in db.query(ProjectMember.user_id).filter(ProjectMember.project_id==task.project_id,ProjectMember.position.in_({"chef_projet","adjoint_chef_projet"}),ProjectMember.is_active.is_(True),ProjectMember.left_at.is_(None)).all() if task.project_id)
            for uid in recipients & active:
                existing=db.query(VeilleReminder.id).filter(VeilleReminder.task_id==task.id,VeilleReminder.recipient_id==uid,
                    VeilleReminder.due_date==task.due_date,VeilleReminder.kind==kind).first()
                if existing: continue
                title="Une échéance à préparer" if days>0 else "Échéance aujourd’hui" if days==0 else "Une tâche appelle un suivi"
                due=task.due_date.strftime("%d/%m/%Y à %H:%M UTC")
                notify_user(db,user_id=uid,title=title,message=f"{task.title} — échéance convenue : {due}. Consultez la tâche et partagez un blocage si une aide est nécessaire.",
                    notification_type="veille_deadline",related_type="veille_task",related_id=task.id,dedupe=False)
                db.add(VeilleReminder(task_id=task.id,recipient_id=uid,due_date=task.due_date,kind=kind,created_at=now))
                sent+=1
    if config.auto_reports and now.hour>=config.report_hour:
        periods=[]
        # Catch up the latest due report after downtime, without flooding old periods.
        weekly_anchor=now.date()-timedelta(days=(now.weekday()-config.weekly_day)%7)
        end=weekly_anchor-timedelta(days=1)
        periods.append(("weekly",max(end-timedelta(days=6),config.effective_at.date()),end))
        end=now.date().replace(day=1)-timedelta(days=1)
        periods.append(("monthly",max(end.replace(day=1),config.effective_at.date()),end))
        leader=db.query(User).filter(User.id.in_(role_user_ids(db,DECIDERS)),User.is_active.is_(True),User.status=="active").order_by(User.created_at).first()
        for kind,start,end in periods:
            key=f"{kind}:{start}:{end}"
            if not leader or end<config.effective_at.date() or db.query(VeilleReport).filter(VeilleReport.automatic_key==key).first(): continue
            snapshot=summary(db,leader,start,end)
            item=VeilleReport(title="Point hebdomadaire" if kind=="weekly" else "Bilan mensuel",kind=kind,period_start=start,period_end=end,
                observations="Ce bilan rassemble les engagements et les livrables connus à sa préparation. Complétez le point de suivi avec les explications de l’équipe.",
                next_actions="Ouvrir les tâches en attente de relecture, traiter les blocages et convenir des prochaines actions avec les responsables.",
                snapshot=snapshot,automatic_key=key,created_at=now)
            db.add(item);db.flush()
            for uid in coordinator_ids(db):
                if db.query(User.id).filter(User.id==uid,User.is_active.is_(True),User.status=="active").first():
                    notify_user(db,user_id=uid,title="Le point de suivi est prêt",message=f"{item.title} : du {start:%d/%m/%Y} au {end:%d/%m/%Y}.",
                        notification_type="veille_report",related_type="veille_report",related_id=item.id,dedupe=False)
            reports+=1
    db.commit()
    return {"reminders":sent,"reports":reports}
