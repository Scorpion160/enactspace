from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
    require_enacchef_or_admin,
)
from app.core.roles import SECRETARIAT_ROLES
from app.db.database import get_db
from app.models.archive import (
    ArchiveItem,
    ArchivedProject,
    Award,
    CompetitionRecord,
    HistoricalDocument,
    HallOfFameEntry,
    HistoricalImpactStatistic,
    MediaArchive,
)
from app.models.stored_file import StoredFile
from app.schemas.archive import (
    ArchivedProjectCreate,
    ArchivedProjectRead,
    ArchivedProjectUpdate,
    ArchiveItemCreate,
    ArchiveItemRead,
    ArchiveItemUpdate,
    ArchiveValidationRequest,
    AwardCreate,
    AwardRead,
    AwardUpdate,
    CompetitionRecordCreate,
    CompetitionRecordRead,
    CompetitionRecordUpdate,
    HistoricalDocumentCreate,
    HistoricalDocumentRead,
    HistoricalDocumentUpdate,
    HallOfFameEntryCreate,
    HallOfFameEntryRead,
    HallOfFameEntryUpdate,
    HistoricalImpactStatisticCreate,
    HistoricalImpactStatisticRead,
    HistoricalImpactStatisticUpdate,
    MediaArchiveCreate,
    MediaArchiveRead,
    MediaArchiveUpdate,
)
from app.services.notification_service import notify_user


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
VALID_ARCHIVE_MEDIA_TYPES = {
    "image",
    "photo",
    "video",
    "lien_video",
    "article_presse",
    "rapport",
    "presentation",
    "document",
}
VALID_HISTORICAL_DOCUMENT_TYPES = {
    "Document officiel",
    "Rapport annuel",
    "Article presse",
    "Présentation",
    "Rapport compétition",
    "Photo",
    "Vidéo",
    "Autre",
}
VALID_HISTORICAL_STATUSES = {"draft", "submitted", "validated", "rejected", "hidden"}
VALID_ARCHIVE_STATUSES = {"draft", "submitted", "validated", "rejected", "archived", "hidden"}
VALID_ARCHIVE_VISIBILITIES = {"interne", "enacchefs", "alumni", "public", "privé"}
VALID_ARCHIVE_CATEGORIES = {
    "Projet historique",
    "Prix / distinction",
    "Compétition",
    "Rapport annuel",
    "Article presse",
    "Photo",
    "Vidéo",
    "Document officiel",
    "Témoignage",
    "Ancien membre / Alumni",
    "Événement",
    "Autre",
}


DEFAULT_HISTORICAL_IMPACT_SUMMARY = {
    "created_projects": 5,
    "developing_projects": 4,
    "developed_products": 14,
    "touched_sdgs": 11,
    "created_jobs": 227,
    "saved_lives": 206,
    "planted_trees": 1425,
    "cumulative_fcfa_gains": 27468761.10,
    "impacted_lives": 15900,
}

