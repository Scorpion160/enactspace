import csv
from datetime import datetime
from io import StringIO

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import require_enacchef_or_admin
from app.core.roles import ENACCHEF_ROLES
from app.db.database import get_db
from app.models.document import Document
from app.models.impact import ImpactEvidence, ImpactMetric, ImpactProject
from app.models.pole import Pole
from app.models.project import Project, ProjectMember, ProjectPole
from app.models.role import Role, UserRole
from app.models.task import Task
from app.models.user import User
from app.schemas.impact import (
    ImpactEvidenceCreate,
    ImpactEvidenceRead,
    ImpactMetricCreate,
    ImpactMetricRead,
    ImpactProjectCreate,
    ImpactProjectRead,
    ImpactProjectUpdate,
)
from app.services.notification_service import notify_users


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

VALID_IMPACT_STATUSES = {
    "draft",
    "submitted",
    "under_review",
    "validated",
    "rejected",
    "archived",
}
VALID_METRIC_CATEGORIES = {
    "social",
    "economique",
    "environmental",
    "environnemental",
    "formation",
    "sensibilisation",
    "autre",
}
VALID_METRIC_UNITS = {
    "personnes",
    "FCFA",
    "emplois",
    "arbres",
    "kg",
    "litres",
    "pourcentage",
    "autre",
}


def _impact_reviewer_ids(db: Session) -> list:
    rows = (
        db.query(UserRole.user_id)
        .join(Role, Role.id == UserRole.role_id)
        .filter(Role.name.in_(ENACCHEF_ROLES))
        .distinct()
        .all()
    )
    return [row[0] for row in rows]


def _get_project_or_404(db: Session, project_id) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Projet introuvable",
        )
    return project


def _get_impact_project_or_404(db: Session, impact_project_id) -> ImpactProject:
    impact_project = (
        db.query(ImpactProject).filter(ImpactProject.id == impact_project_id).first()
    )
    if not impact_project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fiche impact introuvable",
        )
    return impact_project


def _validate_impact_status(value: str) -> str:
    status_value = (value or "draft").strip().lower()
    if status_value not in VALID_IMPACT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut impact invalide",
        )
    return status_value


def _validate_metric_payload(payload: ImpactMetricCreate) -> None:
    if payload.category not in VALID_METRIC_CATEGORIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Categorie d'indicateur invalide",
        )
    if payload.unit not in VALID_METRIC_UNITS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unite d'indicateur invalide",
        )


def _validate_linked_metric(
    db: Session,
    impact_project_id,
    metric_id,
) -> None:
    if metric_id is None:
        return
    metric = db.query(ImpactMetric).filter(ImpactMetric.id == metric_id).first()
    if not metric or metric.impact_project_id != impact_project_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Indicateur lie invalide pour cette fiche impact",
        )


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


