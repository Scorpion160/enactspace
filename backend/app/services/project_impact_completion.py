"""Complete editable Impact narratives and attach historical reference documents."""
from pathlib import Path
from app.models.impact import ImpactProject, ImpactEvidence
from app.models.project import Project
from app.services.file_storage_service import store_bytes
from app.services.project_presentations import get_project_presentation


def complete_impact_catalog(db, documents: dict[str, Path]):
    changes = []
    for project in db.query(Project).with_for_update().all():
        reference = get_project_presentation(project.name)
        if reference is None:
            continue
        record = db.query(ImpactProject).filter_by(project_id=project.id).first()
        if record is None:
            record = ImpactProject(project_id=project.id, season_id=project.season_id,
                                   title=project.name, validation_status="DRAFT")
            db.add(record)
            db.flush()
        fields = []
        if record.validation_status in {"DRAFT", "EVIDENCE_PENDING", "EVIDENCE_ATTACHED"}:
            for field, source in [("summary","description"), ("problem_statement","problem"),
                                  ("solution_summary","solution"), ("target_population","target_population")]:
                if not getattr(record, field):
                    setattr(record, field, reference[source])
                    fields.append(field)
            if not record.sdgs and reference["sdgs"]:
                record.sdgs = list(reference["sdgs"])
                fields.append("sdgs")
        path = documents.get(reference["id"])
        evidence_title = f"{reference['name']} — dossier de référence"
        if path is not None and not db.query(ImpactEvidence).filter_by(
                impact_project_id=record.id, title=evidence_title).first():
            file = store_bytes(db, data=path.read_bytes(), original_filename=path.name,
                               uploaded_by=None, mime_type="application/pdf",
                               storage_scope="impact", visibility="private",
                               entity_type="impact_record", entity_id=record.id,
                               is_temporary=False)
            db.flush()
            db.add(ImpactEvidence(impact_project_id=record.id, file_id=file.id,
                title=evidence_title, description="Présentation du projet, démarche et perspectives.",
                category="reference", validation_status="EVIDENCE_ATTACHED", status="submitted"))
            fields.append("reference_document")
        if fields:
            changes.append({"project":reference["name"],"fields":fields})
    db.flush()
    return changes
