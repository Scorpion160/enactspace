import re
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    require_enacchef_or_admin,
    require_sg_or_admin,
    user_has_any_role,
)
from app.api.routes.documents import visible_documents_query
from app.api.routes.files import ensure_file_access, get_file_or_404
from app.core.roles import SECRETARIAT_ROLES
from app.db.database import get_db
from app.models.archive import Award, CompetitionRecord
from app.models.document import Document
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


def _visible_memory_query(db: Session, model, current_user):
    query = db.query(model)
    if user_has_any_role(db, current_user.id, SECRETARIAT_ROLES):
        return query
    return query.filter(
        or_(model.visibility != "private", model.created_by_id == current_user.id)
    )


def _get_visible_or_404(db: Session, model, entity_id, label: str, current_user):
    if model in {InstitutionalSource, InstitutionalEvent}:
        entity = (
            _visible_memory_query(db, model, current_user)
            .filter(model.id == entity_id)
            .first()
        )
        if entity is None:
            raise _not_found(label)
        return entity
    return _get_or_404(db, model, entity_id, label)


def _ensure_editable_status(value: str | None) -> None:
    if value in FINAL_MEMORY_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Utilisez une action explicite de validation ou de rejet",
        )


def _ensure_source(db: Session, source_id, current_user) -> None:
    if source_id is None:
        return
    if (
        _visible_memory_query(db, InstitutionalSource, current_user)
        .filter(InstitutionalSource.id == source_id)
        .first()
        is None
    ):
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
        for value in [db.query(func.min(column)).scalar(), db.query(func.max(column)).scalar()]
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
        "known_generations": db.query(func.count(InstitutionalGeneration.id)).scalar() or 0,
        "known_projects": db.query(func.count(CanonicalProject.id)).scalar() or 0,
        "known_events": visible_events.with_entities(
            func.count(InstitutionalEvent.id)
        ).scalar()
        or 0,
        "known_awards": db.query(func.count(Award.id)).scalar() or 0,
        "known_territories": db.query(func.count(Territory.id)).scalar() or 0,
        "earliest_year": min(years) if years else None,
        "latest_year": max(years) if years else None,
    }


@router.get("/sources", response_model=list[InstitutionalSourceRead])
def list_sources(
    year: int | None = None,
    source_type: str | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, InstitutionalSource, current_user)
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
    current_user=Depends(require_enacchef_or_admin),
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
    current_user=Depends(require_enacchef_or_admin),
):
    source = _get_visible_or_404(
        db, InstitutionalSource, entity_id, "Source institutionnelle", current_user
    )
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
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(Territory)
    if country:
        query = query.filter(Territory.country == country)
    if region:
        query = query.filter(Territory.region == region)
    if validation_status:
        query = query.filter(Territory.validation_status == validation_status)
    return query.order_by(Territory.country, Territory.region, Territory.name).all()


