import csv
from datetime import datetime
from io import StringIO

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import require_admin_or_team_leader, require_enacchef_or_admin
from app.api.routes.files import ensure_file_access, get_file_or_404
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
    ImpactValidationRequest,
)
from app.services.audit_service import create_audit_log
from app.services.notification_service import notify_user, notify_users


router = APIRouter(prefix="/impact", tags=["Impact"])


CLAIM_TYPES = {"MEASURED", "ESTIMATE", "PROJECTION", "HISTORICAL_CLAIM"}
VALIDATION_STATUSES = {
    "DRAFT",
    "EVIDENCE_PENDING",
    "EVIDENCE_ATTACHED",
    "UNDER_REVIEW",
    "VERIFIED",
    "REJECTED",
    "SUPERSEDED",
}
ACTIVE_REPLACEMENT_STATUSES = (
    "DRAFT",
    "EVIDENCE_PENDING",
    "EVIDENCE_ATTACHED",
    "UNDER_REVIEW",
    "VERIFIED",
)
LEGACY_STATUS_MAP = {
    "draft": "DRAFT",
    "submitted": "EVIDENCE_PENDING",
    "under_review": "UNDER_REVIEW",
    "validated": "VERIFIED",
    "rejected": "REJECTED",
    "archived": "SUPERSEDED",
}
EVIDENCE_LEGACY_STATUS_MAP = {
    **LEGACY_STATUS_MAP,
    "submitted": "EVIDENCE_ATTACHED",
}
LEGACY_STATUS_BY_VALIDATION = {
    value: key for key, value in LEGACY_STATUS_MAP.items()
}
LEGACY_STATUS_BY_VALIDATION["EVIDENCE_ATTACHED"] = "submitted"
REALIZED_FIELDS = {
    "direct_impact": "direct_beneficiaries",
    "indirect_impact": "indirect_beneficiaries",
    "reach": "reach",
    "revenue": "revenue_generated",
    "surplus": "profit_or_surplus",
    "jobs_created": "jobs_created",
    "lives_impacted": "lives_impacted",
    "trees_planted": "trees_planted",
    "waste_reduced": "waste_reduced",
    "water_saved": "water_saved",
    "co2_reduced": "co2_reduced",
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


def _validation_status(
    value: str | None,
    legacy: str | None = None,
    *,
    legacy_map: dict[str, str] = LEGACY_STATUS_MAP,
) -> str:
    status_value = (value or "").strip().upper()
    legacy_value = (legacy or "").strip().lower()
    if not status_value and legacy_value:
        status_value = legacy_map.get(legacy_value, "")
    if status_value not in VALIDATION_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut impact invalide",
        )
    return status_value


def _sync_validation(
    data: dict,
    *,
    default: str,
    legacy_map: dict[str, str] = LEGACY_STATUS_MAP,
) -> None:
    explicit_validation = "validation_status" in data
    value = data.get("validation_status") if explicit_validation else None
    if not explicit_validation and "status" not in data:
        value = default
    canonical = _validation_status(
        value,
        data.get("status"),
        legacy_map=legacy_map,
    )
    data["validation_status"] = canonical
    data["status"] = LEGACY_STATUS_BY_VALIDATION[canonical]


def _ensure_pending_validation(data: dict) -> None:
    if data["validation_status"] in {"VERIFIED", "REJECTED", "SUPERSEDED"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Utilisez l'action de validation, rejet ou remplacement dediee",
        )


def _claim_type(value: str | None) -> str:
    claim_type = (value or "").strip().upper()
    if claim_type not in CLAIM_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de declaration impact invalide",
        )
    return claim_type


def _semantic_key(value: str) -> str:
    semantic_key = value.strip().lower()
    if not semantic_key:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cle semantique impact requise",
        )
    return semantic_key


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
    if payload.period_start and payload.period_end and payload.period_end < payload.period_start:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La fin de periode doit suivre son debut",
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


