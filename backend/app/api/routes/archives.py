from app.core.time import utc_now
import csv
from datetime import datetime
from io import StringIO
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import Response
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
    require_memory_curator,
)
from app.api.routes.files import ensure_file_access
from app.core.roles import MEMORY_CURATOR_ROLES, SECRETARIAT_ROLES
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
from app.models.institutional_memory import InstitutionalSource
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
from app.services.audit_service import create_audit_log


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


INSTITUTIONAL_MEMORY_SOURCE_LABEL = "Mémoire institutionnelle Enactus ESP 2015–2026"

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
        "description": "Performance nationale majeure de l’année 2016.",
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
        "description": "Année nationale marquée par une place de deuxième.",
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


# Enactus ESP approved institutional-memory enrichment (2015-2026).
# The source was supplied and explicitly validated by Enactus ESP.
_APPROVED_PROJECT_DETAILS = {
    "sukhalii-gokh": {
        "name": "SOUKHALI GOKH",
        "year": 2015,
        "season_label": "2015 - 2020",
        "description": "Transformation de céréales locales avec les femmes de Darou Thioub, à Keur Massar.",
        "problem": "Malnutrition infantile et faibles revenus des femmes de la communauté.",
        "solution": "Coopérative de transformation, farine fortifiée et formations en production, packaging, vente et gestion.",
        "impact_summary": "Amélioration nutritionnelle, renforcement des capacités, extension du marché et hausse des revenus.",
    },
    "kong-serve": {
        "name": "KONG’SERVE",
        "year": 2019,
        "description": "Projet développé sur la Petite Côte pour améliorer la conservation du Kong fumé.",
        "problem": "Pertes post-récolte et conservation insuffisante des produits halieutiques.",
        "solution": "Formation des producteurs de Yoff Tonghor et Mballing à une technique améliorée de conservation du Kong fumé.",
        "impact_summary": "Augmentation de la production et des revenus des exploitants, avec croissance des exportations.",
    },
    "javelisel": {
        "year": 2015,
        "description": "Production d'eau de javel à base d'eau et de sel et sensibilisation sanitaire à Pikine et au marché Tilène.",
        "impact_summary": "1 720 bouteilles distribuées dans des zones insalubres, avec amélioration de l'accès à la désinfection.",
    },
    "deconaane": {
        "description": "Accès à l'eau potable à Sébikotane, puis extension à Sinthiou Dimb.",
        "solution": "Filtre à base d'argile et d'éléments naturels, poudre de Moringa, pompe et dispositifs de stockage potou ndaa.",
        "impact_summary": "5 emplois créés, 125 arbres de Moringa plantés, +52 % de revenus mensuels et 515 670 FCFA de chiffre d'affaires sur un mois.",
    },
    "dimbali": {
        "year": 2017,
        "season_label": "Depuis 2017",
        "description": "Projet de lutte contre la malnutrition à Ngayène Sabakh puis Ndiédieng, fondé sur la valorisation du Dimb.",
        "problem": "Malnutrition des enfants de moins de cinq ans, faibles revenus et pertes liées à la saisonnalité du Dimb.",
        "solution": "Transformation agroalimentaire, compostage, séchoirs solaires et formations des bénéficiaires.",
        "impact_summary": "Malnutrition ramenée de 15 % à 0 %, plus de 43 M FCFA d'impact économique, +77 % de revenus, 112 emplois et 1 400 femmes formées.",
    },
    "meune-nagn": {
        "name": "MËN NAÑ",
        "year": 2019,
        "season_label": "Depuis 2019",
        "description": "Valorisation des ressources naturelles du Sud du Sénégal dans les zones de Niaguiss, Saré Yoba Diéga et Sinthiou Dimb.",
        "problem": "Pertes agricoles, faibles revenus, inégalités de genre et difficultés d'accès à l'eau et à la transformation.",
        "solution": "Transformation, formation, séchoirs solaires, technologies d'accès à l'eau et structuration de GIE.",
        "impact_summary": "97 emplois dont 49 femmes entrepreneures, plus de 25 produits dans le panier des GIE, 4 218 375 FCFA de chiffre d'affaires cumulé, plus d'une tonne de fruits et 1 351 litres de lait transformés.",
    },
    "mobigel": {
        "year": 2020,
        "description": "Vélo distributeur de gel antiseptique sans contact et outil mobile de sensibilisation pendant la Covid-19.",
        "impact_summary": "Prototype testé aux Maristes, associant distribution sans contact, comptage des utilisateurs et messages de prévention alimentés par mini panneau solaire.",
    },
    "expansion-dimbali": {
        "year": 2019,
        "season_label": "2019",
        "description": "Mission à Sinthiou Dimb ayant conduit à adapter les technologies d'accès à l'eau au contexte local.",
        "problem": "Le principal besoin identifié à Sinthiou Dimb était l'accès à l'eau plutôt que la culture du dimb.",
        "solution": "Adaptation des technologies de Deconaane : pompe, amélioration de l'accès à l'eau et séchoirs pour la conservation des mangues.",
        "impact_summary": "Extension du savoir-faire technique d'Enactus ESP à Sinthiou Dimb pour l'eau et la conservation alimentaire.",
    },
    "expansion-deconaane": {
        "name": "DECONAANE+",
        "year": 2019,
        "season_label": "2019",
        "description": "Extension de Deconaane à Sinthiou Dimb lors de la mission d'extension de Dimbali.",
        "problem": "Accès à l'eau insuffisant dans la localité.",
        "solution": "Installation d'une pompe et adaptation des solutions de stockage et de conservation.",
        "impact_summary": "Amélioration de l'accès à l'eau et transfert des technologies développées dans Deconaane.",
    },
}