HISTORICAL_STAT_LABELS = {
    "created_projects": ("Projets créés", "projets"),
    "developing_projects": ("Projets en développement", "projets"),
    "developed_products": ("Produits développés", "produits"),
    "touched_sdgs": ("ODD touchés", "ODD"),
    "created_jobs": ("Emplois créés", "emplois"),
    "saved_lives": ("Vies sauvées", "vies"),
    "planted_trees": ("Arbres plantés", "arbres"),
    "cumulative_fcfa_gains": ("Gains cumulés", "FCFA"),
    "impacted_lives": ("Vies impactées", "vies"),
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

INITIAL_AWARDS = [
    {
        "id": "prix-excellence-sonatel",
        "archive_item_id": None,
        "title": "Premier Prix d’Excellence Fondation Sonatel",
        "year": None,
        "competition": "Fondation Sonatel",
        "rank": "Premier prix",
        "result": "Distinction",
        "description": "Prix historique obtenu par Enactus ESP.",
        "archived_project_id": None,
        "file_id": None,
        "media_url": None,
        "is_featured": True,
    },
    {
        "id": "deuxieme-national-2016",
        "archive_item_id": None,
        "title": "Deuxième National compétition nationale 2016",
        "year": 2016,
        "competition": "Compétition Nationale Enactus Sénégal",
        "rank": "Deuxième",
        "result": "Finaliste national",
        "description": "Performance nationale majeure de la saison 2016.",
        "archived_project_id": None,
        "file_id": None,
        "media_url": None,
        "is_featured": True,
    },
    {
        "id": "uhodari-2016",
        "archive_item_id": None,
        "title": "4 prix sur 5 UHODARI 2016",
        "year": 2016,
        "competition": "UHODARI",
        "rank": "4 prix sur 5",
        "result": "Distinction multiple",
        "description": "Série de distinctions obtenues lors de UHODARI 2016.",
        "archived_project_id": None,
        "file_id": None,
        "media_url": None,
        "is_featured": True,
    },
    {
        "id": "champion-national-2017",
        "archive_item_id": None,
        "title": "Champion National 2017",
        "year": 2017,
        "competition": "Compétition Nationale Enactus Sénégal",
        "rank": "Champion national",
        "result": "Qualification internationale",
        "description": "Titre national majeur dans l'histoire d'Enactus ESP.",
        "archived_project_id": None,
        "file_id": None,
        "media_url": None,
        "is_featured": True,
    },
    {
        "id": "champion-national-2018",
        "archive_item_id": None,
        "title": "Champion National 2018",
        "year": 2018,
        "competition": "Compétition Nationale Enactus Sénégal",
        "rank": "Champion national",
        "result": "Qualification World Cup",
        "description": "Deuxième titre national consécutif valorisant la solidité du club.",
        "archived_project_id": None,
        "file_id": None,
        "media_url": None,
        "is_featured": True,
    },
    {
        "id": "demi-finaliste-international-2018",
        "archive_item_id": None,
        "title": "Demi-finaliste compétition internationale 2018",
        "year": 2018,
        "competition": "Enactus World Cup",
        "rank": "Demi-finaliste",
        "result": "Performance internationale",
        "description": "Présence d'Enactus ESP parmi les demi-finalistes internationaux en 2018.",
        "archived_project_id": None,
        "file_id": None,
        "media_url": None,
        "is_featured": True,
    },
]

INITIAL_COMPETITIONS = [
    {
        "id": "competition-nationale-2016",
        "archive_item_id": None,
        "name": "Compétition Nationale Enactus Sénégal 2016",
        "year": 2016,
        "stage": "National",
        "result": "Deuxième national",
        "location": "Sénégal",
        "description": "Saison nationale marquée par une place de deuxième.",
        "project_ids": [],
        "award_ids": ["deuxieme-national-2016"],
        "file_id": None,
        "is_featured": True,
    },
    {
        "id": "uhodari-2016-record",
        "archive_item_id": None,
        "name": "UHODARI 2016",
        "year": 2016,
        "stage": "Distinctions",
        "result": "4 prix sur 5",
        "location": "Sénégal",
        "description": "Compétition marquée par quatre prix remportés sur cinq.",
        "project_ids": [],
        "award_ids": ["uhodari-2016"],
        "file_id": None,
        "is_featured": True,
    },
    {
        "id": "competition-nationale-2017",
        "archive_item_id": None,
        "name": "Compétition Nationale Enactus Sénégal 2017",
        "year": 2017,
        "stage": "National",
        "result": "Champion national",
        "location": "Sénégal",
        "description": "Titre national 2017.",
        "project_ids": [],
        "award_ids": ["champion-national-2017"],
        "file_id": None,
        "is_featured": True,
    },
    {
        "id": "competition-nationale-2018",
        "archive_item_id": None,
        "name": "Compétition Nationale Enactus Sénégal 2018",
        "year": 2018,
        "stage": "National",
        "result": "Champion national",
        "location": "Sénégal",
        "description": "Titre national 2018.",
        "project_ids": [],
        "award_ids": ["champion-national-2018"],
        "file_id": None,
        "is_featured": True,
    },
    {
        "id": "world-cup-2018",
        "archive_item_id": None,
        "name": "Enactus World Cup 2018",
        "year": 2018,
        "stage": "International",
        "result": "Demi-finaliste",
        "location": "International",
        "description": "Performance internationale majeure d'Enactus ESP.",
        "project_ids": [],
        "award_ids": ["demi-finaliste-international-2018"],
        "file_id": None,
        "is_featured": True,
    },
]

INITIAL_HALL_OF_FAME = [
    {
        "id": "creation-enactus-esp",
        "archive_item_id": None,
        "title": "Création d’Enactus ESP",
        "subtitle": "Naissance du club à l'École Supérieure Polytechnique de Dakar",
        "entry_type": "Histoire",
        "year": 2015,
        "description": "Point de départ de l'aventure Enactus ESP et de sa mémoire collective.",
        "score_value": None,
        "score_label": None,
        "file_id": None,
        "external_url": None,
        "order_index": 10,
        "is_featured": True,
    },
    {
        "id": "champion-national-2017-hall",
        "archive_item_id": None,
        "title": "Champion National 2017",
        "subtitle": "Titre national et qualification internationale",
        "entry_type": "Prix",
        "year": 2017,
        "description": "Titre majeur obtenu après la défense des projets Enactus ESP.",
        "score_value": None,
        "score_label": None,
        "file_id": None,
        "external_url": None,
        "order_index": 20,
        "is_featured": True,
    },
    {
        "id": "champion-national-2018-hall",
        "archive_item_id": None,
        "title": "Champion National 2018",
        "subtitle": "Deuxième titre national consécutif",
        "entry_type": "Prix",
        "year": 2018,
        "description": "Confirmation du niveau d'excellence et de la maturité des projets du club.",
        "score_value": None,
        "score_label": None,
        "file_id": None,
        "external_url": None,
        "order_index": 30,
        "is_featured": True,
    },
    {
        "id": "demi-finaliste-world-cup-2018-hall",
        "archive_item_id": None,
        "title": "Demi-finaliste compétition internationale 2018",
        "subtitle": "Rayonnement international",
        "entry_type": "International",
        "year": 2018,
        "description": "Performance internationale qui installe Enactus ESP parmi les références.",
        "score_value": None,
        "score_label": None,
        "file_id": None,
        "external_url": None,
        "order_index": 40,
        "is_featured": True,
    },
    {
        "id": "visibilite-media-hall",
        "archive_item_id": None,
        "title": "Parution presse, passage TV et intervention RFI",
        "subtitle": "Présences médiatiques",
        "entry_type": "Média",
        "year": None,
        "description": "Visibilité médiatique historique dans la presse, à la télévision et à la radio.",
        "score_value": None,
        "score_label": None,
        "file_id": None,
        "external_url": None,
        "order_index": 50,
        "is_featured": True,
    },
]


def _project_payload(project: ArchivedProject) -> dict:
    return ArchivedProjectRead.model_validate(project).model_dump()


def _award_payload(award: Award) -> dict:
    return AwardRead.model_validate(award).model_dump()


def _competition_payload(competition: CompetitionRecord) -> dict:
    return CompetitionRecordRead.model_validate(competition).model_dump()


def _file_payload(stored_file: StoredFile | None) -> dict | None:
    if stored_file is None:
        return None
    return {
        "id": stored_file.id,
        "name": stored_file.original_filename,
        "download_url": f"/api/files/{stored_file.id}/download",
        "preview_url": f"/api/files/{stored_file.id}/preview",
        "size_bytes": stored_file.file_size,
    }


def _media_payload(db: Session, media: MediaArchive) -> dict:
    data = MediaArchiveRead.model_validate(media).model_dump()
    stored_file = None
    if media.file_id:
        stored_file = db.query(StoredFile).filter(StoredFile.id == media.file_id).first()
    data["file"] = _file_payload(stored_file)
    return data


def _historical_document_payload(
    db: Session,
    document: HistoricalDocument,
) -> dict:
    data = HistoricalDocumentRead.model_validate(document).model_dump()
    stored_file = None
    if document.file_id:
        stored_file = db.query(StoredFile).filter(StoredFile.id == document.file_id).first()
    data["file"] = _file_payload(stored_file)
    return data


def _hall_of_fame_payload(db: Session, entry: HallOfFameEntry) -> dict:
    data = HallOfFameEntryRead.model_validate(entry).model_dump()
    stored_file = None
    if entry.file_id:
        stored_file = db.query(StoredFile).filter(StoredFile.id == entry.file_id).first()
    data["file"] = _file_payload(stored_file)
    return data


def _historical_statistic_payload(statistic: HistoricalImpactStatistic) -> dict:
    return HistoricalImpactStatisticRead.model_validate(statistic).model_dump()


def _archive_item_payload(item: ArchiveItem) -> dict:
    return ArchiveItemRead.model_validate(item).model_dump()


def _can_validate_archives(db: Session, user) -> bool:
    return bool(get_user_role_names(db, user.id).intersection(SECRETARIAT_ROLES))


def _can_view_archive_item(db: Session, user, item: ArchiveItem) -> bool:
    roles = get_user_role_names(db, user.id)
    if item.created_by_id == user.id:
        return True
    if roles.intersection(SECRETARIAT_ROLES):
        return True
    if item.status != "validated":
        return False
    if item.visibility == "public" and item.is_public:
        return True
    if item.visibility == "alumni":
        return user.status == "alumni" or "alumni" in roles
    if item.visibility == "enacchefs":
        return bool(roles.intersection(SECRETARIAT_ROLES))
    if item.visibility == "interne":
        return user.status in {"active", "alumni"}
    return False


def _archive_item_or_404(db: Session, archive_id: str) -> ArchiveItem:
    item = db.query(ArchiveItem).filter(ArchiveItem.id == archive_id).first()
    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Archive introuvable",
        )
    return item


