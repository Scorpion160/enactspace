from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.project import Project
from app.schemas.project import ProjectCreate, ProjectRead
from app.api.deps import get_current_user
from app.models.user import User


router = APIRouter(prefix="/projects", tags=["Projets"])


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