import csv
import io
import uuid
from datetime import date, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user
from app.core.time import utc_now
from app.db.database import get_db
from app.models.user import User
from app.models.task import Task
from app.models.veille import (VeilleSettings, VeilleRule, VeillePlan, VeilleBlocker,
    VeilleReview, VeilleReport, VeilleLeave, VeilleCase, VeilleEvent)
from app.schemas.veille import (PlanCreate, PlanChange, ActionCreate, BlockerCreate, BlockerChange,
    ReviewCreate, ReportCreate, LeaveCreate, LeaveChange, CaseCreate, CaseAction,
    RuleCreate, SettingsChange, DeadlineChange)
from app.services import veille_service as service
from app.services.audit_service import create_audit_log

router=APIRouter(prefix="/veille",tags=["Pôle Veille"])


def active(user):
    if user.status!="active":
        raise HTTPException(403,"Le suivi Veille est réservé aux membres actifs.")
    return user


def finish(db,item):
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409,"Une modification concurrente empêche cet enregistrement. Actualisez puis réessayez.") from exc
    db.refresh(item)
    return service.record(item)


@router.get("/context")
def get_context(db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return service.context(db,active(user))


@router.get("/summary")
def get_summary(start:date|None=None,end:date|None=None,pole_id:uuid.UUID|None=None,
    project_id:uuid.UUID|None=None,member_id:uuid.UUID|None=None,season_id:uuid.UUID|None=None,
    db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    today=utc_now().date()
    return service.summary(db,active(user),start or today-timedelta(days=today.weekday()),end or today,
        pole_id,project_id,member_id,season_id)


@router.get("/records")
def get_records(db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    a=service.VeilleAccess(db,active(user))
    tasks=a.task_query().with_entities(Task.id)
    blockers=db.query(VeilleBlocker)
    if not a.full:
        blockers=blockers.filter(or_(VeilleBlocker.task_id.in_(tasks),VeilleBlocker.owner_id==user.id,VeilleBlocker.created_by_id==user.id))
    names={x.id:service.member_name(x) for x in db.query(User).filter(User.id.in_(a.member_ids)).all()}
    def rows(q):
        out=[]
        for item in q.order_by(q.column_descriptions[0]["entity"].created_at.desc()).all():
            data=service.record(item)
            owner=getattr(item,"owner_id",getattr(item,"member_id",None))
            if owner:
                if owner not in names:
                    person=db.get(User,owner);names[owner]=service.member_name(person) if person else "Membre"
                data["member_name"]=names[owner]
            if isinstance(item,VeilleBlocker) and item.task_id:
                task=db.get(Task,item.task_id);data["task_title"]=task.title if task else "Tâche archivée"
            out.append(data)
        return out
    return {"plans":rows(a.plan_query()),"blockers":rows(blockers),"reports":rows(a.report_query()),
        "leaves":rows(db.query(VeilleLeave).filter(VeilleLeave.member_id.in_(a.member_ids))),"cases":rows(a.case_query())}


MODELS={"plan":VeillePlan,"blocker":VeilleBlocker,"report":VeilleReport,"leave":VeilleLeave,"case":VeilleCase}


def visible_record(db,user,kind,ident,locked=False):
    active(user);a=service.VeilleAccess(db,user)
    if kind not in MODELS: raise HTTPException(404,"Type de dossier introuvable.")
    item=service.get_record(db,MODELS[kind],ident,locked)
    if kind=="case" and not a.can_case(item): raise HTTPException(403,"Ce dossier est confidentiel.")
    if kind=="plan" and not a.plan_query().filter(VeillePlan.id==ident).first(): raise HTTPException(403,"Cet engagement ne vous est pas accessible.")
    if kind=="report" and not a.report_query().filter(VeilleReport.id==ident).first(): raise HTTPException(403,"Ce bilan ne vous est pas accessible.")
    if kind=="leave": a.require_member(item.member_id)
    if kind=="blocker":
        if item.task_id: a.task(item.task_id)
        elif not a.full and user.id not in {item.owner_id,item.created_by_id}: raise HTTPException(403,"Ce blocage ne vous est pas accessible.")
    return item


def events(db,kind,ident):
    out=[]
    for row in db.query(VeilleEvent).filter(VeilleEvent.entity_type==kind,VeilleEvent.entity_id==ident).order_by(VeilleEvent.created_at,VeilleEvent.id).all():
        data=service.record(row);actor=db.get(User,row.created_by_id) if row.created_by_id else None
        data["actor_name"]=service.member_name(actor) if actor else "EnactSpace"
        out.append(data)
    return out


@router.get("/records/{kind}/{ident}")
def get_detail(kind:str,ident:uuid.UUID,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    item=visible_record(db,user,kind,ident)
    result=service.record(item);result["events"]=events(db,kind,ident)
    owner=getattr(item,"owner_id",getattr(item,"member_id",None))
    if owner:
        person=db.get(User,owner);result["member_name"]=service.member_name(person) if person else "Membre"
    if kind=="plan":
        result["tasks"]=[service.record(x) for x in db.query(Task).filter(Task.veille_plan_id==item.id).order_by(Task.created_at).all()]
        from app.models.academy import AcademyCourse
        from app.services.academy_progression import LearningAccess
        access=LearningAccess(db,item.owner_id)
        result["assigned_courses"]=[]
        for cid in item.course_ids:
            course=db.get(AcademyCourse,uuid.UUID(cid))
            if course:
                result["assigned_courses"].append({"id":cid,"title":course.title,**access.describe(course)})
    if kind=="case":
        result["available_actions"]=service.case_actions(db,user,item)
        rule=db.get(VeilleRule,item.rule_id) if item.rule_id else None
        result["rule"]=service.record(rule) if rule else None
        reviewer=db.get(User,item.bureau_reviewer_id) if item.bureau_reviewer_id else None
        result["bureau_reviewer_name"]=service.member_name(reviewer) if reviewer else None
    if kind=="blocker" and item.task_id:
        task=db.get(Task,item.task_id);result["task_title"]=task.title if task else "Tâche archivée"
    return result


@router.get("/tasks/{ident}")
def get_task_detail(ident:uuid.UUID,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    a=service.VeilleAccess(db,active(user));task=a.task(ident)
    from app.models.task import TaskAssignee,TaskChecklistItem,TaskComment
    from app.api.routes.tasks import task_payload
    result=service.record(task)
    permissions=task_payload(db,task,user)
    result.update({"can_manage":permissions["can_manage"],"current_user_assigned":permissions["current_user_assigned"]})
    members=db.query(User).join(TaskAssignee,TaskAssignee.user_id==User.id).filter(TaskAssignee.task_id==ident).all()
    result["assignees"]=[{"id":str(u.id),"name":service.member_name(u)} for u in members]
    result["can_review"]=permissions["can_validate"] and task.status=="termine"
    result["proof_filename"]=permissions.get("proof_filename")
    result["can_change_deadline"]=(a.full or result["can_manage"]) and task.status not in service.TERMINAL_TASKS
    result["events"]=events(db,"task",ident)
    result["checklist"]=[service.record(x) for x in db.query(TaskChecklistItem).filter(TaskChecklistItem.task_id==ident).all()]
    result["comments"]=[]
    for comment,author in db.query(TaskComment,User).join(User,User.id==TaskComment.user_id).filter(TaskComment.task_id==ident).order_by(TaskComment.created_at).all():
        result["comments"].append({**service.record(comment),"author_name":service.member_name(author)})
    return result


@router.post("/tasks")
def post_action(payload:ActionCreate,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return finish(db,service.create_action(db,active(user),payload))


@router.get("/tasks/{ident}/history")
def get_task_history(ident:uuid.UUID,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    service.VeilleAccess(db,active(user)).task(ident)
    return {"events":events(db,"task",ident),"reviews":[service.record(x) for x in db.query(VeilleReview).filter(VeilleReview.task_id==ident).order_by(VeilleReview.created_at).all()]}


@router.post("/plans")
def post_plan(payload:PlanCreate,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return finish(db,service.create_plan(db,active(user),payload))


@router.patch("/plans/{ident}")
def patch_plan(ident:uuid.UUID,payload:PlanChange,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    item=visible_record(db,user,"plan",ident,True)
    return finish(db,service.change_plan(db,user,item,payload))


@router.post("/blockers")
def post_blocker(payload:BlockerCreate,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return finish(db,service.create_blocker(db,active(user),payload))


@router.patch("/blockers/{ident}")
def patch_blocker(ident:uuid.UUID,payload:BlockerChange,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    item=visible_record(db,user,"blocker",ident,True)
    return finish(db,service.change_blocker(db,user,item,payload))


@router.post("/tasks/{ident}/reviews")
def post_review(ident:uuid.UUID,payload:ReviewCreate,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return finish(db,service.review_task(db,active(user),ident,payload))


@router.post("/tasks/{ident}/deadline")
def post_deadline(ident:uuid.UUID,payload:DeadlineChange,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return finish(db,service.change_deadline(db,active(user),ident,payload))


@router.post("/reports")
def post_report(payload:ReportCreate,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return finish(db,service.create_report(db,active(user),payload))


@router.get("/reports/{ident}/export")
def export_report(ident:uuid.UUID,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    item=visible_record(db,user,"report",ident)
    output=io.StringIO();writer=csv.writer(output,delimiter=";")
    def cell(value):
        text="" if value is None else str(value)
        return "'"+text if text.lstrip().startswith(("=","+","-","@")) else text
    writer.writerow([cell(item.title),item.period_start,item.period_end])
    writer.writerow(["Observations",cell(item.observations)])
    writer.writerow(["Prochaines actions",cell(item.next_actions)])
    writer.writerow(["Méthode",cell(item.snapshot.get("method",""))])
    writer.writerow([])
    writer.writerow(["Membre","Tâches affectées","Dues","Acceptées","Remises à temps","En retard","Taux d’acceptation (%)"])
    for row in item.snapshot.get("members",[]):
        writer.writerow([cell(row.get(k)) for k in ("name","assigned","due","accepted","on_time","late","rate")])
    writer.writerow([]);writer.writerow(["Indicateur","Valeur"])
    labels={"tasks":"Tâches affectées","due":"Livrables dus","accepted":"Livrables acceptés","on_time":"Remises à temps","late":"Retards à examiner","awaiting_review":"Livrables à relire","blockers":"Blocages ouverts","acceptance_rate":"Taux d’acceptation (%)","quality":"Qualité moyenne (sur 5)","quality_samples":"Livrables évalués","attendance_due":"Présences attendues","attendance_present":"Présences constatées","attendance_excused":"Absences justifiées","attendance_rate":"Taux de présence (%)"}
    for key,value in item.snapshot.get("totals",{}).items(): writer.writerow([labels.get(key,key),"Non évaluable" if value is None else value])
    return Response("\ufeff"+output.getvalue(),media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition":f'attachment; filename="enactspace-veille-{ident}.csv"'})


@router.post("/leaves")
def post_leave(payload:LeaveCreate,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return finish(db,service.create_leave(db,active(user),payload))


@router.patch("/leaves/{ident}")
def patch_leave(ident:uuid.UUID,payload:LeaveChange,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    item=visible_record(db,user,"leave",ident,True)
    return finish(db,service.change_leave(db,user,item,payload))


@router.post("/cases")
def post_case(payload:CaseCreate,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    return finish(db,service.create_case(db,active(user),payload))


@router.post("/cases/{ident}/actions")
def post_case_action(ident:uuid.UUID,payload:CaseAction,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    item=visible_record(db,user,"case",ident,True)
    return finish(db,service.act_case(db,user,item,payload))


@router.post("/rules")
def post_rule(payload:RuleCreate,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    a=service.VeilleAccess(db,active(user))
    if not a.decider: raise HTTPException(403,"L’adoption des règles revient au Team Leader ou à l’administration.")
    row=VeilleRule(**payload.model_dump(),created_by_id=user.id);db.add(row);db.flush()
    service.event_log(db,user,"rule",row.id,"adopted","Règle adoptée",{"effective_from":str(row.effective_from)})
    return finish(db,row)


@router.post("/rules/{ident}/retire")
def retire_rule(ident:uuid.UUID,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    if not service.VeilleAccess(db,active(user)).decider: raise HTTPException(403,"Cette action revient au Team Leader ou à l’administration.")
    row=service.get_record(db,VeilleRule,ident,True)
    row.retired=True;service.event_log(db,user,"rule",row.id,"retired","Règle remplacée pour les nouveaux dossiers")
    return finish(db,row)


@router.put("/settings")
def put_settings(payload:SettingsChange,db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    if not service.VeilleAccess(db,active(user)).decider: raise HTTPException(403,"Le réglage du suivi revient au Team Leader ou à l’administration.")
    row=service.settings(db);row=service.get_record(db,VeilleSettings,1,True);service.require_version(row,payload.version)
    before=service.record(row)
    for key,value in payload.model_dump(exclude={"version"}).items(): setattr(row,key,value)
    row.version+=1;row.updated_at=utc_now()
    create_audit_log(db,action="veille_settings_updated",user_id=user.id,entity_type="veille_settings",old_value=before,new_value=service.record(row))
    return finish(db,row)