def _require_rejection_reason(payload: ImpactValidationRequest) -> str:
    reason = (payload.reason or "").strip()
    if not reason:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le motif de rejet est obligatoire",
        )
    return reason


def _notify_impact_author(
    db: Session,
    *,
    user_id,
    title: str,
    message: str,
    notification_type: str,
    related_type: str,
    related_id,
) -> None:
    if user_id is None:
        return
    notify_user(
        db,
        user_id=user_id,
        title=title,
        message=message,
        notification_type=notification_type,
        related_type=related_type,
        related_id=related_id,
        dedupe=True,
    )


def _operational_progress(status: str | None) -> float:
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


def _claim_payload(metric: ImpactMetric, evidence_count: int = 0) -> dict:
    return {
        "id": str(metric.id),
        "semantic_key": metric.semantic_key,
        "title": metric.title,
        "category": metric.category,
        "value": float(metric.value) if metric.value is not None else None,
        "unit": metric.unit,
        "claim_type": metric.claim_type,
        "validation_status": metric.validation_status,
        "period_start": metric.period_start,
        "period_end": metric.period_end,
        "population_scope": metric.population_scope,
        "source": metric.source,
        "source_reference": metric.source_reference,
        "methodology": metric.methodology_note,
        "notes_limitations": metric.notes_limitations,
        "evidence_count": evidence_count,
        "created_by": str(metric.created_by_id) if metric.created_by_id else None,
        "created_at": metric.created_at,
        "validated_by": str(metric.validated_by_id) if metric.validated_by_id else None,
        "validated_at": metric.validated_at,
        "supersedes_metric_id": (
            str(metric.supersedes_metric_id) if metric.supersedes_metric_id else None
        ),
    }


def _canonical_realized_claims(metrics: list[ImpactMetric]) -> list[ImpactMetric]:
    # One canonical claim per project and semantic indicator is safer than
    # summing potentially overlapping periods or populations.
    current: dict[str, ImpactMetric] = {}
    for metric in metrics:
        if (
            metric.value is None
            or metric.claim_type != "MEASURED"
            or metric.validation_status != "VERIFIED"
        ):
            continue
        key = metric.semantic_key
        candidate_order = (metric.validated_at or metric.created_at, str(metric.id))
        previous = current.get(key)
        previous_order = (
            (previous.validated_at or previous.created_at, str(previous.id))
            if previous is not None
            else None
        )
        if previous_order is None or candidate_order > previous_order:
            current[key] = metric
    return list(current.values())


def _realized_value(metrics: list[ImpactMetric], semantic_key: str):
    values = [
        metric.value for metric in metrics if metric.semantic_key == semantic_key
    ]
    return sum(values) if values else None