def _ensure_archive_values(
    *,
    category: str | None = None,
    visibility: str | None = None,
    status_value: str | None = None,
) -> None:
    if category is not None and category not in VALID_ARCHIVE_CATEGORIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Catégorie d'archive invalide",
        )
    if visibility is not None and visibility not in VALID_ARCHIVE_VISIBILITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Visibilité d'archive invalide",
        )
    if status_value is not None and status_value not in VALID_ARCHIVE_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut d'archive invalide",
        )


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


def _create_archive_item_for_award(
    db: Session,
    payload: AwardCreate,
    user_id,
) -> ArchiveItem:
    archive_item = ArchiveItem(
        title=payload.title,
        description=payload.description,
        category="Prix / distinction",
        year=payload.year,
        file_id=payload.file_id,
        visibility="interne",
        status="draft",
        is_featured=payload.is_featured,
        created_by_id=user_id,
        tags=["prix", "distinction", payload.title.lower()],
        metadata_json={
            "competition": payload.competition,
            "rank": payload.rank,
            "result": payload.result,
        },
    )
    db.add(archive_item)
    db.flush()
    return archive_item


def _create_archive_item_for_competition(
    db: Session,
    payload: CompetitionRecordCreate,
    user_id,
) -> ArchiveItem:
    archive_item = ArchiveItem(
        title=payload.name,
        description=payload.description,
        category="Compétition",
        year=payload.year,
        file_id=payload.file_id,
        visibility="interne",
        status="draft",
        is_featured=payload.is_featured,
        created_by_id=user_id,
        tags=["competition", "archives", payload.name.lower()],
        metadata_json={
            "stage": payload.stage,
            "result": payload.result,
            "location": payload.location,
        },
    )
    db.add(archive_item)
    db.flush()
    return archive_item