for _project in INITIAL_HISTORICAL_PROJECTS:
    _details = _APPROVED_PROJECT_DETAILS.get(_project["id"])
    if _details:
        _project.update(_details)

# Remove the duplicate legacy Soukhali alias now that the canonical historical
# entry is explicitly documented as SOUKHALI GOKH.
INITIAL_HISTORICAL_PROJECTS = [
    _project for _project in INITIAL_HISTORICAL_PROJECTS if _project["id"] != "soukhali"
]

INITIAL_HISTORICAL_PROJECTS.extend([
    {
        "id": "suncuiz", "archive_item_id": None, "name": "SUNCUIZ", "year": 2017,
        "season_label": "Projet fondateur", "description": "Cuiseur solaire destiné aux femmes rurales, expérimenté à Sambé Nguinth dans le Diourbel puis décliné en paniers thermiques.",
        "problem": "Déforestation et risques sanitaires liés à la cuisson au bois.", "solution": "Cuisson solaire puis paniers thermiques.",
        "impact_summary": "Solution énergétique simple destinée à réduire la dépendance au bois de cuisson.", "status": "archivé",
        "linked_project_id": None, "key_members": [], "awards": [], "document_ids": [], "media_file_ids": [],
    },
    {
        "id": "ville-light", "archive_item_id": None, "name": "VILLE LIGHT", "year": 2017,
        "season_label": "Projet fondateur", "description": "Système d'éclairage à faible coût inspiré des bouteilles solaires, ensuite transformé en kits pédagogiques.",
        "problem": "Accès limité à un éclairage abordable.", "solution": "Éclairage simple à faible coût et kits de sensibilisation.",
        "impact_summary": "Sensibilisation aux technologies simples d'éclairage.", "status": "archivé",
        "linked_project_id": None, "key_members": [], "awards": [], "document_ids": [], "media_file_ids": [],
    },
    {
        "id": "diappeu-thi", "archive_item_id": None, "name": "DIAPPEU THI", "year": 2020,
        "season_label": "2020", "description": "Projet de riposte à la Covid-19 piloté notamment par Balla Hann et Clara.",
        "problem": "Besoin de prévention et de protection communautaire pendant la pandémie.", "solution": "Sensibilisation, distribution de masques et de gel, et actions communautaires.",
        "impact_summary": "Initiative communautaire de lutte contre la Covid-19.", "status": "archivé",
        "linked_project_id": None, "key_members": ["Balla Hann", "Clara"], "awards": [], "document_ids": [], "media_file_ids": [],
    },
    {
        "id": "cajor", "archive_item_id": None, "name": "CAJOR", "year": 2022,
        "season_label": "2022 - 2023", "description": "Projet lancé durant le cycle 2022–2023 et porté par le pôle Chimie.",
        "problem": None, "solution": None,
        "impact_summary": "Projet de la nouvelle génération lancée aux côtés de SHERY, Terrasen et Aquatus.", "status": "historique",
        "linked_project_id": None, "key_members": ["Pôle Chimie"], "awards": [], "document_ids": [], "media_file_ids": [],
    },
    {
        "id": "shery", "archive_item_id": None, "name": "SHERY", "year": 2021,
        "season_label": "Depuis 2021", "description": "Serviettes hygiéniques réutilisables contre la précarité menstruelle, avec tisanes naturelles et plateforme de sensibilisation.",
        "problem": "Précarité menstruelle, coût des protections jetables et manque d'information.", "solution": "Serviettes réutilisables lavables, tisanes et plateforme numérique.",
        "impact_summary": "Projet contribuant à 7 ODD, lauréat du premier prix du Salon du Polytechnicien 2023.", "status": "développement",
        "linked_project_id": None, "key_members": [], "awards": ["Premier prix Salon du Polytechnicien 2023"], "document_ids": [], "media_file_ids": [],
    },
    {
        "id": "terrasen", "archive_item_id": None, "name": "TERRASEN", "year": 2022,
        "season_label": "Depuis 2022", "description": "Micro-jardinage, transformation agroalimentaire et irrigation automatisée à base d'ESP32.",
        "problem": "Insécurité alimentaire, précarité économique et gestion de l'eau.", "solution": "Micro-jardinage sur table, goutte-à-goutte, arrosage automatisé et transformation.",
        "impact_summary": "Plus de 50 emplois directs, plus de 17 800 personnes directement impactées, 12,5 tonnes transformées et 55 600 USD de profit annuel total.", "status": "développement",
        "linked_project_id": None, "key_members": [], "awards": ["1er prix Polytech'Innovation 2025", "2e prix SENAYSKILLS 2025"], "document_ids": [], "media_file_ids": [],
    },
    {
        "id": "aquatus", "archive_item_id": None, "name": "AQUATUS", "year": 2023,
        "season_label": "Depuis 2023", "description": "Projet d'aquaponie ciblant Ngayène Sabakh, combinant aquaculture et hydroponie.",
        "problem": "Besoin d'une production alimentaire durable économe en eau, en sol et en espace.", "solution": "Système aquaponique intégrant élevage de poissons et culture hors-sol.",
        "impact_summary": "Projet audité à Ngayène Sabakh et lauréat du deuxième prix Polytech'Innovation 2025.", "status": "développement",
        "linked_project_id": None, "key_members": [], "awards": ["2e prix Polytech'Innovation 2025"], "document_ids": [], "media_file_ids": [],
    },
])