def _sum_known(items: list[dict], key: str):
    values = [item[key] for item in items if item.get(key) is not None]
    return sum(values) if values else None


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
    impact_profile = (
        db.query(ImpactProject).filter(ImpactProject.project_id == project.id).first()
    )
    metrics = []
    evidence_counts = {}
    impact_evidence_count = 0
    verified_evidence_count = 0
    if impact_profile:
        metrics = (
            db.query(ImpactMetric)
            .filter(ImpactMetric.impact_project_id == impact_profile.id)
            .order_by(ImpactMetric.created_at.asc(), ImpactMetric.id.asc())
            .all()
        )
        impact_evidence_count = (
            db.query(func.count(ImpactEvidence.id))
            .filter(ImpactEvidence.impact_project_id == impact_profile.id)
            .scalar()
            or 0
        )
        verified_evidence_count = (
            db.query(func.count(ImpactEvidence.id))
            .filter(
                ImpactEvidence.impact_project_id == impact_profile.id,
                ImpactEvidence.validation_status == "VERIFIED",
            )
            .scalar()
            or 0
        )
        evidence_counts = dict(
            db.query(ImpactEvidence.metric_id, func.count(ImpactEvidence.id))
            .filter(
                ImpactEvidence.impact_project_id == impact_profile.id,
                ImpactEvidence.metric_id.is_not(None),
            )
            .group_by(ImpactEvidence.metric_id)
            .all()
        )
    realized_claims = _canonical_realized_claims(metrics)
    lead, deputy = _project_leaders(db, project.id)
    budget = float(project.budget_estimated or 0)
    progress = _operational_progress(project.status)

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
        **{
            field: float(value) if value is not None else None
            for field, semantic_key in REALIZED_FIELDS.items()
            for value in [_realized_value(realized_claims, semantic_key)]
        },
        "planet_impact": None,
        "evidence_count": int(impact_evidence_count),
        "verified_evidence_count": int(verified_evidence_count),
        "methodology": None,
        "assumptions": None,
        "budget_used": budget,
        "progress": progress,
        "completed_tasks": int(completed_tasks),
        "late_tasks": int(late_tasks),
        "documents_count": int(documents_count),
        "innovation_score": None,
        "business_viability_score": None,
        "scalability_score": None,
        "competition_readiness_score": None,
        "claims": [
            _claim_payload(metric, int(evidence_counts.get(metric.id, 0)))
            for metric in metrics
        ],
    }

    if impact_profile:
        payload.update(
            {
                "sdgs": impact_profile.sdgs or [],
                "problem": impact_profile.problem_statement or payload["problem"],
                "solution": impact_profile.solution_summary or payload["solution"],
                "target_beneficiaries": (
                    impact_profile.target_population
                    or payload["target_beneficiaries"]
                ),
                "methodology": impact_profile.methodology,
                "assumptions": (
                    impact_profile.projection_next_12_months
                    or impact_profile.evidence_notes
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
    if "validation_status" not in payload.model_fields_set:
        data.pop("validation_status", None)
    if "status" not in payload.model_fields_set:
        data.pop("status", None)
    _sync_validation(data, default="DRAFT")
    _ensure_pending_validation(data)
    impact_project = ImpactProject(**data, created_by_id=current_user.id)
    db.add(impact_project)
    db.flush()

    if impact_project.validation_status in {"EVIDENCE_PENDING", "UNDER_REVIEW"}:
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
    if "status" in data or "validation_status" in data:
        _sync_validation(data, default=impact_project.validation_status)
        _ensure_pending_validation(data)
    for field, value in data.items():
        setattr(impact_project, field, value)
    impact_project.updated_at = datetime.utcnow()

    if impact_project.validation_status in {"EVIDENCE_PENDING", "UNDER_REVIEW"}:
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


@router.post("/records/{impact_project_id}/validate", response_model=ImpactProjectRead)
def validate_impact_record(
    impact_project_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin_or_team_leader),
):
    impact_project = _get_impact_project_or_404(db, impact_project_id)
    impact_project.validation_status = "VERIFIED"
    impact_project.status = "validated"
    impact_project.validated_by_id = current_user.id
    impact_project.validated_at = datetime.utcnow()
    impact_project.rejection_reason = None
    impact_project.updated_at = datetime.utcnow()
    create_audit_log(
        db, "impact_record_verified", current_user.id,
        "impact_project", impact_project.id,
    )
    _notify_impact_author(
        db,
        user_id=impact_project.created_by_id,
        title="Impact valide",
        message=f"{impact_project.title} a ete valide.",
        notification_type="impact_validated",
        related_type="impact_project",
        related_id=impact_project.id,
    )
    db.commit()
    db.refresh(impact_project)
    return impact_project


@router.post("/records/{impact_project_id}/reject", response_model=ImpactProjectRead)
def reject_impact_record(
    impact_project_id: str,
    payload: ImpactValidationRequest,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin_or_team_leader),
):
    impact_project = _get_impact_project_or_404(db, impact_project_id)
    reason = _require_rejection_reason(payload)
    impact_project.validation_status = "REJECTED"
    impact_project.status = "rejected"
    impact_project.validated_by_id = current_user.id
    impact_project.validated_at = datetime.utcnow()
    impact_project.rejection_reason = reason
    impact_project.updated_at = datetime.utcnow()
    create_audit_log(
        db, "impact_record_rejected", current_user.id,
        "impact_project", impact_project.id,
        new_value={"reason": reason},
    )
    _notify_impact_author(
        db,
        user_id=impact_project.created_by_id,
        title="Impact refuse",
        message=f"{impact_project.title} a ete refuse: {reason}",
        notification_type="impact_rejected",
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
    if "validation_status" not in payload.model_fields_set:
        data.pop("validation_status", None)
    if "status" not in payload.model_fields_set:
        data.pop("status", None)
    data["claim_type"] = _claim_type(payload.claim_type)
    data["semantic_key"] = _semantic_key(payload.semantic_key)
    _sync_validation(data, default="DRAFT")
    _ensure_pending_validation(data)
    if payload.evidence_file_id:
        stored_file = get_file_or_404(db, str(payload.evidence_file_id))
        ensure_file_access(db, stored_file, current_user, manage=True)
    if payload.supersedes_metric_id:
        replaced = (
            db.query(ImpactMetric)
            .filter(
                ImpactMetric.id == payload.supersedes_metric_id,
                ImpactMetric.impact_project_id == impact_project.id,
            )
            .with_for_update()
            .first()
        )
        if replaced is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Declaration remplacee invalide pour cette fiche impact",
            )
        if replaced.validation_status == "SUPERSEDED":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Une declaration deja remplacee ne peut pas recevoir un concurrent",
            )
        existing_replacement = db.query(ImpactMetric.id).filter(
            ImpactMetric.supersedes_metric_id == replaced.id,
            ImpactMetric.validation_status.in_(ACTIVE_REPLACEMENT_STATUSES),
        ).first()
        if existing_replacement:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cette declaration a deja ete remplacee",
            )
    metric = ImpactMetric(
        impact_project_id=impact_project.id,
        **data,
        created_by_id=current_user.id,
    )
    db.add(metric)
    db.flush()
    if metric.validation_status in {"EVIDENCE_PENDING", "UNDER_REVIEW"}:
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