def _create_archive_item_for_media(
    db: Session,
    payload: MediaArchiveCreate,
    user_id,
) -> ArchiveItem:
    archive_item = ArchiveItem(
        title=payload.title,
        description=payload.description,
        category="Photo" if payload.media_type in {"image", "photo"} else "Vidéo",
        year=payload.year,
        file_id=payload.file_id,
        visibility="interne",
        status="draft",
        is_featured=payload.is_featured,
        created_by_id=user_id,
        source_label=payload.source_label,
        source_url=payload.external_url,
        tags=["media", "archive", payload.media_type],
        metadata_json={"media_type": payload.media_type},
    )
    db.add(archive_item)
    db.flush()
    return archive_item


def _create_archive_item_for_historical_document(
    db: Session,
    payload: HistoricalDocumentCreate,
    user_id,
) -> ArchiveItem:
    archive_item = ArchiveItem(
        title=payload.title,
        description=payload.description,
        category=payload.document_type,
        year=payload.year,
        document_id=payload.document_id,
        file_id=payload.file_id,
        visibility=payload.visibility,
        status="draft",
        is_featured=payload.is_featured,
        created_by_id=user_id,
        source_label=payload.source_label,
        tags=["document", "historique", payload.document_type.lower()],
        metadata_json={"document_type": payload.document_type},
    )
    db.add(archive_item)
    db.flush()
    return archive_item


def _create_archive_item_for_hall_entry(
    db: Session,
    payload: HallOfFameEntryCreate,
    user_id,
) -> ArchiveItem:
    archive_item = ArchiveItem(
        title=payload.title,
        description=payload.description,
        category=payload.entry_type,
        year=payload.year,
        file_id=payload.file_id,
        visibility="interne",
        status="draft",
        is_featured=payload.is_featured,
        created_by_id=user_id,
        source_url=payload.external_url,
        tags=["hall_of_fame", payload.entry_type.lower(), payload.title.lower()],
        metadata_json={
            "subtitle": payload.subtitle,
            "score_label": payload.score_label,
        },
    )
    db.add(archive_item)
    db.flush()
    return archive_item


def _mark_file_as_archive(db: Session, file_id, visibility: str = "internal") -> None:
    if file_id is None:
        return
    stored_file = db.query(StoredFile).filter(StoredFile.id == file_id).first()
    if not stored_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier d'archive introuvable",
        )
    stored_file.storage_scope = "archive"
    stored_file.visibility = visibility
    stored_file.is_temporary = False
    stored_file.expires_at = None


@router.get("/items")
def list_archive_items(
    search: str | None = Query(default=None),
    category: str | None = Query(default=None),
    year: int | None = Query(default=None),
    visibility: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    featured: bool | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(ArchiveItem)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                ArchiveItem.title.ilike(pattern),
                ArchiveItem.description.ilike(pattern),
                ArchiveItem.category.ilike(pattern),
                ArchiveItem.source_label.ilike(pattern),
            )
        )
    if category:
        query = query.filter(ArchiveItem.category == category)
    if year is not None:
        query = query.filter(ArchiveItem.year == year)
    if visibility:
        query = query.filter(ArchiveItem.visibility == visibility)
    if status_filter:
        query = query.filter(ArchiveItem.status == status_filter)
    if featured is not None:
        query = query.filter(ArchiveItem.is_featured.is_(featured))
    items = query.order_by(
        ArchiveItem.is_featured.desc(),
        ArchiveItem.year.desc().nullslast(),
        ArchiveItem.updated_at.desc(),
    ).all()
    return {
        "items": [
            _archive_item_payload(item)
            for item in items
            if _can_view_archive_item(db, current_user, item)
        ]
    }