@router.post("/territories", response_model=TerritoryRead)
def create_territory(payload: TerritoryCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _create_entity(db, Territory, payload, current_user, conflict_detail="Ce territoire existe deja")


@router.patch("/territories/{entity_id}", response_model=TerritoryRead)
def update_territory(entity_id: str, payload: TerritoryUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _update_entity(db, _get_or_404(db, Territory, entity_id, "Territoire"), payload, TerritoryCreate, current_user, conflict_detail="Ce territoire existe deja")


@router.get("/generations", response_model=list[InstitutionalGenerationRead])
def list_generations(
    start_year: int | None = None,
    end_year: int | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(InstitutionalGeneration)
    if start_year is not None:
        query = query.filter(or_(InstitutionalGeneration.end_year.is_(None), InstitutionalGeneration.end_year >= start_year))
    if end_year is not None:
        query = query.filter(InstitutionalGeneration.start_year <= end_year)
    if validation_status:
        query = query.filter(InstitutionalGeneration.validation_status == validation_status)
    return query.order_by(InstitutionalGeneration.start_year.desc()).all()


@router.post("/generations", response_model=InstitutionalGenerationRead)
def create_generation(payload: InstitutionalGenerationCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _create_entity(db, InstitutionalGeneration, payload, current_user, conflict_detail="Cette generation existe deja")


@router.patch("/generations/{entity_id}", response_model=InstitutionalGenerationRead)
def update_generation(entity_id: str, payload: InstitutionalGenerationUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _update_entity(db, _get_or_404(db, InstitutionalGeneration, entity_id, "Generation"), payload, InstitutionalGenerationCreate, current_user, conflict_detail="Cette generation existe deja")


@router.get("/leadership-terms", response_model=list[LeadershipTermRead])
def list_leadership_terms(
    year: int | None = None,
    generation_id: str | None = None,
    pole_id: str | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(LeadershipTerm)
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
def create_leadership_term(payload: LeadershipTermCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _create_entity(db, LeadershipTerm, payload, current_user, conflict_detail="Ce mandat historique existe deja")


@router.patch("/leadership-terms/{entity_id}", response_model=LeadershipTermRead)
def update_leadership_term(entity_id: str, payload: LeadershipTermUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _update_entity(db, _get_or_404(db, LeadershipTerm, entity_id, "Mandat historique"), payload, LeadershipTermCreate, current_user, conflict_detail="Mandat historique invalide")


@router.get("/canonical-projects", response_model=list[CanonicalProjectRead])
def list_canonical_projects(
    year: int | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(CanonicalProject)
    if year is not None:
        query = query.filter(or_(CanonicalProject.first_year.is_(None), CanonicalProject.first_year <= year), or_(CanonicalProject.last_year.is_(None), CanonicalProject.last_year >= year))
    if validation_status:
        query = query.filter(CanonicalProject.validation_status == validation_status)
    return query.order_by(CanonicalProject.canonical_name).all()


@router.post("/canonical-projects", response_model=CanonicalProjectRead)
def create_canonical_project(payload: CanonicalProjectCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    payload = payload.model_copy(update={"slug": _normalize_slug(payload.slug)})
    return _create_entity(db, CanonicalProject, payload, current_user, conflict_detail="Cette identite projet existe deja")


@router.patch("/canonical-projects/{entity_id}", response_model=CanonicalProjectRead)
def update_canonical_project(entity_id: str, payload: CanonicalProjectUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    if payload.slug is not None:
        payload = payload.model_copy(update={"slug": _normalize_slug(payload.slug)})
    return _update_entity(db, _get_or_404(db, CanonicalProject, entity_id, "Projet canonique"), payload, CanonicalProjectCreate, current_user, conflict_detail="Cette identite projet existe deja")


@router.get("/project-aliases", response_model=list[ProjectAliasRead])
def list_project_aliases(
    project: str | None = None,
    year: int | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(ProjectAlias)
    if project:
        query = query.filter(ProjectAlias.canonical_project_id == project)
    if year is not None:
        query = query.filter(or_(ProjectAlias.start_year.is_(None), ProjectAlias.start_year <= year), or_(ProjectAlias.end_year.is_(None), ProjectAlias.end_year >= year))
    if validation_status:
        query = query.filter(ProjectAlias.validation_status == validation_status)
    return query.order_by(ProjectAlias.alias).all()


@router.post("/project-aliases", response_model=ProjectAliasRead)
def create_project_alias(payload: ProjectAliasCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    payload = payload.model_copy(update={"alias": payload.alias.strip()})
    return _create_entity(db, ProjectAlias, payload, current_user, conflict_detail="Cet alias projet existe deja")


@router.patch("/project-aliases/{entity_id}", response_model=ProjectAliasRead)
def update_project_alias(entity_id: str, payload: ProjectAliasUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    if payload.alias is not None:
        payload = payload.model_copy(update={"alias": payload.alias.strip()})
    return _update_entity(db, _get_or_404(db, ProjectAlias, entity_id, "Alias projet"), payload, ProjectAliasCreate, current_user, conflict_detail="Cet alias projet existe deja")


@router.get("/project-years", response_model=list[ProjectYearRead])
def list_project_years(
    year: int | None = None,
    project: str | None = None,
    territory: str | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(ProjectYear)
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
def create_project_year(payload: ProjectYearCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _create_entity(db, ProjectYear, payload, current_user, conflict_detail="Cette annee projet existe deja")


@router.patch("/project-years/{entity_id}", response_model=ProjectYearRead)
def update_project_year(entity_id: str, payload: ProjectYearUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _update_entity(db, _get_or_404(db, ProjectYear, entity_id, "Annee projet"), payload, ProjectYearCreate, current_user, conflict_detail="Cette annee projet existe deja")


@router.get("/project-relationships", response_model=list[ProjectRelationshipRead])
def list_project_relationships(
    project: str | None = None,
    year: int | None = None,
    relationship_type: str | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(ProjectRelationship)
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
def create_project_relationship(payload: ProjectRelationshipCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _create_entity(db, ProjectRelationship, payload, current_user, conflict_detail="Cette relation projet est invalide ou existe deja")


@router.patch("/project-relationships/{entity_id}", response_model=ProjectRelationshipRead)
def update_project_relationship(entity_id: str, payload: ProjectRelationshipUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
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
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = _visible_memory_query(db, InstitutionalEvent, current_user)
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
def create_event(payload: InstitutionalEventCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _create_entity(db, InstitutionalEvent, payload, current_user, conflict_detail="Cet evenement est invalide")


@router.patch("/events/{entity_id}", response_model=InstitutionalEventRead)
def update_event(entity_id: str, payload: InstitutionalEventUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _update_entity(db, _get_visible_or_404(db, InstitutionalEvent, entity_id, "Evenement institutionnel", current_user), payload, InstitutionalEventCreate, current_user, conflict_detail="Cet evenement est invalide")


@router.get("/frameworks", response_model=list[InstitutionalFrameworkRead])
def list_frameworks(
    year: int | None = None,
    framework_type: str | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(InstitutionalFramework)
    if year is not None:
        query = query.filter(InstitutionalFramework.effective_from_year <= year, or_(InstitutionalFramework.effective_to_year.is_(None), InstitutionalFramework.effective_to_year >= year))
    if framework_type:
        query = query.filter(InstitutionalFramework.framework_type == framework_type)
    if validation_status:
        query = query.filter(InstitutionalFramework.validation_status == validation_status)
    return query.order_by(InstitutionalFramework.effective_from_year.desc()).all()


@router.post("/frameworks", response_model=InstitutionalFrameworkRead)
def create_framework(payload: InstitutionalFrameworkCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _create_entity(db, InstitutionalFramework, payload, current_user, conflict_detail="Cette version de referentiel existe deja")


@router.patch("/frameworks/{entity_id}", response_model=InstitutionalFrameworkRead)
def update_framework(entity_id: str, payload: InstitutionalFrameworkUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _update_entity(db, _get_or_404(db, InstitutionalFramework, entity_id, "Referentiel institutionnel"), payload, InstitutionalFrameworkCreate, current_user, conflict_detail="Cette version de referentiel existe deja")


@router.get("/competitions", response_model=list[CompetitionRecordMemoryRead])
def list_competitions(
    year: int | None = None,
    territory: str | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(CompetitionRecord)
    if year is not None:
        query = query.filter(CompetitionRecord.year == year)
    if territory:
        query = query.filter(CompetitionRecord.territory_id == territory)
    if validation_status:
        query = query.filter(CompetitionRecord.validation_status == validation_status)
    return query.order_by(CompetitionRecord.year.desc().nullslast(), CompetitionRecord.name).all()


@router.post("/competitions", response_model=CompetitionRecordMemoryRead)
def create_competition(payload: CompetitionRecordMemoryCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    _ensure_file_reference(db, current_user, payload.file_id)
    return _create_entity(db, CompetitionRecord, payload, current_user, conflict_detail="Cette edition de competition existe deja")


@router.patch("/competitions/{entity_id}", response_model=CompetitionRecordMemoryRead)
def update_competition(entity_id: str, payload: CompetitionRecordMemoryUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    if "file_id" in payload.model_fields_set:
        _ensure_file_reference(db, current_user, payload.file_id)
    return _update_entity(db, _get_or_404(db, CompetitionRecord, entity_id, "Competition"), payload, CompetitionRecordMemoryCreate, current_user, conflict_detail="Cette edition de competition est invalide")


@router.get("/competition-participations", response_model=list[CompetitionParticipationRead])
def list_competition_participations(
    competition: str | None = None,
    project: str | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(CompetitionParticipation)
    if competition:
        query = query.filter(CompetitionParticipation.competition_record_id == competition)
    if project:
        query = query.filter(CompetitionParticipation.canonical_project_id == project)
    if validation_status:
        query = query.filter(CompetitionParticipation.validation_status == validation_status)
    return query.order_by(CompetitionParticipation.created_at).all()


@router.post("/competition-participations", response_model=CompetitionParticipationRead)
def create_competition_participation(payload: CompetitionParticipationCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _create_entity(db, CompetitionParticipation, payload, current_user, conflict_detail="Cette participation existe deja")


@router.patch("/competition-participations/{entity_id}", response_model=CompetitionParticipationRead)
def update_competition_participation(entity_id: str, payload: CompetitionParticipationUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    return _update_entity(db, _get_or_404(db, CompetitionParticipation, entity_id, "Participation"), payload, CompetitionParticipationCreate, current_user, conflict_detail="Cette participation est invalide ou existe deja")


@router.get("/awards", response_model=list[AwardMemoryRead])
def list_awards(
    year: int | None = None,
    project: str | None = None,
    validation_status: str | None = None,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(Award)
    if year is not None:
        query = query.filter(Award.year == year)
    if project:
        query = query.filter(Award.canonical_project_id == project)
    if validation_status:
        query = query.filter(Award.validation_status == validation_status)
    return query.order_by(Award.year.desc().nullslast(), Award.title).all()


@router.post("/awards", response_model=AwardMemoryRead)
def create_award(payload: AwardMemoryCreate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    _ensure_file_reference(db, current_user, payload.file_id)
    return _create_entity(db, Award, payload, current_user, conflict_detail="Cette distinction existe deja")


@router.patch("/awards/{entity_id}", response_model=AwardMemoryRead)
def update_award(entity_id: str, payload: AwardMemoryUpdate, db: Session = Depends(get_db), current_user=Depends(require_enacchef_or_admin)):
    if "file_id" in payload.model_fields_set:
        _ensure_file_reference(db, current_user, payload.file_id)
    return _update_entity(db, _get_or_404(db, Award, entity_id, "Distinction"), payload, AwardMemoryCreate, current_user, conflict_detail="Cette distinction est invalide")


@router.get("/{resource}/{entity_id}")
def get_memory_entity(
    resource: str,
    entity_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    model = RESOURCE_MODELS.get(resource)
    if model is None:
        raise _not_found("Ressource institutionnelle")
    return _get_visible_or_404(
        db, model, entity_id, "Fait institutionnel", current_user
    )


@router.post("/{resource}/{entity_id}/validate")
def validate_memory_entity(
    resource: str,
    entity_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_sg_or_admin),
):
    model = RESOURCE_MODELS.get(resource)
    if model is None:
        raise _not_found("Ressource institutionnelle")
    entity = _get_visible_or_404(
        db, model, entity_id, "Fait institutionnel", current_user
    )
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
    current_user=Depends(require_sg_or_admin),
):
    model = RESOURCE_MODELS.get(resource)
    if model is None:
        raise _not_found("Ressource institutionnelle")
    entity = _get_visible_or_404(
        db, model, entity_id, "Fait institutionnel", current_user
    )
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