# Validated institutional distinctions not present in the older compatibility set.
INITIAL_AWARDS.extend([
    {"id": "champion-national-2023", "archive_item_id": None, "title": "Champion National 2023", "year": 2023, "competition": "Enactus National Competition", "rank": "Champion national", "result": "Champion national", "description": "Troisième titre national d'Enactus ESP.", "archived_project_id": None, "file_id": None, "media_url": None, "is_featured": True},
    {"id": "shery-salon-polytechnicien-2023", "archive_item_id": None, "title": "Premier prix Salon du Polytechnicien 2023 — SHERY", "year": 2023, "competition": "Salon du Polytechnicien", "rank": "Premier prix", "result": "Lauréat", "description": "Premier prix obtenu par le projet SHERY.", "archived_project_id": None, "file_id": None, "media_url": None, "is_featured": True},
    {"id": "terrasen-polytech-innovation-2025", "archive_item_id": None, "title": "Premier prix Polytech'Innovation 2025 — Terrasen", "year": 2025, "competition": "Polytech'Innovation", "rank": "Premier prix", "result": "Lauréat", "description": "Premier prix obtenu par le projet Terrasen.", "archived_project_id": None, "file_id": None, "media_url": None, "is_featured": True},
    {"id": "aquatus-polytech-innovation-2025", "archive_item_id": None, "title": "Deuxième prix Polytech'Innovation 2025 — Aquatus", "year": 2025, "competition": "Polytech'Innovation", "rank": "Deuxième prix", "result": "Deuxième prix", "description": "Deuxième prix obtenu par le projet Aquatus.", "archived_project_id": None, "file_id": None, "media_url": None, "is_featured": True},
    {"id": "terrasen-senayskills-2025", "archive_item_id": None, "title": "Deuxième prix SENAYSKILLS 2025 — Terrasen", "year": 2025, "competition": "SENAYSKILLS", "rank": "Deuxième prix", "result": "Deuxième prix", "description": "Deuxième prix obtenu par le projet Terrasen.", "archived_project_id": None, "file_id": None, "media_url": None, "is_featured": True},
])

INITIAL_COMPETITIONS.extend([
    {"id": "world-cup-2022", "archive_item_id": None, "name": "Enactus World Cup 2022", "year": 2022, "stage": "International", "result": "Participation", "location": "International", "description": "Retour d'Enactus ESP à la World Cup avec Dimbali et Mën Nañ après qualification sur dossier.", "project_ids": ["dimbali", "meune-nagn"], "award_ids": [], "file_id": None, "is_featured": True},
    {"id": "competition-nationale-2023", "archive_item_id": None, "name": "Enactus National Competition 2023", "year": 2023, "stage": "National", "result": "Champion national", "location": "Sénégal", "description": "Troisième titre de champion national d'Enactus ESP.", "project_ids": [], "award_ids": ["champion-national-2023"], "file_id": None, "is_featured": True},
])