@router.post("/metrics/{metric_id}/validate", response_model=ImpactMetricRead)
def validate_impact_metric(
    metric_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin_or_team_leader),
):
    metric = (
        db.query(ImpactMetric)
        .filter(ImpactMetric.id == metric_id)
        .with_for_update()
        .first()
    )
    if not metric:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Indicateur impact introuvable",
        )
    if metric.validation_status in {"REJECTED", "SUPERSEDED"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une declaration rejetee ou remplacee ne peut pas etre validee",
        )
    has_linked_evidence = (
        db.query(ImpactEvidence.id)
        .filter(
            ImpactEvidence.metric_id == metric.id,
            ImpactEvidence.impact_project_id == metric.impact_project_id,
        )
        .first()
        is not None
    )
    if not (
        (metric.source_reference or "").strip()
        or metric.evidence_file_id is not None
        or has_linked_evidence
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Une reference source ou une preuve rattachee est requise",
        )
    predecessor = None
    if metric.supersedes_metric_id is not None:
        predecessor = (
            db.query(ImpactMetric)
            .filter(
                ImpactMetric.id == metric.supersedes_metric_id,
                ImpactMetric.impact_project_id == metric.impact_project_id,
            )
            .with_for_update()
            .first()
        )
        if predecessor is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="La declaration remplacee est introuvable",
            )
        predecessor.validation_status = "SUPERSEDED"
        predecessor.status = "archived"
        predecessor.updated_at = datetime.utcnow()
        create_audit_log(
            db,
            "impact_claim_superseded",
            current_user.id,
            "impact_metric",
            predecessor.id,
            new_value={"replacement_metric_id": str(metric.id)},
        )
    metric.validation_status = "VERIFIED"
    metric.status = "validated"
    metric.validated_by_id = current_user.id
    metric.validated_at = datetime.utcnow()
    metric.rejection_reason = None
    metric.updated_at = datetime.utcnow()
    create_audit_log(
        db, "impact_claim_verified", current_user.id,
        "impact_metric", metric.id,
        new_value={"claim_type": metric.claim_type, "semantic_key": metric.semantic_key},
    )
    _notify_impact_author(
        db,
        user_id=metric.created_by_id,
        title="Indicateur impact valide",
        message=f"{metric.title} a ete valide.",
        notification_type="impact_metric_validated",
        related_type="impact_metric",
        related_id=metric.id,
    )
    db.commit()
    db.refresh(metric)
    return metric


