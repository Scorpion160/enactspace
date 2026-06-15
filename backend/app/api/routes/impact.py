from fastapi import APIRouter, Depends
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import require_enacchef_or_admin
from app.db.database import get_db
from app.models.document import Document
from app.models.pole import Pole
from app.models.project import Project, ProjectMember, ProjectPole
from app.models.task import Task
from app.models.user import User


router = APIRouter(prefix="/impact", tags=["Impact"])


HISTORICAL_IMPACT = {
    "created_projects": 5,
    "developing_projects": 4,
    "developed_products": 14,
    "touched_sdgs": 11,
    "created_jobs": 227,
    "saved_lives": 206,
    "planted_trees": 1425,
    "cumulative_usd_gains": 46236.7,
    "cumulative_fcfa_gains": 27468761,
    "impacted_lives": 15900,
    "emblematic_projects": [
        "DIMBALI",
        "DECONAANE",
        "JAVELISEL",
        "MOBIGEL",
        "MEUNE NAGN",
        "SOUKHALI",
    ],
    "distinctions": [
        "Champion National 2017",
        "Champion National 2018",
        "Demi-finaliste compétition internationale 2018",
        "Premier Prix d’Excellence Fondation Sonatel",
    ],
}


def _status_progress(status: str | None) -> float:
    normalized = (status or "").strip().lower()
    if normalized in {"termine", "terminé", "done", "completed"}:
        return 100
    if normalized in {"actif", "active", "en_cours", "en cours"}:
        return 70
    if normalized in {"prototype", "pilote", "pilot"}:
        return 48
    if normalized in {"idee", "idée", "exploration"}:
        return 28
    return 40


def _display_name(user: User | None) -> str:
    if not user:
        return "Non assigné"
    name = " ".join(
        part for part in [user.first_name, user.last_name] if part and part.strip()
    ).strip()
    return name or user.email


def _project_pole_name(db: Session, project_id) -> str:
    pole = (
        db.query(Pole)
        .join(ProjectPole, ProjectPole.pole_id == Pole.id)
        .filter(ProjectPole.project_id == project_id)
        .order_by(Pole.name.asc())
        .first()
    )
    return pole.name if pole else "Projet"


def _project_leaders(db: Session, project_id) -> tuple[str, str]:
    members = (
        db.query(ProjectMember, User)
        .join(User, User.id == ProjectMember.user_id)
        .filter(ProjectMember.project_id == project_id, ProjectMember.is_active.is_(True))
        .order_by(ProjectMember.position.asc(), ProjectMember.joined_at.asc())
        .all()
    )

    lead = None
    deputy = None
    for member, user in members:
        position = (member.position or "").lower()
        if lead is None and ("chef" in position or "lead" in position):
            lead = user
        elif deputy is None and ("adjoint" in position or "deputy" in position):
            deputy = user

    if lead is None and members:
        lead = members[0][1]
    if deputy is None and len(members) > 1:
        deputy = members[1][1]

    return _display_name(lead), _display_name(deputy)


def _project_payload(db: Session, project: Project) -> dict:
    completed_tasks = (
        db.query(func.count(Task.id))
        .filter(
            Task.project_id == project.id,
            Task.status.in_(["termine", "terminé", "done", "completed"]),
        )
        .scalar()
        or 0
    )
    late_tasks = (
        db.query(func.count(Task.id))
        .filter(Task.project_id == project.id, Task.status.in_(["en_retard", "late"]))
        .scalar()
        or 0
    )
    documents_count = (
        db.query(func.count(Document.id))
        .filter(Document.project_id == project.id)
        .scalar()
        or 0
    )
    evidence_count = (
        db.query(func.count(Document.id))
        .filter(Document.project_id == project.id, Document.is_official.is_(True))
        .scalar()
        or 0
    )
    lead, deputy = _project_leaders(db, project.id)
    budget = float(project.budget_estimated or 0)
    progress = _status_progress(project.status)
    direct_impact = max(0, int(progress * 2))
    indirect_impact = direct_impact * 4
    reach = direct_impact + indirect_impact + documents_count * 25

    return {
        "id": str(project.id),
        "project_name": project.name,
        "status": project.status,
        "pole_name": _project_pole_name(db, project.id),
        "project_lead": lead,
        "deputy_lead": deputy,
        "sdgs": [],
        "problem": project.problem_statement or project.description or "Problème à documenter",
        "solution": project.solution or "Solution à documenter",
        "target_beneficiaries": project.expected_impact or "Bénéficiaires à préciser",
        "direct_impact": direct_impact,
        "indirect_impact": indirect_impact,
        "reach": reach,
        "revenue": 0,
        "surplus": 0,
        "planet_impact": 0,
        "evidence_count": int(evidence_count),
        "methodology": "À préciser dans le module Impact",
        "assumptions": project.objectives or "Hypothèses à documenter",
        "budget_used": budget,
        "progress": progress,
        "completed_tasks": int(completed_tasks),
        "late_tasks": int(late_tasks),
        "documents_count": int(documents_count),
        "innovation_score": min(100, 45 + documents_count * 4),
        "business_viability_score": 50 if budget else 35,
        "scalability_score": min(100, 42 + completed_tasks * 3),
        "competition_readiness_score": min(100, 30 + evidence_count * 10 + documents_count * 2),
    }


@router.get("/projects")
def list_impact_projects(
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    projects = db.query(Project).order_by(Project.updated_at.desc()).all()
    return [_project_payload(db, project) for project in projects]


@router.get("/summary")
def get_impact_summary(
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    projects = list_impact_projects(db=db, current_user=current_user)
    active_projects = len(projects)
    completed_tasks = sum(project["completed_tasks"] for project in projects)
    late_tasks = sum(project["late_tasks"] for project in projects)
    documents = sum(project["documents_count"] for project in projects)
    direct_impact = sum(project["direct_impact"] for project in projects)
    indirect_impact = sum(project["indirect_impact"] for project in projects)
    reach = sum(project["reach"] for project in projects)
    readiness = (
        sum(project["competition_readiness_score"] for project in projects)
        / active_projects
        if active_projects
        else 0
    )

    return {
        "organization": {
            "active_members": db.query(func.count(User.id))
            .filter(User.is_active.is_(True), User.status.in_(["active", "alumni"]))
            .scalar()
            or 0,
            "attendance_rate": 0,
            "retention_rate": 0,
            "completed_tasks": completed_tasks,
            "late_tasks": late_tasks,
            "active_projects": active_projects,
            "direct_impact_total": direct_impact,
            "indirect_impact_total": indirect_impact,
            "reach_total": reach,
            "revenue_total": sum(project["revenue"] for project in projects),
            "surplus_total": sum(project["surplus"] for project in projects),
            "official_documents": documents,
            "competition_readiness": readiness,
            "academy_participation": 0,
            "communication_engagement": 0,
            "financial_health": 0,
        },
        "historical_impact": HISTORICAL_IMPACT,
    }