INITIAL_HALL_OF_FAME.extend([
    {"id": "world-cup-2022-hall", "archive_item_id": None, "title": "Retour à Enactus World Cup", "subtitle": "Dimbali et Mën Nañ représentent Enactus ESP", "entry_type": "International", "year": 2022, "description": "Qualification sur dossier et retour sur la scène mondiale.", "score_value": None, "score_label": None, "file_id": None, "external_url": None, "order_index": 50, "is_featured": True},
    {"id": "champion-national-2023-hall", "archive_item_id": None, "title": "Champion National 2023", "subtitle": "Troisième titre national", "entry_type": "Prix", "year": 2023, "description": "Enactus ESP devient triple champion national après les titres de 2017 et 2018.", "score_value": None, "score_label": None, "file_id": None, "external_url": None, "order_index": 60, "is_featured": True},
    {"id": "innovations-2025-hall", "archive_item_id": None, "title": "Terrasen et Aquatus primés en 2025", "subtitle": "Polytech'Innovation et SENAYSKILLS", "entry_type": "Prix", "year": 2025, "description": "Terrasen remporte le 1er prix Polytech'Innovation et le 2e prix SENAYSKILLS ; Aquatus obtient le 2e prix Polytech'Innovation.", "score_value": None, "score_label": None, "file_id": None, "external_url": None, "order_index": 70, "is_featured": True},
])

