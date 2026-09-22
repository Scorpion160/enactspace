import base64
import json
import re
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import Date, DateTime, String, and_, case, cast, func, literal, or_, select, union_all
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    require_memory_curator,
    user_has_any_role,
)
from app.api.routes.documents import visible_documents_query
from app.api.routes.files import ensure_file_access, get_file_or_404
from app.core.roles import MEMORY_CURATOR_ROLES
from app.db.database import get_db
from app.models.archive import Award, CompetitionRecord
from app.models.attendance import AttendanceSession
from app.models.document import Document
from app.models.event import Event
from app.models.institutional_memory import (
    CanonicalProject,
    CompetitionParticipation,
    InstitutionalEvent,
    InstitutionalFramework,
    InstitutionalGeneration,
    InstitutionalSource,
    LeadershipTerm,
    ProjectAlias,
    ProjectRelationship,
    ProjectYear,
    Territory,
)
from app.models.pole import Pole
from app.models.project import Project
from app.models.user import User
from app.schemas.institutional_memory import (
    AwardMemoryCreate,
    AwardMemoryRead,
    AwardMemoryUpdate,
    CanonicalProjectCreate,
    CanonicalProjectRead,
    CanonicalProjectUpdate,
    CompetitionParticipationCreate,
    CompetitionParticipationRead,
    CompetitionParticipationUpdate,
    CompetitionRecordMemoryCreate,
    CompetitionRecordMemoryRead,
    CompetitionRecordMemoryUpdate,
    InstitutionalEventCreate,
    InstitutionalEventRead,
    InstitutionalEventUpdate,
    InstitutionalFrameworkCreate,
    InstitutionalFrameworkRead,
    InstitutionalFrameworkUpdate,
    InstitutionalGenerationCreate,
    InstitutionalGenerationRead,
    InstitutionalGenerationUpdate,
    InstitutionalSourceCreate,
    InstitutionalSourceRead,
    InstitutionalSourceUpdate,
    LeadershipTermCreate,
    LeadershipTermRead,
    LeadershipTermUpdate,
    MemoryValidationRequest,
    ProjectAliasCreate,
    ProjectAliasRead,
    ProjectAliasUpdate,
    ProjectRelationshipCreate,
    ProjectRelationshipRead,
    ProjectRelationshipUpdate,
    ProjectYearCreate,
    ProjectYearRead,
    ProjectYearUpdate,
    TerritoryCreate,
    TerritoryRead,
    TerritoryUpdate,
)
from app.services.audit_service import create_audit_log


router = APIRouter(prefix="/institutional-memory", tags=["Institutional memory"])

FINAL_MEMORY_STATUSES = {"VERIFIED", "REJECTED", "SUPERSEDED"}


def _not_found(label: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{label} introuvable")


def _get_or_404(db: Session, model, entity_id, label: str):
    entity = db.query(model).filter(model.id == entity_id).first()
    if entity is None:
        raise _not_found(label)
    return entity


def _is_memory_curator(db: Session, current_user) -> bool:
    return user_has_any_role(db, current_user.id, MEMORY_CURATOR_ROLES)


def _visible_memory_query(
    db: Session,
    model,
    current_user,
    *,
    review: bool = False,
):
    curator = _is_memory_curator(db, current_user)
    if review and not curator:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Le mode de revision est reserve aux curateurs de la memoire",
        )
    query = db.query(model)
    if not review:
        query = query.filter(model.validation_status == "VERIFIED")
    if curator:
        return query
    if model in {InstitutionalSource, InstitutionalEvent}:
        query = query.filter(model.visibility != "private")
    source_id = getattr(model, "source_id", None)
    if source_id is not None and model is not InstitutionalSource:
        query = query.filter(
            or_(
                source_id.is_(None),
                db.query(InstitutionalSource.id)
                .filter(
                    InstitutionalSource.id == source_id,
                    InstitutionalSource.visibility != "private",
                )
                .exists(),
            )
        )
    return query


def _get_visible_or_404(
    db: Session,
    model,
    entity_id,
    label: str,
    current_user,
    *,
    review: bool = False,
):
    entity = (
        _visible_memory_query(db, model, current_user, review=review)
        .filter(model.id == entity_id)
        .first()
    )
    if entity is None:
        raise _not_found(label)
    return entity


def _ensure_editable_status(value: str | None) -> None:
    if value in FINAL_MEMORY_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Utilisez une action explicite de validation ou de rejet",
        )


def _ensure_source(db: Session, source_id, current_user) -> None:
    if source_id is None:
        return
    source = db.query(InstitutionalSource).filter(InstitutionalSource.id == source_id).first()
    if source is None or (source.visibility == "private" and not _is_memory_curator(db, current_user)):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Source institutionnelle introuvable",
        )


def _ensure_file_reference(db: Session, current_user, file_id) -> None:
    if file_id is None:
        return
    stored_file = get_file_or_404(db, str(file_id))
    ensure_file_access(db, stored_file, current_user, manage=True)


def _ensure_document_reference(db: Session, current_user, document_id) -> None:
    if document_id is None:
        return
    document = (
        visible_documents_query(db, current_user)
        .filter(Document.id == document_id)
        .first()
    )
    if document is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Document source introuvable ou non autorise",
        )


def _normalize_slug(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "-", value.strip().lower()).strip("-")
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cle projet invalide",
        )
    return normalized


def _commit(db: Session, *, conflict_detail: str):
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=conflict_detail,
        ) from error


