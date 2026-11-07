"""Fill documented project narratives without replacing team edits or current metrics."""
from app.models.project import Project
from app.services.project_presentations import get_project_presentation

PLACEHOLDERS = {"Projet actif de Enactus ESP.", "Projet actif d’Enactus ESP.", ""}


def complete_project_catalog(db):
    changes = []
    for project in db.query(Project).with_for_update().all():
        reference = get_project_presentation(project.name)
        if reference is None:
            continue
        fields = []
        for field, source in [("description","description"), ("problem_statement","problem"),
                              ("solution","solution"), ("objectives","objectives"),
                              ("expected_impact","expected_impact")]:
            current = getattr(project, field)
            if current is None or current.strip() in PLACEHOLDERS:
                setattr(project, field, reference[source])
                fields.append(field)
        if project.name.strip().casefold() in {"cherry", "sherry"}:
            project.name = "SHERY"
            fields.append("name")
        if fields:
            changes.append({"project": reference["name"], "fields": fields})
    db.flush()
    return changes
