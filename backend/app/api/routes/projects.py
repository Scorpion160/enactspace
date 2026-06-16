from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.project import Project
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.api.deps import get_current_user
from app.models.user import User


router = APIRouter(prefix="/projects", tags=["Projets"])
VALID_PROJECT_STATUSES = {
    "idee",
    "etude",
    "prototype",
    "test",
    "deploiement",
    "termine",
    "suspendu",
}


def get_project_or_404(db: Session, project_id: str) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Projet introuvable",
        )
    return project


@router.post("/", response_model=ProjectRead)
def create_project(
    payload: ProjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = Project(
        season_id=payload.season_id,
        name=payload.name,
        description=payload.description,
        problem_statement=payload.problem_statement,
        solution=payload.solution,
        objectives=payload.objectives,
        expected_impact=payload.expected_impact,
        budget_estimated=payload.budget_estimated,
        status=payload.status,
        started_at=payload.started_at,
        ended_at=payload.ended_at,
    )

    db.add(project)
    db.commit()
    db.refresh(project)

    return project


@router.get("/", response_model=list[ProjectRead])
def list_projects(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Project).order_by(Project.created_at.desc()).all()


@router.patch("/{project_id}", response_model=ProjectRead)
def update_project(
    project_id: str,
    payload: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = get_project_or_404(db, project_id)
    data = payload.model_dump(exclude_unset=True)

    if data.get("status") is not None and data["status"] not in VALID_PROJECT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut projet invalide",
        )

    for field, value in data.items():
        setattr(project, field, value)

    project.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(project)

    return project