@router.post("/metrics/{metric_id}/reject", response_model=ImpactMetricRead)
def reject_impact_metric(
    metric_id: str,
    payload: ImpactValidationRequest,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin_or_team_leader),
):
    metric = (
        db.query(ImpactMetric)
        .filter(ImpactMetric.id == metric_id)
        .with_for_update()
        .first()
    )
    if not metric:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Indicateur impact introuvable",
        )
    if metric.validation_status in {"VERIFIED", "SUPERSEDED"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une declaration validee ou remplacee ne peut pas etre rejetee",
        )
    reason = _require_rejection_reason(payload)
    metric.validation_status = "REJECTED"
    metric.status = "rejected"
    metric.validated_by_id = current_user.id
    metric.validated_at = datetime.utcnow()
    metric.rejection_reason = reason
    metric.updated_at = datetime.utcnow()
    create_audit_log(
        db, "impact_claim_rejected", current_user.id,
        "impact_metric", metric.id,
        new_value={"reason": reason},
    )
    _notify_impact_author(
        db,
        user_id=metric.created_by_id,
        title="Indicateur impact refuse",
        message=f"{metric.title} a ete refuse: {reason}",
        notification_type="impact_metric_rejected",
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
    if payload.file_id:
        stored_file = get_file_or_404(db, str(payload.file_id))
        ensure_file_access(db, stored_file, current_user, manage=True)
    data = payload.model_dump()
    if "validation_status" not in payload.model_fields_set:
        data.pop("validation_status", None)
    if "status" not in payload.model_fields_set:
        data.pop("status", None)
    _sync_validation(
        data,
        default="EVIDENCE_ATTACHED",
        legacy_map=EVIDENCE_LEGACY_STATUS_MAP,
    )
    _ensure_pending_validation(data)
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


@router.post("/evidence/{evidence_id}/validate", response_model=ImpactEvidenceRead)
def validate_impact_evidence(
    evidence_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin_or_team_leader),
):
    evidence = (
        db.query(ImpactEvidence).filter(ImpactEvidence.id == evidence_id).first()
    )
    if not evidence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Preuve impact introuvable",
        )
    evidence.validation_status = "VERIFIED"
    evidence.status = "validated"
    evidence.validated_by_id = current_user.id
    evidence.validated_at = datetime.utcnow()
    evidence.rejection_reason = None
    evidence.updated_at = datetime.utcnow()
    create_audit_log(
        db, "impact_evidence_verified", current_user.id,
        "impact_evidence", evidence.id,
    )
    _notify_impact_author(
        db,
        user_id=evidence.submitted_by_id,
        title="Preuve impact validee",
        message=f"{evidence.title} a ete validee.",
        notification_type="impact_evidence_validated",
        related_type="impact_evidence",
        related_id=evidence.id,
    )
    db.commit()
    db.refresh(evidence)
    return evidence