def _create_entity(db, model, payload, current_user, *, conflict_detail: str):
    data = payload.model_dump()
    _ensure_editable_status(data.get("validation_status"))
    _ensure_source(db, data.get("source_id"), current_user)
    entity = model(**data, created_by_id=current_user.id)
    db.add(entity)
    _commit(db, conflict_detail=conflict_detail)
    db.refresh(entity)
    return entity


def _update_entity(
    db,
    entity,
    payload,
    create_schema,
    current_user,
    *,
    conflict_detail: str,
):
    if entity.validation_status in FINAL_MEMORY_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un fait finalise ne peut pas etre modifie directement",
        )
    updates = payload.model_dump(exclude_unset=True)
    _ensure_editable_status(updates.get("validation_status"))
    current = {
        name: getattr(entity, name)
        for name in create_schema.model_fields
    }
    validated = create_schema.model_validate({**current, **updates}).model_dump()
    _ensure_source(db, validated.get("source_id"), current_user)
    for field, value in validated.items():
        setattr(entity, field, value)
    entity.updated_at = datetime.utcnow()
    _commit(db, conflict_detail=conflict_detail)
    db.refresh(entity)
    return entity


RESOURCE_MODELS = {
    "sources": InstitutionalSource,
    "territories": Territory,
    "generations": InstitutionalGeneration,
    "leadership-terms": LeadershipTerm,
    "canonical-projects": CanonicalProject,
    "project-aliases": ProjectAlias,
    "project-years": ProjectYear,
    "project-relationships": ProjectRelationship,
    "events": InstitutionalEvent,
    "frameworks": InstitutionalFramework,
    "competitions": CompetitionRecord,
    "competition-participations": CompetitionParticipation,
    "awards": Award,
}