INITIAL_HISTORICAL_STATISTICS = [
    {"id": "institutional-lives-impacted", "metric_key": "lives_impacted", "label": "Vies impactées", "value": 150000, "unit": "personnes", "description": "Plus de 150 000 vies impactées.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None, "minimum": True},
    {"id": "institutional-jobs-created", "metric_key": "jobs_created", "label": "Emplois créés", "value": 200, "unit": "emplois", "description": "Plus de 200 emplois créés.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None, "minimum": True},
    {"id": "institutional-people-trained", "metric_key": "people_trained", "label": "Personnes formées", "value": 1597, "unit": "personnes", "description": "1 597 personnes formées.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None},
    {"id": "institutional-products-developed", "metric_key": "products_developed", "label": "Produits développés", "value": 39, "unit": "produits", "description": "39 produits développés.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None},
    {"id": "institutional-work-hours", "metric_key": "work_hours", "label": "Heures de travail investies", "value": 36640, "unit": "heures", "description": "36 640 heures de travail investies.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None},
    {"id": "institutional-sdgs", "metric_key": "sdgs_touched", "label": "ODD touchés", "value": 11, "unit": "ODD", "description": "11 Objectifs de Développement Durable touchés.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None},
    {"id": "institutional-revenue-usd-2021-2022", "metric_key": "revenue_usd_2021_2022", "label": "Revenu total annuel 2021–2022", "value": 173193, "unit": "USD", "description": "125 521 USD pour Dimbali et 47 672 USD pour Mën Nañ, soit 173 193 USD au total.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None},
    {"id": "institutional-beneficiary-income", "metric_key": "beneficiary_income_increase_pct", "label": "Hausse des revenus des bénéficiaires", "value": 77, "unit": "%", "description": "Augmentation des revenus des bénéficiaires : +77 %.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None},
    {"id": "institutional-trees-planted", "metric_key": "trees_planted", "label": "Arbres plantés", "value": 1425, "unit": "arbres", "description": "1 425 arbres plantés au cumul.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None},
    {"id": "institutional-field-km", "metric_key": "field_kilometers", "label": "Kilomètres parcourus sur le terrain", "value": 8949, "unit": "km", "description": "8 949 km parcourus sur le terrain.", "source_label": INSTITUTIONAL_MEMORY_SOURCE_LABEL, "status": "validated", "validated_at": None},
]


from app.services.club_heritage import PUBLIC_HERITAGE_MEDIA, enrich_public_heritage

# Public evidence enriches the approved history without changing current impact.
enrich_public_heritage(INITIAL_HISTORICAL_PROJECTS, INITIAL_AWARDS, INITIAL_COMPETITIONS, INITIAL_HALL_OF_FAME)
from app.services.project_presentations import enrich_project_archives, enrich_project_archive
enrich_project_archives(INITIAL_HISTORICAL_PROJECTS)


def _project_payload(project: ArchivedProject) -> dict:
    return enrich_project_archive(ArchivedProjectRead.model_validate(project).model_dump())


def _award_payload(award: Award) -> dict:
    return AwardRead.model_validate(award).model_dump()


def _competition_payload(competition: CompetitionRecord) -> dict:
    return CompetitionRecordRead.model_validate(competition).model_dump()


def _file_payload(
    db: Session,
    current_user,
    stored_file: StoredFile | None,
) -> dict | None:
    if stored_file is None:
        return None
    try:
        ensure_file_access(db, stored_file, current_user)
    except HTTPException:
        return {
            "id": stored_file.id,
            "name": stored_file.original_filename,
            "download_url": None,
            "preview_url": None,
            "size_bytes": stored_file.file_size,
            "accessible": False,
        }
    return {
        "id": stored_file.id,
        "name": stored_file.original_filename,
        "download_url": f"/api/files/{stored_file.id}/download",
        "preview_url": f"/api/files/{stored_file.id}/preview",
        "size_bytes": stored_file.file_size,
        "accessible": True,
    }


def _media_payload(db: Session, current_user, media: MediaArchive) -> dict:
    data = MediaArchiveRead.model_validate(media).model_dump()
    stored_file = None
    if media.file_id:
        stored_file = db.query(StoredFile).filter(StoredFile.id == media.file_id).first()
    data["file"] = _file_payload(db, current_user, stored_file)
    return data


def _historical_document_payload(
    db: Session,
    current_user,
    document: HistoricalDocument,
) -> dict:
    data = HistoricalDocumentRead.model_validate(document).model_dump()
    stored_file = None
    if document.file_id:
        stored_file = db.query(StoredFile).filter(StoredFile.id == document.file_id).first()
    data["file"] = _file_payload(db, current_user, stored_file)
    return data


def _hall_of_fame_payload(db: Session, current_user, entry: HallOfFameEntry) -> dict:
    data = HallOfFameEntryRead.model_validate(entry).model_dump()
    stored_file = None
    if entry.file_id:
        stored_file = db.query(StoredFile).filter(StoredFile.id == entry.file_id).first()
    data["file"] = _file_payload(db, current_user, stored_file)
    return data


def _historical_statistic_has_provenance(
    statistic: HistoricalImpactStatistic,
) -> bool:
    return bool(
        statistic.source_file_id is not None
        or (statistic.source_label or "").strip()
    )


def _historical_statistic_payload(statistic: HistoricalImpactStatistic) -> dict:
    data = HistoricalImpactStatisticRead.model_validate(statistic).model_dump()
    provenance_ready = _historical_statistic_has_provenance(statistic)
    data["provenance_ready"] = provenance_ready
    if data["status"] == "validated" and not provenance_ready:
        data["status"] = "submitted"
        data["validated_by_id"] = None
        data["validated_at"] = None
    return data


def _archive_item_payload(item: ArchiveItem) -> dict:
    return ArchiveItemRead.model_validate(item).model_dump()


def _can_validate_archives(db: Session, user) -> bool:
    return bool(get_user_role_names(db, user.id).intersection(SECRETARIAT_ROLES))


def _is_memory_curator(db: Session, user) -> bool:
    return bool(get_user_role_names(db, user.id).intersection(MEMORY_CURATOR_ROLES))


def _static_compatibility_payload(row: dict) -> dict:
    # These records come from the institutional memory validated by Enactus ESP.
    # Keep the compatibility shape for existing clients while exposing their
    # authoritative institutional status and provenance.
    return {
        **row,
        "legacy": False,
        "verified": True,
        "trust": "institutional_verified",
        "source_label": row.get("source_label") or INSTITUTIONAL_MEMORY_SOURCE_LABEL,
    }


def _require_static_compatibility(db: Session, user, include_static: bool) -> None:
    # Supplied institutional-memory records are approved by Enactus ESP and are
    # therefore visible to every authenticated validated member.
    _ = (db, user, include_static)


def _parent_archive_item(db: Session, child) -> ArchiveItem | None:
    archive_item_id = getattr(child, "archive_item_id", None)
    if archive_item_id is None:
        return None
    return db.query(ArchiveItem).filter(ArchiveItem.id == archive_item_id).first()


def _can_view_parentless_legacy_visibility(db: Session, user, visibility) -> bool:
    normalized = str(visibility or "").strip().lower()
    roles = get_user_role_names(db, user.id)
    if normalized == "interne":
        return user.status in {"active", "alumni"}
    if normalized == "alumni":
        return user.status == "alumni" or "alumni" in roles
    if normalized == "enacchefs":
        return bool(roles.intersection(SECRETARIAT_ROLES))
    if normalized in {"privé", "prive", "private"}:
        return False
    return False


def _can_view_legacy_child(db: Session, user, child) -> bool:
    if _is_memory_curator(db, user):
        return True
    parent = _parent_archive_item(db, child)
    if parent is not None and not _can_view_archive_item(db, user, parent):
        return False
    if parent is None and hasattr(child, "visibility"):
        if not _can_view_parentless_legacy_visibility(
            db,
            user,
            getattr(child, "visibility", None),
        ):
            return False
    validation_status = getattr(child, "validation_status", None)
    if parent is None and validation_status is not None and validation_status != "VERIFIED":
        return False
    source_id = getattr(child, "source_id", None)
    if source_id is not None:
        source = (
            db.query(InstitutionalSource)
            .filter(InstitutionalSource.id == source_id)
            .first()
        )
        if source is None or source.visibility == "private":
            return False
    return True


def _require_visible_legacy_child(db: Session, user, child, label: str) -> None:
    if not _can_view_legacy_child(db, user, child):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"{label} introuvable")


def _ensure_legacy_child_editable(db: Session, child) -> None:
    if getattr(child, "validation_status", None) in {"VERIFIED", "REJECTED", "SUPERSEDED"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un fait finalise ne peut pas etre modifie via les archives heritees",
        )
    parent = _parent_archive_item(db, child)
    if parent is not None and parent.status in {"validated", "archived"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Le contenu d'une archive finalisee est immuable",
        )


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


def _mark_file_as_archive(db: Session, file_id) -> None:
    if file_id is None:
        return
    stored_file = db.query(StoredFile).filter(StoredFile.id == file_id).first()
    if not stored_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier d'archive introuvable",
        )
    stored_file.storage_scope = "archive"
    stored_file.is_temporary = False
    stored_file.expires_at = None


def _csv_download(filename: str, rows: list[list]) -> Response:
    output = StringIO()
    writer = csv.writer(output)
    writer.writerows(rows)
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


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
    current_user=Depends(require_memory_curator),
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
    current_user=Depends(require_memory_curator),
):
    archive_item = _archive_item_or_404(db, archive_id)
    if archive_item.status in {"validated", "archived"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une archive finalisee ne peut pas etre modifiee directement",
        )
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
    archive_item.updated_at = utc_now()
    db.commit()
    db.refresh(archive_item)
    return archive_item


@router.post("/items/{archive_id}/submit", response_model=ArchiveItemRead)
def submit_archive_item(
    archive_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    archive_item = _archive_item_or_404(db, archive_id)
    if archive_item.status in {"validated", "archived"}:
        raise HTTPException(status_code=409, detail="Une archive finalisee est immuable")
    archive_item.status = "submitted"
    archive_item.rejected_by_id = None
    archive_item.rejected_at = None
    archive_item.rejection_reason = None
    archive_item.updated_at = utc_now()
    db.commit()
    db.refresh(archive_item)
    return archive_item


@router.post("/items/{archive_id}/validate", response_model=ArchiveItemRead)
def validate_archive_item(
    archive_id: str,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    if not _can_validate_archives(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Validation d'archive réservée au SG, Team Leader ou Admin",
        )
    archive_item = _archive_item_or_404(db, archive_id)
    if archive_item.status in {"validated", "archived"}:
        raise HTTPException(status_code=409, detail="Une archive finalisee est immuable")
    archive_item.status = "validated"
    archive_item.validated_by_id = current_user.id
    archive_item.validated_at = utc_now()
    archive_item.rejected_by_id = None
    archive_item.rejected_at = None
    archive_item.rejection_reason = None
    archive_item.updated_at = utc_now()
    create_audit_log(
        db,
        "legacy_archive_validated",
        current_user.id,
        "archive_item",
        archive_item.id,
    )
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
    current_user=Depends(require_memory_curator),
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
    if archive_item.status in {"validated", "archived"}:
        raise HTTPException(status_code=409, detail="Une archive finalisee est immuable")
    archive_item.status = "rejected"
    archive_item.rejected_by_id = current_user.id
    archive_item.rejected_at = utc_now()
    archive_item.rejection_reason = payload.reason.strip()
    archive_item.updated_at = utc_now()
    create_audit_log(
        db,
        "legacy_archive_rejected",
        current_user.id,
        "archive_item",
        archive_item.id,
        new_value={"reason": payload.reason.strip()},
    )
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
    current_user=Depends(require_memory_curator),
):
    if not _can_validate_archives(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Archivage réservé au SG, Team Leader ou Admin",
        )
    archive_item = _archive_item_or_404(db, archive_id)
    if archive_item.status == "archived":
        return archive_item
    if archive_item.status != "validated":
        raise HTTPException(status_code=409, detail="Seule une archive validee peut etre archivee")
    archive_item.status = "archived"
    archive_item.updated_at = utc_now()
    create_audit_log(
        db,
        "legacy_archive_archived",
        current_user.id,
        "archive_item",
        archive_item.id,
    )
    db.commit()
    db.refresh(archive_item)
    return archive_item


@router.get("/export/items.csv")
def export_archive_items_csv(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    if not _can_validate_archives(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Export archives réservé au SG, Team Leader ou Admin",
        )
    rows = [
        [
            "Titre",
            "Categorie",
            "Annee",
            "Visibilite",
            "Statut",
            "Mis en avant",
            "Public",
            "Source",
            "Creation",
            "Validation",
        ]
    ]
    items = db.query(ArchiveItem).order_by(ArchiveItem.updated_at.desc()).all()
    for item in items:
        rows.append(
            [
                item.title,
                item.category,
                item.year or "",
                item.visibility,
                item.status,
                "oui" if item.is_featured else "non",
                "oui" if item.is_public else "non",
                item.source_label or "",
                item.created_at,
                item.validated_at or "",
            ]
        )
    return _csv_download("enactspace_archives.csv", rows)


@router.get("/historical-projects")
def list_historical_projects(
    search: str | None = Query(default=None),
    year: int | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    include_static: bool = Query(default=True),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    _require_static_compatibility(db, current_user, include_static)
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
        if _can_view_legacy_child(db, current_user, project)
    ]
    static_projects = []
    if include_static:
        static_projects = [
            _static_compatibility_payload(project)
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
    current_user=Depends(require_memory_curator),
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
            _require_static_compatibility(db, current_user, True)
            return _static_compatibility_payload(project)
    persisted = _get_archived_project_or_404(db, project_id)
    _require_visible_legacy_child(db, current_user, persisted, "Projet historique")
    return _project_payload(persisted)


@router.patch("/historical-projects/{project_id}", response_model=ArchivedProjectRead)
def update_historical_project(
    project_id: str,
    payload: ArchivedProjectUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    project = _get_archived_project_or_404(db, project_id)
    _ensure_legacy_child_editable(db, project)
    data = payload.model_dump(exclude_unset=True)
    if "status" in data and data["status"] not in VALID_ARCHIVED_PROJECT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de projet historique invalide",
        )
    for field, value in data.items():
        setattr(project, field, value)
    project.updated_at = utc_now()
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
    _require_static_compatibility(db, current_user, include_static)
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
        if _can_view_legacy_child(db, current_user, award)
    ]
    static_awards = []
    if include_static:
        static_awards = [
            _static_compatibility_payload(award)
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
    current_user=Depends(require_memory_curator),
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
            _require_static_compatibility(db, current_user, True)
            return _static_compatibility_payload(award)
    award = db.query(Award).filter(Award.id == award_id).first()
    if not award:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prix ou distinction introuvable",
        )
    _require_visible_legacy_child(db, current_user, award, "Prix ou distinction")
    return _award_payload(award)


@router.patch("/awards/{award_id}", response_model=AwardRead)
def update_award(
    award_id: str,
    payload: AwardUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    award = db.query(Award).filter(Award.id == award_id).first()
    if not award:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Prix ou distinction introuvable",
        )
    _ensure_legacy_child_editable(db, award)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(award, field, value)
    award.updated_at = utc_now()
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
    _require_static_compatibility(db, current_user, include_static)
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
        if _can_view_legacy_child(db, current_user, competition)
    ]
    static_competitions = []
    if include_static:
        static_competitions = [
            _static_compatibility_payload(competition)
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
    current_user=Depends(require_memory_curator),
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
            _require_static_compatibility(db, current_user, True)
            return _static_compatibility_payload(competition)
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
    _require_visible_legacy_child(db, current_user, competition, "Competition")
    return _competition_payload(competition)


@router.patch("/competitions/{competition_id}", response_model=CompetitionRecordRead)
def update_competition(
    competition_id: str,
    payload: CompetitionRecordUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
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
    _ensure_legacy_child_editable(db, competition)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(competition, field, value)
    competition.updated_at = utc_now()
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
        # Approved public projects use stable slugs; persisted relations use UUIDs.
        try:
            UUID(project_id)
        except ValueError:
            query = query.filter(False)
        else:
            query = query.filter(MediaArchive.archived_project_id == project_id)
    media = query.order_by(
        MediaArchive.year.desc().nullslast(),
        MediaArchive.is_featured.desc(),
        MediaArchive.created_at.desc(),
    ).all()
    return {
        "media": [
            _media_payload(db, current_user, item)
            for item in media
            if _can_view_legacy_child(db, current_user, item)
        ] + [
            _static_compatibility_payload(item)
            for item in PUBLIC_HERITAGE_MEDIA
            if (not search or search.casefold() in f"{item['title']} {item['description']} {item['source_label']}".casefold())
            and (year is None or item["year"] == year)
            and (not media_type or item["media_type"] == media_type)
            and (not project_id or item["project_id"] == project_id)
        ]
    }


@router.post("/media")
def create_archive_media(
    payload: MediaArchiveCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
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
    return _media_payload(db, current_user, media)


@router.patch("/media/{media_id}")
def update_archive_media(
    media_id: str,
    payload: MediaArchiveUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    media = db.query(MediaArchive).filter(MediaArchive.id == media_id).first()
    if not media:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Média d'archive introuvable",
        )
    _ensure_legacy_child_editable(db, media)
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
    media.updated_at = utc_now()
    db.commit()
    db.refresh(media)
    return _media_payload(db, current_user, media)


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
    return {
        "documents": [
            _historical_document_payload(db, current_user, item)
            for item in documents
            if _can_view_legacy_child(db, current_user, item)
        ]
    }


@router.post("/documents")
def create_historical_document(
    payload: HistoricalDocumentCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
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
    return _historical_document_payload(db, current_user, document)


@router.patch("/documents/{document_id}")
def update_historical_document(
    document_id: str,
    payload: HistoricalDocumentUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    document = (
        db.query(HistoricalDocument).filter(HistoricalDocument.id == document_id).first()
    )
    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document historique introuvable",
        )
    _ensure_legacy_child_editable(db, document)
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
    document.updated_at = utc_now()
    db.commit()
    db.refresh(document)
    return _historical_document_payload(db, current_user, document)


@router.get("/hall-of-fame")
def list_hall_of_fame(
    year: int | None = Query(default=None),
    entry_type: str | None = Query(default=None),
    featured: bool | None = Query(default=None),
    include_static: bool = Query(default=True),
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    _require_static_compatibility(db, current_user, include_static)
    query = db.query(HallOfFameEntry)
    if year is not None:
        query = query.filter(HallOfFameEntry.year == year)
    if entry_type:
        query = query.filter(HallOfFameEntry.entry_type == entry_type)
    if featured is not None:
        query = query.filter(HallOfFameEntry.is_featured.is_(featured))
    entries = [
        _hall_of_fame_payload(db, current_user, entry)
        for entry in query.order_by(
            HallOfFameEntry.order_index.asc(),
            HallOfFameEntry.year.desc().nullslast(),
            HallOfFameEntry.created_at.desc(),
        ).all()
        if _can_view_legacy_child(db, current_user, entry)
    ]
    static_entries = []
    if include_static:
        static_entries = [
            _static_compatibility_payload(entry)
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
    current_user=Depends(require_memory_curator),
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
    return _hall_of_fame_payload(db, current_user, entry)


@router.patch("/hall-of-fame/{entry_id}")
def update_hall_of_fame_entry(
    entry_id: str,
    payload: HallOfFameEntryUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    entry = db.query(HallOfFameEntry).filter(HallOfFameEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Entrée Hall of Fame introuvable",
        )
    _ensure_legacy_child_editable(db, entry)
    data = payload.model_dump(exclude_unset=True)
    if "file_id" in data:
        _mark_file_as_archive(db, data["file_id"])
    for field, value in data.items():
        setattr(entry, field, value)
    entry.updated_at = utc_now()
    db.commit()
    db.refresh(entry)
    return _hall_of_fame_payload(db, current_user, entry)


@router.get("/historical-impact/summary")
def get_historical_impact_summary(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_active_validated_user),
):
    summary = {
        statistic["metric_key"]: float(statistic["value"])
        for statistic in INITIAL_HISTORICAL_STATISTICS
    }
    db_statistics = (
        db.query(HistoricalImpactStatistic)
        .filter(HistoricalImpactStatistic.status == "validated")
        .all()
    )
    db_statistics = [
        statistic
        for statistic in db_statistics
        if _historical_statistic_has_provenance(statistic)
    ]
    persisted_keys = {statistic.metric_key for statistic in db_statistics}
    for statistic in db_statistics:
        summary[statistic.metric_key] = float(statistic.value)
    summary["statistics"] = [
        *[
            statistic
            for statistic in INITIAL_HISTORICAL_STATISTICS
            if statistic["metric_key"] not in persisted_keys
        ],
        *[_historical_statistic_payload(statistic) for statistic in db_statistics],
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
    statistics = list(db_statistics.values())
    if include_defaults:
        statistics = [
            *[
                statistic
                for statistic in INITIAL_HISTORICAL_STATISTICS
                if statistic["metric_key"] not in db_statistics
            ],
            *statistics,
        ]
    return {"statistics": statistics}


@router.post("/historical-impact/statistics")
def create_historical_impact_statistic(
    payload: HistoricalImpactStatisticCreate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
):
    if payload.status not in VALID_HISTORICAL_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de statistique historique invalide",
        )
    if payload.status == "validated" and not (
        payload.source_file_id is not None or (payload.source_label or "").strip()
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Une source est requise pour valider une statistique historique",
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
        statistic.validated_at = utc_now()
    db.add(statistic)
    db.commit()
    db.refresh(statistic)
    return _historical_statistic_payload(statistic)


@router.patch("/historical-impact/statistics/{statistic_id}")
def update_historical_impact_statistic(
    statistic_id: str,
    payload: HistoricalImpactStatisticUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(require_memory_curator),
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
    if statistic.status == "validated":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une statistique historique validee est immuable",
        )
    data = payload.model_dump(exclude_unset=True)
    if "status" in data and data["status"] not in VALID_HISTORICAL_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de statistique historique invalide",
        )
    if "source_file_id" in data:
        _mark_file_as_archive(db, data["source_file_id"])
    resulting_status = data.get("status", statistic.status)
    resulting_source_file_id = data.get(
        "source_file_id",
        statistic.source_file_id,
    )
    resulting_source_label = data.get("source_label", statistic.source_label)
    if resulting_status == "validated" and not (
        resulting_source_file_id is not None
        or (resulting_source_label or "").strip()
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Une source est requise pour valider une statistique historique",
        )
    for field, value in data.items():
        setattr(statistic, field, value)
    statistic.updated_by_id = current_user.id
    if data.get("status") == "validated":
        statistic.validated_by_id = current_user.id
        statistic.validated_at = utc_now()
    statistic.updated_at = utc_now()
    db.commit()
    db.refresh(statistic)
    return _historical_statistic_payload(statistic)