@router.post("/evidence/{evidence_id}/reject", response_model=ImpactEvidenceRead)
def reject_impact_evidence(
    evidence_id: str,
    payload: ImpactValidationRequest,
    db: Session = Depends(get_db),
    current_user=Depends(require_admin_or_team_leader),
):
    evidence = (
        db.query(ImpactEvidence).filter(ImpactEvidence.id == evidence_id).first()
    )
    if not evidence:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Preuve impact introuvable",
        )
    reason = _require_rejection_reason(payload)
    evidence.validation_status = "REJECTED"
    evidence.status = "rejected"
    evidence.validated_by_id = current_user.id
    evidence.validated_at = datetime.utcnow()
    evidence.rejection_reason = reason
    evidence.updated_at = datetime.utcnow()
    create_audit_log(
        db, "impact_evidence_rejected", current_user.id,
        "impact_evidence", evidence.id,
        new_value={"reason": reason},
    )
    _notify_impact_author(
        db,
        user_id=evidence.submitted_by_id,
        title="Preuve impact refusee",
        message=f"{evidence.title} a ete refusee: {reason}",
        notification_type="impact_evidence_rejected",
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
    direct_impact = _sum_known(projects, "direct_impact")
    indirect_impact = _sum_known(projects, "indirect_impact")
    reach = _sum_known(projects, "reach")
    jobs_created = _sum_known(projects, "jobs_created")
    lives_impacted = _sum_known(projects, "lives_impacted")
    trees_planted = _sum_known(projects, "trees_planted")
    validated_evidence = (
        db.query(func.count(ImpactEvidence.id))
        .filter(ImpactEvidence.validation_status == "VERIFIED")
        .scalar()
        or 0
    )
    claims = [claim for project in projects for claim in project["claims"]]
    claim_overview = {
        "by_claim_type": {
            claim_type: sum(claim["claim_type"] == claim_type for claim in claims)
            for claim_type in sorted(CLAIM_TYPES)
        },
        "by_validation_status": {
            validation_status: sum(
                claim["validation_status"] == validation_status for claim in claims
            )
            for validation_status in sorted(VALIDATION_STATUSES)
        },
    }

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
            # A union cannot be inferred from unvalidated project metadata.
            "touched_sdgs": None,
            "revenue_total": _sum_known(projects, "revenue"),
            "surplus_total": _sum_known(projects, "surplus"),
            "official_documents": documents,
            "competition_readiness": None,
            "academy_participation": None,
            "communication_engagement": None,
            "financial_health": None,
        },
        "claim_overview": claim_overview,
        "historical_impact": None,
    }


def _csv_download(filename: str, rows: list[list]) -> Response:
    output = StringIO()
    writer = csv.writer(output)
    writer.writerows(rows)
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


def _impact_export_rows(projects: list[dict]) -> list[list]:
    rows = [
        [
            "Projet",
            "Statut projet",
            "Pole",
            "Chef projet",
            "Cle semantique",
            "Indicateur",
            "Valeur",
            "Unite",
            "Type de declaration",
            "Statut de validation",
            "Debut periode",
            "Fin periode",
            "Perimetre population",
            "Source",
            "Reference source",
            "Methodologie",
            "Notes et limites",
            "Nombre de preuves",
        ]
    ]
    for project in projects:
        claims = project["claims"] or [None]
        for claim in claims:
            rows.append(
                [
                    project["project_name"],
                    project["status"],
                    project["pole_name"],
                    project["project_lead"],
                    claim["semantic_key"] if claim else None,
                    claim["title"] if claim else None,
                    claim["value"] if claim else None,
                    claim["unit"] if claim else None,
                    claim["claim_type"] if claim else None,
                    claim["validation_status"] if claim else None,
                    claim["period_start"] if claim else None,
                    claim["period_end"] if claim else None,
                    claim["population_scope"] if claim else None,
                    claim["source"] if claim else None,
                    claim["source_reference"] if claim else None,
                    claim["methodology"] if claim else None,
                    claim["notes_limitations"] if claim else None,
                    claim["evidence_count"] if claim else 0,
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
                    "jobs_created": project["jobs_created"],
                    "evidence": project["evidence_count"],
                    "verified_evidence": project["verified_evidence_count"],
                },
                "claims": project["claims"],
                "sdgs": project.get("sdgs", []),
                "methodology": project["methodology"],
                "projection": project["assumptions"],
                "improvement_points": [
                    *(
                        ["Ajouter des preuves validees"]
                        if project["verified_evidence_count"] < 2
                        else []
                    ),
                    *(["Renseigner les ODD"] if not project.get("sdgs") else []),
                ],
            }
            for project in projects
        ],
        "todo": "Generation PDF a brancher apres validation du modele de rapport.",
    }
