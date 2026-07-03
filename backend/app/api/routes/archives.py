from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    require_enacchef_or_admin,
)
from app.db.database import get_db
from app.models.archive import ArchiveItem, ArchivedProject
from app.schemas.archive import (
    ArchivedProjectCreate,
    ArchivedProjectRead,
    ArchivedProjectUpdate,
)


router = APIRouter(prefix="/archives", tags=["Archives"])


VALID_ARCHIVED_PROJECT_STATUSES = {
    "historique",
    "archive",
    "archivé",
    "continue",
    "continué",
    "developpement",
    "développement",
}


INITIAL_HISTORICAL_PROJECTS = [
    {
        "id": "sukhalii-gokh",
        "archive_item_id": None,
        "name": "SUKHALII GOKH",
        "year": None,
        "season_label": None,
        "description": "Projet historique Enactus ESP à documenter.",
        "problem": None,
        "solution": None,
        "impact_summary": "Mémoire projet à compléter avec les preuves disponibles.",
        "status": "historique",
        "linked_project_id": None,
        "key_members": [],
        "awards": [],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "kong-serve",
        "archive_item_id": None,
        "name": "KONG’SERVE",
        "year": None,
        "season_label": None,
        "description": "Projet historique Enactus ESP à documenter.",
        "problem": None,
        "solution": None,
        "impact_summary": "Mémoire projet à compléter avec les preuves disponibles.",
        "status": "historique",
        "linked_project_id": None,
        "key_members": [],
        "awards": [],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "javelisel",
        "archive_item_id": None,
        "name": "JAVELISEL",
        "year": 2015,
        "season_label": "2015 - 2019",
        "description": "Projet de santé publique autour de l'eau de javel et de la prévention des maladies.",
        "problem": "Prévention insuffisante de maladies liées à l'hygiène.",
        "solution": "Production et diffusion de solutions de désinfection accessibles avec sensibilisation.",
        "impact_summary": "Projet emblématique lié à l'hygiène communautaire.",
        "status": "archivé",
        "linked_project_id": None,
        "key_members": ["Équipe Javelisel"],
        "awards": ["Premier Prix d’Excellence Fondation Sonatel"],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "deconaane",
        "archive_item_id": None,
        "name": "DECONAANE",
        "year": 2016,
        "season_label": "2016 - 2020",
        "description": "Projet lié à l'eau sûre, au moringa, à la prévention sanitaire et aux revenus.",
        "problem": "Accès insuffisant à une eau sûre et prévention sanitaire limitée.",
        "solution": "Approche communautaire combinant traitement, sensibilisation et valorisation du moringa.",
        "impact_summary": "Projet de santé communautaire et d'activité génératrice de revenus.",
        "status": "continué",
        "linked_project_id": None,
        "key_members": ["Équipe projet Deconaane"],
        "awards": ["4 prix sur 5 UHODARI 2016"],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "dimbali",
        "archive_item_id": None,
        "name": "DIMBALI",
        "year": 2016,
        "season_label": "2016 - 2020",
        "description": "Projet lancé à Ngayène Sabakh pour combattre la malnutrition et renforcer les revenus.",
        "problem": "Malnutrition, faibles revenus et pertes post-récolte.",
        "solution": "Farine infantile fortifiée, séchage solaire et structuration du GIE FAVEC.",
        "impact_summary": "Projet emblématique de nutrition, entrepreneuriat féminin et développement local.",
        "status": "archivé",
        "linked_project_id": None,
        "key_members": ["Équipe projet Dimbali", "Alumni Enactus ESP"],
        "awards": ["Champion National 2017", "Champion National 2018"],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "meune-nagn",
        "archive_item_id": None,
        "name": "MEUNE NAGN",
        "year": None,
        "season_label": None,
        "description": "Projet historique Enactus ESP à documenter.",
        "problem": None,
        "solution": None,
        "impact_summary": "Mémoire projet à compléter avec les preuves disponibles.",
        "status": "historique",
        "linked_project_id": None,
        "key_members": [],
        "awards": [],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "soukhali",
        "archive_item_id": None,
        "name": "SOUKHALI",
        "year": None,
        "season_label": None,
        "description": "Projet historique Enactus ESP à documenter.",
        "problem": None,
        "solution": None,
        "impact_summary": "Mémoire projet à compléter avec les preuves disponibles.",
        "status": "historique",
        "linked_project_id": None,
        "key_members": [],
        "awards": [],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "mobigel",
        "archive_item_id": None,
        "name": "MOBIGEL",
        "year": 2020,
        "season_label": "2020 - 2021",
        "description": "Innovation rapide née en contexte Covid-19 autour de l'hygiène mobile.",
        "problem": "Besoin urgent de solutions d'hygiène accessibles et mobiles pendant la crise sanitaire.",
        "solution": "Dispositif mobile facilitant l'accès au gel et à l'hygiène préventive.",
        "impact_summary": "Projet agile de prévention sanitaire sur le campus et dans les espaces publics.",
        "status": "archivé",
        "linked_project_id": None,
        "key_members": ["Équipe Mobigel"],
        "awards": ["Parution presse", "Passage TV"],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "expansion-dimbali",
        "archive_item_id": None,
        "name": "EXPANSION DIMBALI",
        "year": None,
        "season_label": None,
        "description": "Extension historique du projet Dimbali.",
        "problem": "Besoin de consolider l'impact nutritionnel et économique.",
        "solution": "Réplication et renforcement du modèle Dimbali.",
        "impact_summary": "Extension à documenter avec les données terrain disponibles.",
        "status": "historique",
        "linked_project_id": None,
        "key_members": [],
        "awards": [],
        "document_ids": [],
        "media_file_ids": [],
    },
    {
        "id": "expansion-deconaane",
        "archive_item_id": None,
        "name": "EXPANSION DECONAANE",
        "year": None,
        "season_label": None,
        "description": "Extension historique du projet Deconaane.",
        "problem": "Besoin d'élargir la prévention sanitaire et la valorisation locale.",
        "solution": "Réplication et renforcement du modèle Deconaane.",
        "impact_summary": "Extension à documenter avec les données terrain disponibles.",
        "status": "historique",
        "linked_project_id": None,
        "key_members": [],
        "awards": [],
        "document_ids": [],
        "media_file_ids": [],
    },
]


