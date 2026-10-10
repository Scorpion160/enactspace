"""Import relançable des archives documentées d'Enactus ESP.

Commande : python -m app.services.club_heritage_seed
Les sources sont identifiées par leur titre, sans publier de coordonnées privées.
"""
from app.db.database import SessionLocal
from app.models.archive import ArchiveItem, ArchivedProject
from app.models.impact import ImpactProject
from app.models.institutional_memory import CanonicalProject, InstitutionalSource
from app.models.project import Project

HISTORY = "Histoire de Enactus ESP.pdf"
DIMBALI = "Projet Dimbali/dimbali.pdf"
AQUATUS = "Enactus 2025/PROJETS/Aquatus/Fiche de projet/FICHE DE PROJET AQUATUS (2).pdf"
SOURCES = (
    (HISTORY, "Chronologie du club, fondation et projets des promotions 2015 à 2023."),
    (DIMBALI, "Article sur le projet Dimbali à Ngayène Sabakh."),
    (AQUATUS, "Fiche de conception du projet Aquatus et de son financement prévu."),
)
PROJECTS = (
    ("Dimbali", "dimbali", 2016, DIMBALI,
     "Valorisation du fruit de dimb, farine enrichie, séchage solaire et accompagnement de l'association FAVEC à Ngayène Sabakh.",
     "L'article décrit des actions et résultats en nutrition, revenus et savoir-faire. Aucun total chiffré n'est repris sans méthode de mesure."),
    ("Aquatus", "aquatus", 2023, AQUATUS,
     "Projet d'aquaponie associant poissons et cultures végétales ; la fiche présente un modèle envisagé.",
     "La fiche chiffre un besoin de financement prévisionnel à 2,5 millions FCFA, et non un impact réalisé."),
    ("Javelisel", "javelisel", 2015, HISTORY,
     "Projet d'hygiène cité parmi les premiers projets de l'équipe.",
     "Le document historique atteste le projet ; résultats chiffrés non documentés ici."),
    ("Mën Nañ", "men-nan", 2019, HISTORY,
     "Projet cité dans la chronologie du club à partir de 2019.",
     "Résultats chiffrés non documentés dans cette source."),
    ("SHERY", "shery", 2021, HISTORY,
     "Projet cité dans la chronologie du club à partir de 2021.",
     "Résultats chiffrés non documentés dans cette source."),
    ("Terrasen", "terrasen", 2022, HISTORY,
     "Projet cité parmi les projets de l’année 2022–2023.",
     "Résultats chiffrés non documentés dans cette source."),
    ("CAJOR", "cajor", 2022, HISTORY,
     "Projet cité parmi les projets de l’année 2022–2023.",
     "Résultats chiffrés non documentés dans cette source."),
)


def seed_club_heritage(db):
    counts = {"sources": 0, "memory": 0, "archives": 0, "impact": 0}
    sources = {}
    for title, notes in SOURCES:
        source = db.query(InstitutionalSource).filter_by(title=title).first()
        if source is None:
            source = InstitutionalSource(source_type="document", title=title,
                source_label="Archives documentaires Enactus ESP", notes=notes,
                visibility="internal", validation_status="HISTORICAL_REPORTED")
            db.add(source)
            db.flush()
            counts["sources"] += 1
        sources[title] = source
    for name, slug, year, reference, description, impact in PROJECTS:
        source = sources[reference]
        canonical = db.query(CanonicalProject).filter_by(slug=slug).first()
        if canonical is None:
            canonical = CanonicalProject(canonical_name=name, slug=slug,
                description=description, first_year=year, source_id=source.id,
                validation_status="HISTORICAL_REPORTED")
            db.add(canonical)
            counts["memory"] += 1
        archive = db.query(ArchiveItem).filter_by(
            title=f"{name} — mémoire du projet",
            source_label=reference).first()
        if archive is None:
            archive = ArchiveItem(title=f"{name} — mémoire du projet",
                description=f"{description}\n\nImpact : {impact}",
                category="Projet historique", year=year, visibility="interne",
                status="draft", source_label=reference,
                tags=["mémoire", "projet", "source documentaire"],
                metadata_json={"source_title": reference, "claim_scope": "historical_reported"})
            db.add(archive)
            db.flush()
            db.add(ArchivedProject(archive_item_id=archive.id, name=name,
                year=year, description=description, impact_summary=impact,
                status="historique"))
            counts["archives"] += 1
        # L'impact opérationnel n'est lié qu'à un projet déjà présent dans le portfolio.
        # Aucun nouveau projet actuel n'est créé à partir d'une archive.
        project = db.query(Project).filter(Project.name.ilike(name)).first()
        if project and db.query(ImpactProject).filter_by(project_id=project.id).first() is None:
            db.add(ImpactProject(project_id=project.id, title=name,
                summary=description, evidence_notes=f"Source : {reference}. {impact}",
                methodology="Récit historique ; indicateurs chiffrés non établis.",
                validation_status="EVIDENCE_PENDING", status="draft"))
            counts["impact"] += 1
    db.commit()
    return counts


if __name__ == "__main__":
    with SessionLocal() as session:
        print(seed_club_heritage(session))