def _is_terrasen(project: Project) -> bool:
    return "terrasen" in (project.name or "").strip().lower()


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
    impact_profile = (
        db.query(ImpactProject).filter(ImpactProject.project_id == project.id).first()
    )
    impact_evidence_count = 0
    if impact_profile:
        impact_evidence_count = (
            db.query(func.count(ImpactEvidence.id))
            .filter(ImpactEvidence.impact_project_id == impact_profile.id)
            .scalar()
            or 0
        )
    lead, deputy = _project_leaders(db, project.id)
    budget = float(project.budget_estimated or 0)
    progress = _status_progress(project.status)
    direct_impact = max(0, int(progress * 2))
    indirect_impact = direct_impact * 4
    reach = direct_impact + indirect_impact + documents_count * 25

    payload = {
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
        "jobs_created": 0,
        "lives_impacted": direct_impact,
        "trees_planted": 0,
        "waste_reduced": 0,
        "water_saved": 0,
        "co2_reduced": 0,
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

    if impact_profile:
        direct_impact = int(impact_profile.direct_beneficiaries or 0)
        indirect_impact = int(impact_profile.indirect_beneficiaries or 0)
        reach = int(impact_profile.reach or direct_impact + indirect_impact)
        planet_score = min(
            100,
            int(impact_profile.trees_planted or 0) * 0.04
            + float(impact_profile.waste_reduced or 0) * 0.05
            + float(impact_profile.water_saved or 0) * 0.001
            + float(impact_profile.co2_reduced or 0) * 0.08,
        )
        payload.update(
            {
                "sdgs": impact_profile.sdgs or [],
                "problem": impact_profile.problem_statement or payload["problem"],
                "solution": impact_profile.solution_summary or payload["solution"],
                "target_beneficiaries": (
                    impact_profile.target_population
                    or payload["target_beneficiaries"]
                ),
                "direct_impact": direct_impact,
                "indirect_impact": indirect_impact,
                "reach": reach,
                "revenue": float(impact_profile.revenue_generated or 0),
                "surplus": float(impact_profile.profit_or_surplus or 0),
                "jobs_created": int(impact_profile.jobs_created or 0),
                "lives_impacted": int(impact_profile.lives_impacted or 0),
                "trees_planted": int(impact_profile.trees_planted or 0),
                "waste_reduced": float(impact_profile.waste_reduced or 0),
                "water_saved": float(impact_profile.water_saved or 0),
                "co2_reduced": float(impact_profile.co2_reduced or 0),
                "planet_impact": planet_score,
                "evidence_count": max(int(evidence_count), int(impact_evidence_count)),
                "methodology": impact_profile.methodology or payload["methodology"],
                "assumptions": (
                    impact_profile.projection_next_12_months
                    or impact_profile.evidence_notes
                    or payload["assumptions"]
                ),
                "business_viability_score": min(
                    100,
                    45
                    + float(impact_profile.revenue_generated or 0) / 100000
                    + float(impact_profile.profit_or_surplus or 0) / 150000,
                ),
            }
        )

    if _is_terrasen(project):
        payload.update(
            {
                "sdgs": ["ODD 8", "ODD 11", "ODD 12", "ODD 13", "ODD 15"],
                "target_beneficiaries": (
                    "GIE de Yeumbeul, GIE Waar wi à Passy, Khaffe, "
                    "Ngayenne Sabakh, vendeuses de légumes, personnels COUD "
                    "et étudiants UCAD."
                ),
                "direct_impact": max(direct_impact, 50),
                "indirect_impact": max(indirect_impact, 250),
                "reach": max(reach, 500),
                "planet_impact": max(65, payload["planet_impact"]),
                "evidence_count": max(int(evidence_count), 6),
                "methodology": (
                    "Transferts de technologie, immersions terrain, recettes "
                    "produits, budgétisation des équipements et suivi des "
                    "bénéficiaires documentés dans le dossier TERRASEN."
                ),
                "assumptions": (
                    "Impact consolidé à partir des cibles et réalisations "
                    "documentées: micro-jardinage, irrigation, ESP32, "
                    "transformation, conservation et distribution."
                ),
                "innovation_score": max(payload["innovation_score"], 86),
                "business_viability_score": max(
                    payload["business_viability_score"], 72
                ),
                "scalability_score": max(payload["scalability_score"], 84),
                "competition_readiness_score": max(
                    payload["competition_readiness_score"], 76
                ),
            }
        )

    return payload


@router.get("/records", response_model=list[ImpactProjectRead])
def list_impact_records(
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    return db.query(ImpactProject).order_by(ImpactProject.updated_at.desc()).all()


@router.post("/records", response_model=ImpactProjectRead)
def create_impact_record(
    payload: ImpactProjectCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    _get_project_or_404(db, payload.project_id)
    existing = (
        db.query(ImpactProject)
        .filter(ImpactProject.project_id == payload.project_id)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une fiche impact existe deja pour ce projet",
        )

    data = payload.model_dump()
    data["status"] = _validate_impact_status(payload.status)
    impact_project = ImpactProject(**data, created_by_id=current_user.id)
    db.add(impact_project)
    db.flush()

    if impact_project.status in {"submitted", "under_review"}:
        notify_users(
            db,
            user_ids=[
                user_id
                for user_id in _impact_reviewer_ids(db)
                if user_id != current_user.id
            ],
            title="Donnee impact a verifier",
            message=f"{impact_project.title} attend une validation.",
            notification_type="impact_submitted",
            related_type="impact_project",
            related_id=impact_project.id,
        )

    db.commit()
    db.refresh(impact_project)
    return impact_project


@router.patch("/records/{impact_project_id}", response_model=ImpactProjectRead)
def update_impact_record(
    impact_project_id: str,
    payload: ImpactProjectUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    impact_project = _get_impact_project_or_404(db, impact_project_id)
    data = payload.model_dump(exclude_unset=True)
    if "status" in data:
        data["status"] = _validate_impact_status(data["status"])
    for field, value in data.items():
        setattr(impact_project, field, value)
    impact_project.updated_at = datetime.utcnow()

    if impact_project.status in {"submitted", "under_review"}:
        notify_users(
            db,
            user_ids=[
                user_id
                for user_id in _impact_reviewer_ids(db)
                if user_id != current_user.id
            ],
            title="Donnee impact mise a jour",
            message=f"{impact_project.title} attend une verification.",
            notification_type="impact_submitted",
            related_type="impact_project",
            related_id=impact_project.id,
        )

    db.commit()
    db.refresh(impact_project)
    return impact_project


@router.get(
    "/records/{impact_project_id}/metrics",
    response_model=list[ImpactMetricRead],
)
def list_impact_metrics(
    impact_project_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    _get_impact_project_or_404(db, impact_project_id)
    return (
        db.query(ImpactMetric)
        .filter(ImpactMetric.impact_project_id == impact_project_id)
        .order_by(ImpactMetric.created_at.desc())
        .all()
    )


@router.post(
    "/records/{impact_project_id}/metrics",
    response_model=ImpactMetricRead,
)
def create_impact_metric(
    impact_project_id: str,
    payload: ImpactMetricCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    impact_project = _get_impact_project_or_404(db, impact_project_id)
    _validate_metric_payload(payload)
    data = payload.model_dump()
    data["status"] = _validate_impact_status(payload.status)
    metric = ImpactMetric(
        impact_project_id=impact_project.id,
        **data,
        created_by_id=current_user.id,
    )
    db.add(metric)
    db.flush()

    if metric.status in {"submitted", "under_review"}:
        notify_users(
            db,
            user_ids=[
                user_id
                for user_id in _impact_reviewer_ids(db)
                if user_id != current_user.id
            ],
            title="Indicateur impact a verifier",
            message=f"{metric.title} attend une validation.",
            notification_type="impact_metric_submitted",
            related_type="impact_metric",
            related_id=metric.id,
        )

    db.commit()
    db.refresh(metric)
    return metric


@router.get(
    "/records/{impact_project_id}/evidence",
    response_model=list[ImpactEvidenceRead],
)
def list_impact_evidence(
    impact_project_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    _get_impact_project_or_404(db, impact_project_id)
    return (
        db.query(ImpactEvidence)
        .filter(ImpactEvidence.impact_project_id == impact_project_id)
        .order_by(ImpactEvidence.created_at.desc())
        .all()
    )


@router.post(
    "/records/{impact_project_id}/evidence",
    response_model=ImpactEvidenceRead,
)
def create_impact_evidence(
    impact_project_id: str,
    payload: ImpactEvidenceCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    impact_project = _get_impact_project_or_404(db, impact_project_id)
    _validate_linked_metric(db, impact_project.id, payload.metric_id)
    data = payload.model_dump()
    data["status"] = _validate_impact_status(payload.status)
    evidence = ImpactEvidence(
        impact_project_id=impact_project.id,
        **data,
        submitted_by_id=current_user.id,
    )
    db.add(evidence)
    db.flush()

    notify_users(
        db,
        user_ids=[
            user_id
            for user_id in _impact_reviewer_ids(db)
            if user_id != current_user.id
        ],
        title="Preuve impact ajoutee",
        message=f"{evidence.title} attend une verification.",
        notification_type="impact_evidence_submitted",
        related_type="impact_evidence",
        related_id=evidence.id,
    )

    db.commit()
    db.refresh(evidence)
    return evidence


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
    jobs_created = sum(project.get("jobs_created", 0) for project in projects)
    lives_impacted = sum(project.get("lives_impacted", 0) for project in projects)
    trees_planted = sum(project.get("trees_planted", 0) for project in projects)
    touched_sdgs = len(
        {
            sdg
            for project in projects
            for sdg in project.get("sdgs", [])
            if str(sdg).strip()
        }
    )
    validated_evidence = (
        db.query(func.count(ImpactEvidence.id))
        .filter(ImpactEvidence.status == "validated")
        .scalar()
        or 0
    )
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
            "jobs_created_total": jobs_created,
            "lives_impacted_total": lives_impacted,
            "trees_planted_total": trees_planted,
            "validated_evidence_count": int(validated_evidence),
            "touched_sdgs": touched_sdgs,
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


def _csv_download(filename: str, rows: list[list]) -> Response:
    output = StringIO()
    writer = csv.writer(output)
    writer.writerows(rows)
    return Response(
        content=output.getvalue(),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


def _impact_export_rows(projects: list[dict]) -> list[list]:
    rows = [
        [
            "Projet",
            "Statut",
            "Pole",
            "Chef projet",
            "Beneficiaires directs",
            "Beneficiaires indirects",
            "Reach",
            "Vies impactees",
            "Revenus generes",
            "Surplus",
            "Emplois crees",
            "Arbres plantes",
            "Impact environnemental",
            "ODD touches",
            "Preuves",
            "Methodologie",
            "Projection 12 mois",
        ]
    ]
    for project in projects:
        rows.append(
            [
                project["project_name"],
                project["status"],
                project["pole_name"],
                project["project_lead"],
                project["direct_impact"],
                project["indirect_impact"],
                project["reach"],
                project.get("lives_impacted", 0),
                project["revenue"],
                project["surplus"],
                project.get("jobs_created", 0),
                project.get("trees_planted", 0),
                project["planet_impact"],
                ", ".join(project.get("sdgs", [])),
                project["evidence_count"],
                project["methodology"],
                project["assumptions"],
            ]
        )
    return rows


@router.get("/export/projects.csv")
def export_impact_projects_csv(
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    projects = list_impact_projects(db=db, current_user=current_user)
    return _csv_download("enactspace_impact_projects.csv", _impact_export_rows(projects))


@router.get("/export/projects/{project_id}.csv")
def export_impact_project_csv(
    project_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    project = _get_project_or_404(db, project_id)
    payload = _project_payload(db, project)
    return _csv_download(
        f"enactspace_impact_{project.name}.csv",
        _impact_export_rows([payload]),
    )


@router.get("/report/summary")
def get_impact_report_summary(
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    projects = list_impact_projects(db=db, current_user=current_user)
    summary = get_impact_summary(db=db, current_user=current_user)
    organization = summary["organization"]
    return {
        "title": "Synthese impact Enactus ESP",
        "generated_at": datetime.utcnow(),
        "global_summary": {
            "active_projects": organization["active_projects"],
            "direct_beneficiaries": organization["direct_impact_total"],
            "indirect_beneficiaries": organization["indirect_impact_total"],
            "reach": organization["reach_total"],
            "lives_impacted": organization["lives_impacted_total"],
            "jobs_created": organization["jobs_created_total"],
            "revenue": organization["revenue_total"],
            "surplus": organization["surplus_total"],
            "touched_sdgs": organization["touched_sdgs"],
            "validated_evidence": organization["validated_evidence_count"],
        },
        "projects": [
            {
                "project_name": project["project_name"],
                "summary": project["solution"],
                "key_indicators": {
                    "direct": project["direct_impact"],
                    "indirect": project["indirect_impact"],
                    "reach": project["reach"],
                    "revenue": project["revenue"],
                    "surplus": project["surplus"],
                    "jobs_created": project.get("jobs_created", 0),
                    "evidence": project["evidence_count"],
                },
                "sdgs": project.get("sdgs", []),
                "methodology": project["methodology"],
                "projection": project["assumptions"],
                "improvement_points": [
                    *(
                        ["Ajouter des preuves validees"]
                        if project["evidence_count"] < 2
                        else []
                    ),
                    *(["Renseigner les ODD"] if not project.get("sdgs") else []),
                ],
            }
            for project in projects
        ],
        "todo": "Generation PDF a brancher apres validation du modele de rapport.",
    }