def _project_payload(project: ArchivedProject) -> dict:
    return ArchivedProjectRead.model_validate(project).model_dump()


def _matches_static_project(
    project: dict,
    *,
    search: str | None,
    year: int | None,
    status_filter: str | None,
) -> bool:
    if year is not None and project.get("year") != year:
        return False
    if status_filter and project.get("status") != status_filter:
        return False
    if search:
        needle = search.lower()
        haystack = " ".join(
            str(project.get(field) or "")
            for field in ("name", "description", "problem", "solution", "impact_summary")
        ).lower()
        return needle in haystack
    return True


def _get_archived_project_or_404(db: Session, project_id: str) -> ArchivedProject:
    project = db.query(ArchivedProject).filter(ArchivedProject.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Projet historique introuvable",
        )
    return project


def _create_archive_item_for_project(
    db: Session,
    payload: ArchivedProjectCreate,
    user_id,
) -> ArchiveItem:
    archive_item = ArchiveItem(
        title=payload.name,
        description=payload.description or payload.impact_summary,
        category="Projet historique",
        year=payload.year,
        project_id=payload.linked_project_id,
        visibility="interne",
        status="draft",
        is_featured=False,
        is_public=False,
        created_by_id=user_id,
        tags=["projet", "historique", payload.name.lower()],
        metadata_json={
            "season_label": payload.season_label,
            "status": payload.status,
        },
    )
    db.add(archive_item)
    db.flush()
    return archive_item


@router.get("/historical-projects")
def list_historical_projects(
    search: str | None = Query(default=None),
    year: int | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    include_static: bool = Query(default=True),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(ArchivedProject)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                ArchivedProject.name.ilike(pattern),
                ArchivedProject.description.ilike(pattern),
                ArchivedProject.problem.ilike(pattern),
                ArchivedProject.solution.ilike(pattern),
                ArchivedProject.impact_summary.ilike(pattern),
            )
        )
    if year is not None:
        query = query.filter(ArchivedProject.year == year)
    if status_filter:
        query = query.filter(ArchivedProject.status == status_filter)

    db_projects = [
        _project_payload(project)
        for project in query.order_by(
            ArchivedProject.year.desc().nullslast(),
            ArchivedProject.name.asc(),
        ).all()
    ]
    static_projects = []
    if include_static:
        static_projects = [
            project
            for project in INITIAL_HISTORICAL_PROJECTS
            if _matches_static_project(
                project,
                search=search,
                year=year,
                status_filter=status_filter,
            )
        ]
    return {"projects": db_projects + static_projects}


@router.post("/historical-projects", response_model=ArchivedProjectRead)
def create_historical_project(
    payload: ArchivedProjectCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    if payload.status not in VALID_ARCHIVED_PROJECT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de projet historique invalide",
        )
    archive_item_id = payload.archive_item_id
    if archive_item_id is None:
        archive_item_id = _create_archive_item_for_project(
            db,
            payload,
            current_user.id,
        ).id
    project = ArchivedProject(
        **payload.model_dump(exclude={"archive_item_id"}),
        archive_item_id=archive_item_id,
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


@router.get("/historical-projects/{project_id}")
def get_historical_project(
    project_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    for project in INITIAL_HISTORICAL_PROJECTS:
        if project["id"] == project_id:
            return project
    return _project_payload(_get_archived_project_or_404(db, project_id))


@router.patch("/historical-projects/{project_id}", response_model=ArchivedProjectRead)
def update_historical_project(
    project_id: str,
    payload: ArchivedProjectUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    project = _get_archived_project_or_404(db, project_id)
    data = payload.model_dump(exclude_unset=True)
    if "status" in data and data["status"] not in VALID_ARCHIVED_PROJECT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de projet historique invalide",
        )
    for field, value in data.items():
        setattr(project, field, value)
    project.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(project)
    return project