@router.post("/items", response_model=ArchiveItemRead)
def create_archive_item(
    payload: ArchiveItemCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    _ensure_archive_values(
        category=payload.category,
        visibility=payload.visibility,
        status_value=payload.status,
    )
    if payload.is_public and payload.visibility not in {"public", "alumni"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Une archive publique doit avoir une visibilité public ou alumni",
        )
    _mark_file_as_archive(db, payload.file_id)
    archive_item = ArchiveItem(
        **payload.model_dump(),
        created_by_id=current_user.id,
    )
    db.add(archive_item)
    db.commit()
    db.refresh(archive_item)
    return archive_item


@router.get("/items/{archive_id}")
def get_archive_item(
    archive_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    archive_item = _archive_item_or_404(db, archive_id)
    if not _can_view_archive_item(db, current_user, archive_item):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Archive non autorisée",
        )
    return _archive_item_payload(archive_item)


@router.patch("/items/{archive_id}", response_model=ArchiveItemRead)
def update_archive_item(
    archive_id: str,
    payload: ArchiveItemUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    archive_item = _archive_item_or_404(db, archive_id)
    data = payload.model_dump(exclude_unset=True)
    _ensure_archive_values(
        category=data.get("category"),
        visibility=data.get("visibility"),
        status_value=data.get("status"),
    )
    if data.get("is_public") is True:
        next_visibility = data.get("visibility", archive_item.visibility)
        if next_visibility not in {"public", "alumni"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Une archive publique doit avoir une visibilité public ou alumni",
            )
    if "file_id" in data:
        _mark_file_as_archive(db, data["file_id"])
    for field, value in data.items():
        setattr(archive_item, field, value)
    archive_item.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(archive_item)
    return archive_item


@router.post("/items/{archive_id}/submit", response_model=ArchiveItemRead)
def submit_archive_item(
    archive_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    archive_item = _archive_item_or_404(db, archive_id)
    archive_item.status = "submitted"
    archive_item.rejected_by_id = None
    archive_item.rejected_at = None
    archive_item.rejection_reason = None
    archive_item.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(archive_item)
    return archive_item


@router.post("/items/{archive_id}/validate", response_model=ArchiveItemRead)
def validate_archive_item(
    archive_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    if not _can_validate_archives(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Validation d'archive réservée au SG, Team Leader ou Admin",
        )
    archive_item = _archive_item_or_404(db, archive_id)
    archive_item.status = "validated"
    archive_item.validated_by_id = current_user.id
    archive_item.validated_at = datetime.utcnow()
    archive_item.rejected_by_id = None
    archive_item.rejected_at = None
    archive_item.rejection_reason = None
    archive_item.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(archive_item)
    if archive_item.created_by_id:
        notify_user(
            db,
            user_id=archive_item.created_by_id,
            title="Archive validée",
            message=f"L'archive « {archive_item.title} » est validée.",
            notification_type="archive_validated",
            related_type="archive",
            related_id=archive_item.id,
            dedupe=True,
        )
        db.commit()
    return archive_item


@router.post("/items/{archive_id}/reject", response_model=ArchiveItemRead)
def reject_archive_item(
    archive_id: str,
    payload: ArchiveValidationRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    if not _can_validate_archives(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Refus d'archive réservé au SG, Team Leader ou Admin",
        )
    if not payload.reason or not payload.reason.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le motif de refus est obligatoire",
        )
    archive_item = _archive_item_or_404(db, archive_id)
    archive_item.status = "rejected"
    archive_item.rejected_by_id = current_user.id
    archive_item.rejected_at = datetime.utcnow()
    archive_item.rejection_reason = payload.reason.strip()
    archive_item.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(archive_item)
    if archive_item.created_by_id:
        notify_user(
            db,
            user_id=archive_item.created_by_id,
            title="Archive refusée",
            message=f"L'archive « {archive_item.title} » a été refusée : {payload.reason.strip()}",
            notification_type="archive_rejected",
            related_type="archive",
            related_id=archive_item.id,
            dedupe=True,
        )
        db.commit()
    return archive_item


@router.post("/items/{archive_id}/archive", response_model=ArchiveItemRead)
def archive_archive_item(
    archive_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    if not _can_validate_archives(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Archivage réservé au SG, Team Leader ou Admin",
        )
    archive_item = _archive_item_or_404(db, archive_id)
    archive_item.status = "archived"
    archive_item.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(archive_item)
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


@router.get("/awards")
def list_awards(
    search: str | None = Query(default=None),
    year: int | None = Query(default=None),
    featured: bool | None = Query(default=None),
    include_static: bool = Query(default=True),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(Award)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                Award.title.ilike(pattern),
                Award.competition.ilike(pattern),
                Award.result.ilike(pattern),
                Award.description.ilike(pattern),
            )
        )
    if year is not None:
        query = query.filter(Award.year == year)
    if featured is not None:
        query = query.filter(Award.is_featured.is_(featured))

    db_awards = [
        _award_payload(award)
        for award in query.order_by(
            Award.year.desc().nullslast(),
            Award.is_featured.desc(),
            Award.title.asc(),
        ).all()
    ]
    static_awards = []
    if include_static:
        static_awards = [
            award
            for award in INITIAL_AWARDS
            if (year is None or award["year"] == year)
            and (featured is None or award["is_featured"] is featured)
            and (
                not search
                or search.lower()
                in " ".join(
                    str(award.get(field) or "")
                    for field in ("title", "competition", "result", "description")
                ).lower()
            )
        ]
    return {"awards": db_awards + static_awards}


@router.post("/awards", response_model=AwardRead)
def create_award(
    payload: AwardCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    archive_item_id = payload.archive_item_id
    if archive_item_id is None:
        archive_item_id = _create_archive_item_for_award(
            db,
            payload,
            current_user.id,
        ).id
    award = Award(
        **payload.model_dump(exclude={"archive_item_id"}),
        archive_item_id=archive_item_id,
    )
    db.add(award)
    db.commit()
    db.refresh(award)
    return award


@router.get("/awards/{award_id}")
def get_award(
    award_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    for award in INITIAL_AWARDS:
        if award["id"] == award_id:
            return award
    award = db.query(Award).filter(Award.id == award_id).first()
    if not award:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prix ou distinction introuvable",
        )
    return _award_payload(award)


@router.patch("/awards/{award_id}", response_model=AwardRead)
def update_award(
    award_id: str,
    payload: AwardUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    award = db.query(Award).filter(Award.id == award_id).first()
    if not award:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prix ou distinction introuvable",
        )
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(award, field, value)
    award.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(award)
    return award


@router.get("/competitions")
def list_competitions(
    search: str | None = Query(default=None),
    year: int | None = Query(default=None),
    featured: bool | None = Query(default=None),
    include_static: bool = Query(default=True),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(CompetitionRecord)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                CompetitionRecord.name.ilike(pattern),
                CompetitionRecord.stage.ilike(pattern),
                CompetitionRecord.result.ilike(pattern),
                CompetitionRecord.description.ilike(pattern),
            )
        )
    if year is not None:
        query = query.filter(CompetitionRecord.year == year)
    if featured is not None:
        query = query.filter(CompetitionRecord.is_featured.is_(featured))

    db_competitions = [
        _competition_payload(competition)
        for competition in query.order_by(
            CompetitionRecord.year.desc().nullslast(),
            CompetitionRecord.is_featured.desc(),
            CompetitionRecord.name.asc(),
        ).all()
    ]
    static_competitions = []
    if include_static:
        static_competitions = [
            competition
            for competition in INITIAL_COMPETITIONS
            if (year is None or competition["year"] == year)
            and (featured is None or competition["is_featured"] is featured)
            and (
                not search
                or search.lower()
                in " ".join(
                    str(competition.get(field) or "")
                    for field in ("name", "stage", "result", "description")
                ).lower()
            )
        ]
    return {"competitions": db_competitions + static_competitions}


@router.post("/competitions", response_model=CompetitionRecordRead)
def create_competition(
    payload: CompetitionRecordCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    archive_item_id = payload.archive_item_id
    if archive_item_id is None:
        archive_item_id = _create_archive_item_for_competition(
            db,
            payload,
            current_user.id,
        ).id
    competition = CompetitionRecord(
        **payload.model_dump(exclude={"archive_item_id"}),
        archive_item_id=archive_item_id,
    )
    db.add(competition)
    db.commit()
    db.refresh(competition)
    return competition


@router.get("/competitions/{competition_id}")
def get_competition(
    competition_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    for competition in INITIAL_COMPETITIONS:
        if competition["id"] == competition_id:
            return competition
    competition = (
        db.query(CompetitionRecord)
        .filter(CompetitionRecord.id == competition_id)
        .first()
    )
    if not competition:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Compétition introuvable",
        )
    return _competition_payload(competition)


@router.patch("/competitions/{competition_id}", response_model=CompetitionRecordRead)
def update_competition(
    competition_id: str,
    payload: CompetitionRecordUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    competition = (
        db.query(CompetitionRecord)
        .filter(CompetitionRecord.id == competition_id)
        .first()
    )
    if not competition:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Compétition introuvable",
        )
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(competition, field, value)
    competition.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(competition)
    return competition


@router.get("/media")
def list_archive_media(
    search: str | None = Query(default=None),
    year: int | None = Query(default=None),
    media_type: str | None = Query(default=None),
    project_id: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(MediaArchive)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                MediaArchive.title.ilike(pattern),
                MediaArchive.description.ilike(pattern),
                MediaArchive.source_label.ilike(pattern),
            )
        )
    if year is not None:
        query = query.filter(MediaArchive.year == year)
    if media_type:
        query = query.filter(MediaArchive.media_type == media_type)
    if project_id:
        query = query.filter(MediaArchive.archived_project_id == project_id)
    media = query.order_by(
        MediaArchive.year.desc().nullslast(),
        MediaArchive.is_featured.desc(),
        MediaArchive.created_at.desc(),
    ).all()
    return {"media": [_media_payload(db, item) for item in media]}


@router.post("/media")
def create_archive_media(
    payload: MediaArchiveCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    if payload.media_type not in VALID_ARCHIVE_MEDIA_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de média d'archive invalide",
        )
    _mark_file_as_archive(db, payload.file_id)
    archive_item_id = payload.archive_item_id
    if archive_item_id is None:
        archive_item_id = _create_archive_item_for_media(
            db,
            payload,
            current_user.id,
        ).id
    media = MediaArchive(
        **payload.model_dump(exclude={"archive_item_id"}),
        archive_item_id=archive_item_id,
    )
    db.add(media)
    db.commit()
    db.refresh(media)
    return _media_payload(db, media)


@router.patch("/media/{media_id}")
def update_archive_media(
    media_id: str,
    payload: MediaArchiveUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    media = db.query(MediaArchive).filter(MediaArchive.id == media_id).first()
    if not media:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Média d'archive introuvable",
        )
    data = payload.model_dump(exclude_unset=True)
    if "media_type" in data and data["media_type"] not in VALID_ARCHIVE_MEDIA_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de média d'archive invalide",
        )
    if "file_id" in data:
        _mark_file_as_archive(db, data["file_id"])
    for field, value in data.items():
        setattr(media, field, value)
    media.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(media)
    return _media_payload(db, media)


@router.get("/documents")
def list_historical_documents(
    search: str | None = Query(default=None),
    year: int | None = Query(default=None),
    document_type: str | None = Query(default=None),
    visibility: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(HistoricalDocument)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                HistoricalDocument.title.ilike(pattern),
                HistoricalDocument.description.ilike(pattern),
                HistoricalDocument.source_label.ilike(pattern),
            )
        )
    if year is not None:
        query = query.filter(HistoricalDocument.year == year)
    if document_type:
        query = query.filter(HistoricalDocument.document_type == document_type)
    if visibility:
        query = query.filter(HistoricalDocument.visibility == visibility)
    documents = query.order_by(
        HistoricalDocument.year.desc().nullslast(),
        HistoricalDocument.is_featured.desc(),
        HistoricalDocument.created_at.desc(),
    ).all()
    return {"documents": [_historical_document_payload(db, item) for item in documents]}


@router.post("/documents")
def create_historical_document(
    payload: HistoricalDocumentCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    if payload.document_type not in VALID_HISTORICAL_DOCUMENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de document historique invalide",
        )
    _mark_file_as_archive(db, payload.file_id)
    archive_item_id = payload.archive_item_id
    if archive_item_id is None:
        archive_item_id = _create_archive_item_for_historical_document(
            db,
            payload,
            current_user.id,
        ).id
    document = HistoricalDocument(
        **payload.model_dump(exclude={"archive_item_id"}),
        archive_item_id=archive_item_id,
    )
    db.add(document)
    db.commit()
    db.refresh(document)
    return _historical_document_payload(db, document)


@router.patch("/documents/{document_id}")
def update_historical_document(
    document_id: str,
    payload: HistoricalDocumentUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    document = (
        db.query(HistoricalDocument).filter(HistoricalDocument.id == document_id).first()
    )
    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document historique introuvable",
        )
    data = payload.model_dump(exclude_unset=True)
    if (
        "document_type" in data
        and data["document_type"] not in VALID_HISTORICAL_DOCUMENT_TYPES
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de document historique invalide",
        )
    if "file_id" in data:
        _mark_file_as_archive(db, data["file_id"])
    for field, value in data.items():
        setattr(document, field, value)
    document.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(document)
    return _historical_document_payload(db, document)


@router.get("/hall-of-fame")
def list_hall_of_fame(
    year: int | None = Query(default=None),
    entry_type: str | None = Query(default=None),
    featured: bool | None = Query(default=None),
    include_static: bool = Query(default=True),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    query = db.query(HallOfFameEntry)
    if year is not None:
        query = query.filter(HallOfFameEntry.year == year)
    if entry_type:
        query = query.filter(HallOfFameEntry.entry_type == entry_type)
    if featured is not None:
        query = query.filter(HallOfFameEntry.is_featured.is_(featured))
    entries = [
        _hall_of_fame_payload(db, entry)
        for entry in query.order_by(
            HallOfFameEntry.order_index.asc(),
            HallOfFameEntry.year.desc().nullslast(),
            HallOfFameEntry.created_at.desc(),
        ).all()
    ]
    static_entries = []
    if include_static:
        static_entries = [
            entry
            for entry in INITIAL_HALL_OF_FAME
            if (year is None or entry["year"] == year)
            and (entry_type is None or entry["entry_type"] == entry_type)
            and (featured is None or entry["is_featured"] is featured)
        ]
    return {"items": entries + static_entries}


@router.post("/hall-of-fame")
def create_hall_of_fame_entry(
    payload: HallOfFameEntryCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    _mark_file_as_archive(db, payload.file_id)
    archive_item_id = payload.archive_item_id
    if archive_item_id is None:
        archive_item_id = _create_archive_item_for_hall_entry(
            db,
            payload,
            current_user.id,
        ).id
    entry = HallOfFameEntry(
        **payload.model_dump(exclude={"archive_item_id"}),
        archive_item_id=archive_item_id,
    )
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return _hall_of_fame_payload(db, entry)


@router.patch("/hall-of-fame/{entry_id}")
def update_hall_of_fame_entry(
    entry_id: str,
    payload: HallOfFameEntryUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    entry = db.query(HallOfFameEntry).filter(HallOfFameEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrée Hall of Fame introuvable",
        )
    data = payload.model_dump(exclude_unset=True)
    if "file_id" in data:
        _mark_file_as_archive(db, data["file_id"])
    for field, value in data.items():
        setattr(entry, field, value)
    entry.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(entry)
    return _hall_of_fame_payload(db, entry)


@router.get("/historical-impact/summary")
def get_historical_impact_summary(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    summary = dict(DEFAULT_HISTORICAL_IMPACT_SUMMARY)
    statistics = (
        db.query(HistoricalImpactStatistic)
        .filter(HistoricalImpactStatistic.status == "validated")
        .all()
    )
    for statistic in statistics:
        summary[statistic.metric_key] = float(statistic.value or 0)
    summary["statistics"] = [
        _historical_statistic_payload(statistic) for statistic in statistics
    ]
    return summary


@router.get("/historical-impact/statistics")
def list_historical_impact_statistics(
    include_defaults: bool = Query(default=True),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    db_statistics = {
        statistic.metric_key: _historical_statistic_payload(statistic)
        for statistic in db.query(HistoricalImpactStatistic)
        .order_by(
            HistoricalImpactStatistic.is_featured.desc(),
            HistoricalImpactStatistic.metric_key.asc(),
        )
        .all()
    }
    if include_defaults:
        for key, value in DEFAULT_HISTORICAL_IMPACT_SUMMARY.items():
            if key in db_statistics:
                continue
            label, unit = HISTORICAL_STAT_LABELS.get(key, (key, None))
            db_statistics[key] = {
                "id": key,
                "metric_key": key,
                "label": label,
                "value": value,
                "unit": unit,
                "description": "Chiffre historique à confirmer avec les sources disponibles.",
                "source_label": "Présentation Enactus ESP",
                "source_file_id": None,
                "status": "validated",
                "is_featured": True,
                "updated_by_id": None,
                "validated_by_id": None,
                "validated_at": None,
                "created_at": None,
                "updated_at": None,
            }
    return {"statistics": list(db_statistics.values())}


@router.post("/historical-impact/statistics")
def create_historical_impact_statistic(
    payload: HistoricalImpactStatisticCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    if payload.status not in VALID_HISTORICAL_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de statistique historique invalide",
        )
    existing = (
        db.query(HistoricalImpactStatistic)
        .filter(HistoricalImpactStatistic.metric_key == payload.metric_key)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cette statistique historique existe déjà",
        )
    _mark_file_as_archive(db, payload.source_file_id)
    statistic = HistoricalImpactStatistic(
        **payload.model_dump(),
        updated_by_id=current_user.id,
    )
    if payload.status == "validated":
        statistic.validated_by_id = current_user.id
        statistic.validated_at = datetime.utcnow()
    db.add(statistic)
    db.commit()
    db.refresh(statistic)
    return _historical_statistic_payload(statistic)


@router.patch("/historical-impact/statistics/{statistic_id}")
def update_historical_impact_statistic(
    statistic_id: str,
    payload: HistoricalImpactStatisticUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_enacchef_or_admin),
):
    statistic = (
        db.query(HistoricalImpactStatistic)
        .filter(HistoricalImpactStatistic.id == statistic_id)
        .first()
    )
    if not statistic:
        statistic = (
            db.query(HistoricalImpactStatistic)
            .filter(HistoricalImpactStatistic.metric_key == statistic_id)
            .first()
        )
    if not statistic:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Statistique historique introuvable",
        )
    data = payload.model_dump(exclude_unset=True)
    if "status" in data and data["status"] not in VALID_HISTORICAL_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de statistique historique invalide",
        )
    if "source_file_id" in data:
        _mark_file_as_archive(db, data["source_file_id"])
    for field, value in data.items():
        setattr(statistic, field, value)
    statistic.updated_by_id = current_user.id
    if data.get("status") == "validated":
        statistic.validated_by_id = current_user.id
        statistic.validated_at = datetime.utcnow()
    statistic.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(statistic)
    return _historical_statistic_payload(statistic)