@router.get("/overview")
def memory_overview(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    visible_events = _visible_memory_query(db, InstitutionalEvent, current_user)
    years = [
        value
        for model, column in (
            (InstitutionalGeneration, InstitutionalGeneration.start_year),
            (CanonicalProject, CanonicalProject.first_year),
            (ProjectYear, ProjectYear.year),
            (CompetitionRecord, CompetitionRecord.year),
            (Award, Award.year),
        )
        for value in [
            _visible_memory_query(db, model, current_user)
            .with_entities(func.min(column))
            .scalar(),
            _visible_memory_query(db, model, current_user)
            .with_entities(func.max(column))
            .scalar(),
        ]
        if value is not None
    ]
    years.extend(
        value
        for value in (
            visible_events.with_entities(func.min(InstitutionalEvent.year)).scalar(),
            visible_events.with_entities(func.max(InstitutionalEvent.year)).scalar(),
        )
        if value is not None
    )
    return {
        "known_generations": _visible_memory_query(db, InstitutionalGeneration, current_user).count(),
        "known_projects": _visible_memory_query(db, CanonicalProject, current_user).count(),
        "known_events": visible_events.with_entities(
            func.count(InstitutionalEvent.id)
        ).scalar()
        or 0,
        "known_awards": _visible_memory_query(db, Award, current_user).count(),
        "known_territories": _visible_memory_query(db, Territory, current_user).count(),
        "earliest_year": min(years) if years else None,
        "latest_year": max(years) if years else None,
    }


@router.get("/sources", response_model=list[InstitutionalSourceRead])
def list_sources(
    year: int | None = None,
    source_type: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, InstitutionalSource, current_user, review=review)
    if year is not None:
        query = query.filter(InstitutionalSource.year == year)
    if source_type:
        query = query.filter(InstitutionalSource.source_type == source_type)
    if validation_status:
        query = query.filter(InstitutionalSource.validation_status == validation_status)
    return query.order_by(InstitutionalSource.year.desc().nullslast(), InstitutionalSource.title).all()


@router.post("/sources", response_model=InstitutionalSourceRead)
def create_source(
    payload: InstitutionalSourceCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    _ensure_file_reference(db, current_user, payload.file_id)
    _ensure_document_reference(db, current_user, payload.document_id)
    return _create_entity(
        db, InstitutionalSource, payload, current_user,
        conflict_detail="Cette source existe deja",
    )


@router.patch("/sources/{entity_id}", response_model=InstitutionalSourceRead)
def update_source(
    entity_id: str,
    payload: InstitutionalSourceUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    source = _get_or_404(db, InstitutionalSource, entity_id, "Source institutionnelle")
    data = payload.model_dump(exclude_unset=True)
    if "file_id" in data:
        _ensure_file_reference(db, current_user, data["file_id"])
    if "document_id" in data:
        _ensure_document_reference(db, current_user, data["document_id"])
    return _update_entity(
        db, source, payload, InstitutionalSourceCreate, current_user,
        conflict_detail="Cette source existe deja",
    )


@router.get("/territories", response_model=list[TerritoryRead])
def list_territories(
    country: str | None = None,
    region: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, Territory, current_user, review=review)
    if country:
        query = query.filter(Territory.country == country)
    if region:
        query = query.filter(Territory.region == region)
    if validation_status:
        query = query.filter(Territory.validation_status == validation_status)
    return query.order_by(Territory.country, Territory.region, Territory.name).all()


@router.post("/territories", response_model=TerritoryRead)
def create_territory(payload: TerritoryCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _create_entity(db, Territory, payload, current_user, conflict_detail="Ce territoire existe deja")


@router.patch("/territories/{entity_id}", response_model=TerritoryRead)
def update_territory(entity_id: str, payload: TerritoryUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _update_entity(db, _get_or_404(db, Territory, entity_id, "Territoire"), payload, TerritoryCreate, current_user, conflict_detail="Ce territoire existe deja")


@router.get("/generations", response_model=list[InstitutionalGenerationRead])
def list_generations(
    start_year: int | None = None,
    end_year: int | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, InstitutionalGeneration, current_user, review=review)
    if start_year is not None:
        query = query.filter(or_(InstitutionalGeneration.end_year.is_(None), InstitutionalGeneration.end_year >= start_year))
    if end_year is not None:
        query = query.filter(InstitutionalGeneration.start_year <= end_year)
    if validation_status:
        query = query.filter(InstitutionalGeneration.validation_status == validation_status)
    return query.order_by(InstitutionalGeneration.start_year.desc()).all()


@router.post("/generations", response_model=InstitutionalGenerationRead)
def create_generation(payload: InstitutionalGenerationCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _create_entity(db, InstitutionalGeneration, payload, current_user, conflict_detail="Cette generation existe deja")


@router.patch("/generations/{entity_id}", response_model=InstitutionalGenerationRead)
def update_generation(entity_id: str, payload: InstitutionalGenerationUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _update_entity(db, _get_or_404(db, InstitutionalGeneration, entity_id, "Generation"), payload, InstitutionalGenerationCreate, current_user, conflict_detail="Cette generation existe deja")


@router.get("/leadership-terms", response_model=list[LeadershipTermRead])
def list_leadership_terms(
    year: int | None = None,
    generation_id: str | None = None,
    pole_id: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, LeadershipTerm, current_user, review=review)
    if year is not None:
        query = query.filter(LeadershipTerm.start_year <= year, or_(LeadershipTerm.end_year.is_(None), LeadershipTerm.end_year >= year))
    if generation_id:
        query = query.filter(LeadershipTerm.generation_id == generation_id)
    if pole_id:
        query = query.filter(LeadershipTerm.pole_id == pole_id)
    if validation_status:
        query = query.filter(LeadershipTerm.validation_status == validation_status)
    return query.order_by(LeadershipTerm.start_year.desc(), LeadershipTerm.role_label).all()


@router.post("/leadership-terms", response_model=LeadershipTermRead)
def create_leadership_term(payload: LeadershipTermCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _create_entity(db, LeadershipTerm, payload, current_user, conflict_detail="Ce mandat historique existe deja")


@router.patch("/leadership-terms/{entity_id}", response_model=LeadershipTermRead)
def update_leadership_term(entity_id: str, payload: LeadershipTermUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _update_entity(db, _get_or_404(db, LeadershipTerm, entity_id, "Mandat historique"), payload, LeadershipTermCreate, current_user, conflict_detail="Mandat historique invalide")


@router.get("/canonical-projects", response_model=list[CanonicalProjectRead])
def list_canonical_projects(
    year: int | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, CanonicalProject, current_user, review=review)
    if year is not None:
        query = query.filter(or_(CanonicalProject.first_year.is_(None), CanonicalProject.first_year <= year), or_(CanonicalProject.last_year.is_(None), CanonicalProject.last_year >= year))
    if validation_status:
        query = query.filter(CanonicalProject.validation_status == validation_status)
    return query.order_by(CanonicalProject.canonical_name).all()


@router.post("/canonical-projects", response_model=CanonicalProjectRead)
def create_canonical_project(payload: CanonicalProjectCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    payload = payload.model_copy(update={"slug": _normalize_slug(payload.slug)})
    return _create_entity(db, CanonicalProject, payload, current_user, conflict_detail="Cette identite projet existe deja")


@router.patch("/canonical-projects/{entity_id}", response_model=CanonicalProjectRead)
def update_canonical_project(entity_id: str, payload: CanonicalProjectUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    if payload.slug is not None:
        payload = payload.model_copy(update={"slug": _normalize_slug(payload.slug)})
    return _update_entity(db, _get_or_404(db, CanonicalProject, entity_id, "Projet canonique"), payload, CanonicalProjectCreate, current_user, conflict_detail="Cette identite projet existe deja")


@router.get("/project-aliases", response_model=list[ProjectAliasRead])
def list_project_aliases(
    project: str | None = None,
    year: int | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, ProjectAlias, current_user, review=review)
    if project:
        query = query.filter(ProjectAlias.canonical_project_id == project)
    if year is not None:
        query = query.filter(or_(ProjectAlias.start_year.is_(None), ProjectAlias.start_year <= year), or_(ProjectAlias.end_year.is_(None), ProjectAlias.end_year >= year))
    if validation_status:
        query = query.filter(ProjectAlias.validation_status == validation_status)
    return query.order_by(ProjectAlias.alias).all()


@router.post("/project-aliases", response_model=ProjectAliasRead)
def create_project_alias(payload: ProjectAliasCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    payload = payload.model_copy(update={"alias": payload.alias.strip()})
    return _create_entity(db, ProjectAlias, payload, current_user, conflict_detail="Cet alias projet existe deja")


@router.patch("/project-aliases/{entity_id}", response_model=ProjectAliasRead)
def update_project_alias(entity_id: str, payload: ProjectAliasUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    if payload.alias is not None:
        payload = payload.model_copy(update={"alias": payload.alias.strip()})
    return _update_entity(db, _get_or_404(db, ProjectAlias, entity_id, "Alias projet"), payload, ProjectAliasCreate, current_user, conflict_detail="Cet alias projet existe deja")


@router.get("/project-years", response_model=list[ProjectYearRead])
def list_project_years(
    year: int | None = None,
    project: str | None = None,
    territory: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, ProjectYear, current_user, review=review)
    if year is not None:
        query = query.filter(ProjectYear.year == year)
    if project:
        query = query.filter(ProjectYear.canonical_project_id == project)
    if territory:
        query = query.filter(ProjectYear.territory_id == territory)
    if validation_status:
        query = query.filter(ProjectYear.validation_status == validation_status)
    return query.order_by(ProjectYear.year.desc()).all()


@router.post("/project-years", response_model=ProjectYearRead)
def create_project_year(payload: ProjectYearCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _create_entity(db, ProjectYear, payload, current_user, conflict_detail="Cette annee projet existe deja")


@router.patch("/project-years/{entity_id}", response_model=ProjectYearRead)
def update_project_year(entity_id: str, payload: ProjectYearUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _update_entity(db, _get_or_404(db, ProjectYear, entity_id, "Annee projet"), payload, ProjectYearCreate, current_user, conflict_detail="Cette annee projet existe deja")


@router.get("/project-relationships", response_model=list[ProjectRelationshipRead])
def list_project_relationships(
    project: str | None = None,
    year: int | None = None,
    relationship_type: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, ProjectRelationship, current_user, review=review)
    if project:
        query = query.filter(or_(ProjectRelationship.source_project_id == project, ProjectRelationship.target_project_id == project))
    if year is not None:
        query = query.filter(ProjectRelationship.year == year)
    if relationship_type:
        query = query.filter(ProjectRelationship.relationship_type == relationship_type)
    if validation_status:
        query = query.filter(ProjectRelationship.validation_status == validation_status)
    return query.order_by(ProjectRelationship.year.desc().nullslast()).all()


@router.post("/project-relationships", response_model=ProjectRelationshipRead)
def create_project_relationship(payload: ProjectRelationshipCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _create_entity(db, ProjectRelationship, payload, current_user, conflict_detail="Cette relation projet est invalide ou existe deja")


@router.patch("/project-relationships/{entity_id}", response_model=ProjectRelationshipRead)
def update_project_relationship(entity_id: str, payload: ProjectRelationshipUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _update_entity(db, _get_or_404(db, ProjectRelationship, entity_id, "Relation projet"), payload, ProjectRelationshipCreate, current_user, conflict_detail="Cette relation projet est invalide")


@router.get("/events", response_model=list[InstitutionalEventRead])
def list_events(
    year: int | None = None,
    start_year: int | None = None,
    end_year: int | None = None,
    project: str | None = None,
    generation: str | None = None,
    event_type: str | None = None,
    territory: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, InstitutionalEvent, current_user, review=review)
    if year is not None:
        query = query.filter(InstitutionalEvent.year == year)
    if start_year is not None:
        query = query.filter(InstitutionalEvent.year >= start_year)
    if end_year is not None:
        query = query.filter(InstitutionalEvent.year <= end_year)
    if project:
        query = query.filter(InstitutionalEvent.canonical_project_id == project)
    if generation:
        query = query.filter(InstitutionalEvent.generation_id == generation)
    if event_type:
        query = query.filter(InstitutionalEvent.event_type == event_type)
    if territory:
        query = query.filter(InstitutionalEvent.territory_id == territory)
    if validation_status:
        query = query.filter(InstitutionalEvent.validation_status == validation_status)
    return query.order_by(InstitutionalEvent.year.desc(), InstitutionalEvent.event_date.desc().nullslast()).all()


@router.post("/events", response_model=InstitutionalEventRead)
def create_event(payload: InstitutionalEventCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _create_entity(db, InstitutionalEvent, payload, current_user, conflict_detail="Cet evenement est invalide")


@router.patch("/events/{entity_id}", response_model=InstitutionalEventRead)
def update_event(entity_id: str, payload: InstitutionalEventUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _update_entity(db, _get_or_404(db, InstitutionalEvent, entity_id, "Evenement institutionnel"), payload, InstitutionalEventCreate, current_user, conflict_detail="Cet evenement est invalide")


@router.get("/frameworks", response_model=list[InstitutionalFrameworkRead])
def list_frameworks(
    year: int | None = None,
    framework_type: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, InstitutionalFramework, current_user, review=review)
    if year is not None:
        query = query.filter(InstitutionalFramework.effective_from_year <= year, or_(InstitutionalFramework.effective_to_year.is_(None), InstitutionalFramework.effective_to_year >= year))
    if framework_type:
        query = query.filter(InstitutionalFramework.framework_type == framework_type)
    if validation_status:
        query = query.filter(InstitutionalFramework.validation_status == validation_status)
    return query.order_by(InstitutionalFramework.effective_from_year.desc()).all()


@router.post("/frameworks", response_model=InstitutionalFrameworkRead)
def create_framework(payload: InstitutionalFrameworkCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _create_entity(db, InstitutionalFramework, payload, current_user, conflict_detail="Cette version de referentiel existe deja")


@router.patch("/frameworks/{entity_id}", response_model=InstitutionalFrameworkRead)
def update_framework(entity_id: str, payload: InstitutionalFrameworkUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _update_entity(db, _get_or_404(db, InstitutionalFramework, entity_id, "Referentiel institutionnel"), payload, InstitutionalFrameworkCreate, current_user, conflict_detail="Cette version de referentiel existe deja")


@router.get("/competitions", response_model=list[CompetitionRecordMemoryRead])
def list_competitions(
    year: int | None = None,
    territory: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, CompetitionRecord, current_user, review=review)
    if year is not None:
        query = query.filter(CompetitionRecord.year == year)
    if territory:
        query = query.filter(CompetitionRecord.territory_id == territory)
    if validation_status:
        query = query.filter(CompetitionRecord.validation_status == validation_status)
    return query.order_by(CompetitionRecord.year.desc().nullslast(), CompetitionRecord.name).all()


@router.post("/competitions", response_model=CompetitionRecordMemoryRead)
def create_competition(payload: CompetitionRecordMemoryCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    _ensure_file_reference(db, current_user, payload.file_id)
    return _create_entity(db, CompetitionRecord, payload, current_user, conflict_detail="Cette edition de competition existe deja")


@router.patch("/competitions/{entity_id}", response_model=CompetitionRecordMemoryRead)
def update_competition(entity_id: str, payload: CompetitionRecordMemoryUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    if "file_id" in payload.model_fields_set:
        _ensure_file_reference(db, current_user, payload.file_id)
    return _update_entity(db, _get_or_404(db, CompetitionRecord, entity_id, "Competition"), payload, CompetitionRecordMemoryCreate, current_user, conflict_detail="Cette edition de competition est invalide")


@router.get("/competition-participations", response_model=list[CompetitionParticipationRead])
def list_competition_participations(
    competition: str | None = None,
    project: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, CompetitionParticipation, current_user, review=review)
    if competition:
        query = query.filter(CompetitionParticipation.competition_record_id == competition)
    if project:
        query = query.filter(CompetitionParticipation.canonical_project_id == project)
    if validation_status:
        query = query.filter(CompetitionParticipation.validation_status == validation_status)
    return query.order_by(CompetitionParticipation.created_at).all()


@router.post("/competition-participations", response_model=CompetitionParticipationRead)
def create_competition_participation(payload: CompetitionParticipationCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _create_entity(db, CompetitionParticipation, payload, current_user, conflict_detail="Cette participation existe deja")


@router.patch("/competition-participations/{entity_id}", response_model=CompetitionParticipationRead)
def update_competition_participation(entity_id: str, payload: CompetitionParticipationUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    return _update_entity(db, _get_or_404(db, CompetitionParticipation, entity_id, "Participation"), payload, CompetitionParticipationCreate, current_user, conflict_detail="Cette participation est invalide ou existe deja")


@router.get("/awards", response_model=list[AwardMemoryRead])
def list_awards(
    year: int | None = None,
    project: str | None = None,
    validation_status: str | None = None,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, Award, current_user, review=review)
    if year is not None:
        query = query.filter(Award.year == year)
    if project:
        query = query.filter(Award.canonical_project_id == project)
    if validation_status:
        query = query.filter(Award.validation_status == validation_status)
    return query.order_by(Award.year.desc().nullslast(), Award.title).all()


@router.post("/awards", response_model=AwardMemoryRead)
def create_award(payload: AwardMemoryCreate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    _ensure_file_reference(db, current_user, payload.file_id)
    return _create_entity(db, Award, payload, current_user, conflict_detail="Cette distinction existe deja")


@router.patch("/awards/{entity_id}", response_model=AwardMemoryRead)
def update_award(entity_id: str, payload: AwardMemoryUpdate, db: Session = Depends(get_db), current_user=Depends(require_memory_curator)):
    if "file_id" in payload.model_fields_set:
        _ensure_file_reference(db, current_user, payload.file_id)
    return _update_entity(db, _get_or_404(db, Award, entity_id, "Distinction"), payload, AwardMemoryCreate, current_user, conflict_detail="Cette distinction est invalide")


def _timeline_select(
    model,
    *,
    resource_type: str,
    title,
    summary,
    year,
    effective_date=None,
    captured_at=None,
    origin=None,
    source_id=None,
    source_entity_type=None,
    source_entity_id=None,
    source_entity_version=None,
    canonical_project_id=None,
    related_canonical_project_id=None,
    operational_project_id=None,
    pole_id=None,
    member_id=None,
    operational_event_id=None,
    generation_id=None,
    territory_id=None,
    competition_id=None,
):
    null_string = cast(literal(None), String)
    null_date = cast(literal(None), Date)
    null_datetime = cast(literal(None), DateTime)
    return select(
        cast(model.id, String).label("id"),
        literal(resource_type).label("resource_type"),
        cast(title, String).label("title"),
        cast(summary, String).label("summary"),
        year.label("year"),
        (effective_date if effective_date is not None else null_date).label("effective_date"),
        model.validation_status.label("validation_status"),
        (origin if origin is not None else literal("manual")).label("origin"),
        (captured_at if captured_at is not None else null_datetime).label("captured_at"),
        model.created_at.label("created_at"),
        model.updated_at.label("updated_at"),
        model.validated_at.label("validated_at"),
        cast(source_id if source_id is not None else null_string, String).label("source_id"),
        cast(source_entity_type if source_entity_type is not None else null_string, String).label("source_entity_type"),
        cast(source_entity_id if source_entity_id is not None else null_string, String).label("source_entity_id"),
        cast(source_entity_version if source_entity_version is not None else null_string, String).label("source_entity_version"),
        cast(canonical_project_id if canonical_project_id is not None else null_string, String).label("canonical_project_id"),
        cast(related_canonical_project_id if related_canonical_project_id is not None else null_string, String).label("related_canonical_project_id"),
        cast(operational_project_id if operational_project_id is not None else null_string, String).label("operational_project_id"),
        cast(pole_id if pole_id is not None else null_string, String).label("pole_id"),
        cast(member_id if member_id is not None else null_string, String).label("member_id"),
        cast(operational_event_id if operational_event_id is not None else null_string, String).label("operational_event_id"),
        cast(generation_id if generation_id is not None else null_string, String).label("generation_id"),
        cast(territory_id if territory_id is not None else null_string, String).label("territory_id"),
        cast(competition_id if competition_id is not None else null_string, String).label("competition_id"),
    )


def _timeline_union(db: Session, current_user, *, review: bool):
    curator = _is_memory_curator(db, current_user)
    if review and not curator:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Le mode de revision est reserve aux curateurs de la memoire",
        )

    statements = [
        _timeline_select(
            InstitutionalEvent,
            resource_type="institutional_event",
            title=InstitutionalEvent.title,
            summary=InstitutionalEvent.description,
            year=InstitutionalEvent.year,
            effective_date=InstitutionalEvent.event_date,
            captured_at=InstitutionalEvent.captured_at,
            origin=InstitutionalEvent.origin,
            source_id=InstitutionalEvent.source_id,
            source_entity_type=InstitutionalEvent.source_entity_type,
            source_entity_id=InstitutionalEvent.source_entity_id,
            source_entity_version=InstitutionalEvent.source_entity_version,
            canonical_project_id=InstitutionalEvent.canonical_project_id,
            operational_project_id=InstitutionalEvent.operational_project_id,
            pole_id=InstitutionalEvent.pole_id,
            operational_event_id=InstitutionalEvent.operational_event_id,
            generation_id=InstitutionalEvent.generation_id,
            territory_id=InstitutionalEvent.territory_id,
        ),
        _timeline_select(
            LeadershipTerm,
            resource_type="leadership_term",
            title=LeadershipTerm.role_label,
            summary=LeadershipTerm.display_name,
            year=LeadershipTerm.start_year,
            source_id=LeadershipTerm.source_id,
            pole_id=LeadershipTerm.pole_id,
            member_id=LeadershipTerm.user_id,
            generation_id=LeadershipTerm.generation_id,
        ),
        _timeline_select(
            ProjectYear,
            resource_type="project_year",
            title=func.coalesce(ProjectYear.display_name, literal("Annee de projet")),
            summary=func.coalesce(ProjectYear.solution_summary, ProjectYear.problem_summary),
            year=ProjectYear.year,
            source_id=ProjectYear.source_id,
            canonical_project_id=ProjectYear.canonical_project_id,
            operational_project_id=ProjectYear.operational_project_id,
            territory_id=ProjectYear.territory_id,
        ),
        _timeline_select(
            ProjectRelationship,
            resource_type="project_relationship",
            title=ProjectRelationship.relationship_type,
            summary=ProjectRelationship.notes,
            year=ProjectRelationship.year,
            source_id=ProjectRelationship.source_id,
            canonical_project_id=ProjectRelationship.source_project_id,
            related_canonical_project_id=ProjectRelationship.target_project_id,
        ).where(ProjectRelationship.year.is_not(None)),
        _timeline_select(
            CompetitionRecord,
            resource_type="competition",
            title=CompetitionRecord.name,
            summary=CompetitionRecord.description,
            year=CompetitionRecord.year,
            source_id=CompetitionRecord.source_id,
            territory_id=CompetitionRecord.territory_id,
            competition_id=CompetitionRecord.id,
        ).where(CompetitionRecord.year.is_not(None)),
        _timeline_select(
            Award,
            resource_type="award",
            title=Award.title,
            summary=Award.description,
            year=Award.year,
            source_id=Award.source_id,
            canonical_project_id=Award.canonical_project_id,
            competition_id=Award.competition_record_id,
        ).where(Award.year.is_not(None)),
        _timeline_select(
            InstitutionalFramework,
            resource_type="framework",
            title=InstitutionalFramework.name,
            summary=InstitutionalFramework.description,
            year=InstitutionalFramework.effective_from_year,
            source_id=InstitutionalFramework.source_id,
        ),
        _timeline_select(
            InstitutionalGeneration,
            resource_type="generation",
            title=InstitutionalGeneration.name,
            summary=InstitutionalGeneration.description,
            year=InstitutionalGeneration.start_year,
            source_id=InstitutionalGeneration.source_id,
            generation_id=InstitutionalGeneration.id,
        ),
    ]
    models = [
        InstitutionalEvent,
        LeadershipTerm,
        ProjectYear,
        ProjectRelationship,
        CompetitionRecord,
        Award,
        InstitutionalFramework,
        InstitutionalGeneration,
    ]
    for index, model in enumerate(models):
        if not review:
            statements[index] = statements[index].where(model.validation_status == "VERIFIED")
        if not curator:
            if model is InstitutionalEvent:
                statements[index] = statements[index].where(InstitutionalEvent.visibility != "private")
            statements[index] = statements[index].where(
                or_(
                    model.source_id.is_(None),
                    db.query(InstitutionalSource.id)
                    .filter(
                        InstitutionalSource.id == model.source_id,
                        InstitutionalSource.visibility != "private",
                    )
                    .exists(),
                )
            )
    return union_all(*statements).subquery("institutional_timeline")


def _encode_timeline_cursor(row) -> str:
    payload = [
        row.year,
        row.effective_date.isoformat() if row.effective_date else None,
        row.resource_type,
        row.id,
    ]
    return base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    ).decode("ascii").rstrip("=")


def _decode_timeline_cursor(cursor: str):
    try:
        padded = cursor + "=" * (-len(cursor) % 4)
        year, effective, resource_type, entity_id = json.loads(
            base64.urlsafe_b64decode(padded).decode("utf-8")
        )
        return int(year), date.fromisoformat(effective) if effective else None, str(resource_type), str(entity_id)
    except (ValueError, TypeError, json.JSONDecodeError) as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Curseur de chronologie invalide",
        ) from error


def _timeline_cursor_condition(timeline, cursor: str):
    cursor_year, cursor_date, cursor_type, cursor_id = _decode_timeline_cursor(cursor)
    after_identity = or_(
        timeline.c.resource_type > cursor_type,
        and_(timeline.c.resource_type == cursor_type, timeline.c.id > cursor_id),
    )
    if cursor_date is None:
        within_year = and_(timeline.c.effective_date.is_(None), after_identity)
    else:
        within_year = or_(
            timeline.c.effective_date < cursor_date,
            timeline.c.effective_date.is_(None),
            and_(timeline.c.effective_date == cursor_date, after_identity),
        )
    return or_(timeline.c.year < cursor_year, and_(timeline.c.year == cursor_year, within_year))


def _timeline_source_payload(
    db: Session,
    current_user,
    source_id: str | None,
    *,
    review: bool,
):
    if not source_id:
        return None
    source = (
        _visible_memory_query(
            db,
            InstitutionalSource,
            current_user,
            review=review,
        )
        .filter(InstitutionalSource.id == source_id)
        .first()
    )
    if source is None:
        return None
    capability = None
    if source.file_id:
        try:
            stored_file = get_file_or_404(db, str(source.file_id))
            ensure_file_access(db, stored_file, current_user)
        except HTTPException:
            pass
        # Protected file routes require the EnactSpace Bearer credential. Until
        # an authenticated in-app byte viewer exists, source metadata is safe
        # but advertising an external-launch capability would be misleading.
    elif source.document_id:
        visible_document = (
            visible_documents_query(db, current_user)
            .filter(Document.id == source.document_id)
            .first()
        )
        if visible_document is not None:
            capability = {"type": "document", "url": f"/api/documents/{source.document_id}"}
    elif source.external_url:
        capability = {"type": "external_url", "url": source.external_url}
    return {
        "id": str(source.id),
        "type": source.source_type,
        "label": source.source_label or source.title,
        "capability": capability,
    }


def _timeline_related_entities(
    db: Session,
    current_user,
    row,
    *,
    review: bool,
) -> list[dict]:
    references = (
        ("canonical_project", row.canonical_project_id, CanonicalProject, "canonical_name"),
        ("canonical_project", row.related_canonical_project_id, CanonicalProject, "canonical_name"),
        ("project", row.operational_project_id, Project, "name"),
        ("pole", row.pole_id, Pole, "name"),
        ("member", row.member_id, User, None),
        ("event", row.operational_event_id, Event, "title"),
        ("generation", row.generation_id, InstitutionalGeneration, "name"),
        ("territory", row.territory_id, Territory, "name"),
        ("competition", row.competition_id, CompetitionRecord, "name"),
    )
    related = []
    seen = set()
    for entity_type, entity_id, model, label_field in references:
        identity = (entity_type, entity_id)
        if not entity_id or identity in seen:
            continue
        seen.add(identity)
        if model in {
            CanonicalProject,
            InstitutionalGeneration,
            Territory,
            CompetitionRecord,
        }:
            entity = (
                _visible_memory_query(db, model, current_user, review=review)
                .filter(model.id == entity_id)
                .first()
            )
        else:
            entity = db.query(model).filter(model.id == entity_id).first()
        if entity is None:
            related.append({"type": entity_type, "id": entity_id, "label": "Element indisponible", "available": False})
            continue
        if model is User:
            label = f"{entity.first_name} {entity.last_name}".strip()
        else:
            label = getattr(entity, label_field)
        related.append({"type": entity_type, "id": entity_id, "label": label, "available": True})

    source_entity_id = row.source_entity_id
    source_entity_type = row.source_entity_type
    source_models = {
        "project": (Project, "name"),
        "attendance_session": (AttendanceSession, "title"),
    }
    if source_entity_id and source_entity_type in source_models:
        identity = (source_entity_type, source_entity_id)
        if identity not in seen:
            model, label_field = source_models[source_entity_type]
            entity = db.query(model).filter(model.id == source_entity_id).first()
            related.append(
                {
                    "type": source_entity_type,
                    "id": source_entity_id,
                    "label": getattr(entity, label_field)
                    if entity is not None
                    else "Element source indisponible",
                    "available": entity is not None,
                }
            )
    return related


def _timeline_item_payload(
    db: Session,
    current_user,
    row,
    *,
    review: bool,
) -> dict:
    return {
        "id": row.id,
        "resource_type": row.resource_type,
        "title": row.title,
        "summary": row.summary,
        "year": row.year,
        "effective_date": row.effective_date,
        "date_precision": "exact" if row.effective_date else "year",
        "validation_status": row.validation_status,
        "origin": row.origin,
        "captured_at": row.captured_at,
        "created_at": row.created_at,
        "updated_at": row.updated_at,
        "validated_at": row.validated_at,
        "source_entity_type": row.source_entity_type,
        "source_entity_id": row.source_entity_id,
        "source_entity_version": row.source_entity_version,
        "source": _timeline_source_payload(
            db,
            current_user,
            row.source_id,
            review=review,
        ),
        "related_entities": _timeline_related_entities(
            db,
            current_user,
            row,
            review=review,
        ),
    }


@router.get("/timeline")
def list_timeline(
    start_year: int | None = None,
    end_year: int | None = None,
    resource_type: str | None = Query(default=None, alias="type"),
    project_id: str | None = None,
    pole_id: str | None = None,
    member_id: str | None = None,
    event_id: str | None = None,
    validation_status: str | None = None,
    search: str | None = None,
    review: bool = False,
    limit: int = Query(default=25, ge=1, le=100),
    cursor: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    timeline = _timeline_union(db, current_user, review=review)
    query = select(timeline)
    if start_year is not None:
        query = query.where(timeline.c.year >= start_year)
    if end_year is not None:
        query = query.where(timeline.c.year <= end_year)
    if resource_type:
        query = query.where(timeline.c.resource_type == resource_type)
    if project_id:
        canonical_project_ids = [
            str(value)
            for value, in db.query(CanonicalProject.id)
            .filter(CanonicalProject.current_project_id == project_id)
            .all()
        ]
        project_keys = [project_id, *canonical_project_ids]
        query = query.where(
            or_(
                timeline.c.canonical_project_id.in_(project_keys),
                timeline.c.related_canonical_project_id.in_(project_keys),
                timeline.c.operational_project_id == project_id,
            )
        )
    if pole_id:
        query = query.where(timeline.c.pole_id == pole_id)
    if member_id:
        query = query.where(timeline.c.member_id == member_id)
    if event_id:
        query = query.where(timeline.c.operational_event_id == event_id)
    if validation_status:
        if not review and validation_status != "VERIFIED":
            raise HTTPException(status_code=403, detail="Le statut demande requiert le mode de revision")
        query = query.where(timeline.c.validation_status == validation_status)
    if search and search.strip():
        pattern = f"%{search.strip().lower()}%"
        query = query.where(
            or_(func.lower(timeline.c.title).like(pattern), func.lower(func.coalesce(timeline.c.summary, "")).like(pattern))
        )
    if cursor:
        query = query.where(_timeline_cursor_condition(timeline, cursor))
    query = query.order_by(
        timeline.c.year.desc(),
        case((timeline.c.effective_date.is_not(None), 1), else_=0).desc(),
        timeline.c.effective_date.desc(),
        timeline.c.resource_type.asc(),
        timeline.c.id.asc(),
    ).limit(limit + 1)
    rows = db.execute(query).all()
    page_rows = rows[:limit]
    return {
        "items": [
            _timeline_item_payload(
                db,
                current_user,
                row,
                review=review,
            )
            for row in page_rows
        ],
        "next_cursor": _encode_timeline_cursor(page_rows[-1]) if len(rows) > limit else None,
    }


@router.get("/timeline/{resource_type}/{entity_id}")
def get_timeline_detail(
    resource_type: str,
    entity_id: str,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    timeline = _timeline_union(db, current_user, review=review)
    row = db.execute(
        select(timeline).where(
            timeline.c.resource_type == resource_type,
            timeline.c.id == entity_id,
        )
    ).first()
    if row is None:
        raise _not_found("Element de chronologie")
    return _timeline_item_payload(
        db,
        current_user,
        row,
        review=review,
    )


@router.get("/{resource}/{entity_id}")
def get_memory_entity(
    resource: str,
    entity_id: str,
    review: bool = False,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    model = RESOURCE_MODELS.get(resource)
    if model is None:
        raise _not_found("Ressource institutionnelle")
    return _get_visible_or_404(
        db, model, entity_id, "Fait institutionnel", current_user, review=review
    )


@router.post("/{resource}/{entity_id}/validate")
def validate_memory_entity(
    resource: str,
    entity_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    model = RESOURCE_MODELS.get(resource)
    if model is None:
        raise _not_found("Ressource institutionnelle")
    entity = _get_or_404(db, model, entity_id, "Fait institutionnel")
    if entity.validation_status in FINAL_MEMORY_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un fait finalise ne peut pas etre valide de nouveau",
        )
    if model is InstitutionalSource:
        has_anchor = bool(
            entity.document_id
            or entity.file_id
            or (entity.external_url or "").strip()
            or (entity.source_label or "").strip()
        )
    else:
        has_anchor = entity.source_id is not None
    if not has_anchor:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Une source structuree est requise avant validation",
        )
    entity.validation_status = "VERIFIED"
    entity.validated_by_id = current_user.id
    entity.validated_at = datetime.utcnow()
    entity.updated_at = datetime.utcnow()
    create_audit_log(
        db,
        "institutional_memory_verified",
        current_user.id,
        resource,
        entity.id,
    )
    db.commit()
    db.refresh(entity)
    return entity


@router.post("/{resource}/{entity_id}/reject")
def reject_memory_entity(
    resource: str,
    entity_id: str,
    payload: MemoryValidationRequest,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    model = RESOURCE_MODELS.get(resource)
    if model is None:
        raise _not_found("Ressource institutionnelle")
    entity = _get_or_404(db, model, entity_id, "Fait institutionnel")
    if entity.validation_status in FINAL_MEMORY_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un fait finalise ne peut pas etre rejete de nouveau",
        )
    if not (payload.reason or "").strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le motif de rejet est obligatoire",
        )
    entity.validation_status = "REJECTED"
    entity.validated_by_id = current_user.id
    entity.validated_at = datetime.utcnow()
    entity.updated_at = datetime.utcnow()
    create_audit_log(
        db,
        "institutional_memory_rejected",
        current_user.id,
        resource,
        entity.id,
        new_value={"reason": payload.reason.strip()},
    )
    db.commit()
    db.refresh(entity)
    return entity
