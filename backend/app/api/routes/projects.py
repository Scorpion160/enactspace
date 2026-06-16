from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.project import Project, ProjectMember
from app.schemas.project import (
    ProjectCreate,
    ProjectMemberAssign,
    ProjectMemberRead,
    ProjectRead,
    ProjectUpdate,
)
from app.api.deps import get_current_user, require_enacchef_or_admin
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
VALID_PROJECT_POSITIONS = {"membre", "chef_projet", "adjoint_chef_projet"}


def get_project_or_404(db: Session, project_id: str) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Projet introuvable",
        )
    return project


def get_user_or_404(db: Session, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utilisateur introuvable",
        )
    return user


def project_member_payload(membership: ProjectMember, user: User) -> ProjectMemberRead:
    display_name = f"{user.first_name} {user.last_name}".strip() or user.email
    return ProjectMemberRead(
        id=membership.id,
        project_id=membership.project_id,
        user_id=membership.user_id,
        position=membership.position,
        joined_at=membership.joined_at,
        left_at=membership.left_at,
        is_active=membership.is_active,
        display_name=display_name,
        email=user.email,
    )


@router.post("/", response_model=ProjectRead)
def create_project(
    payload: ProjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
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
    current_user: User = Depends(require_enacchef_or_admin),
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


@router.get("/{project_id}/members", response_model=list[ProjectMemberRead])
def list_project_members(
    project_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_project_or_404(db, project_id)
    rows = (
        db.query(ProjectMember, User)
        .join(User, User.id == ProjectMember.user_id)
        .filter(
            ProjectMember.project_id == project_id,
            ProjectMember.is_active.is_(True),
        )
        .order_by(ProjectMember.position.asc(), ProjectMember.joined_at.asc())
        .all()
    )
    return [project_member_payload(membership, user) for membership, user in rows]


@router.post("/{project_id}/members", response_model=ProjectMemberRead)
def assign_project_member(
    project_id: str,
    payload: ProjectMemberAssign,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    get_project_or_404(db, project_id)
    user = get_user_or_404(db, str(payload.user_id))

    if payload.position not in VALID_PROJECT_POSITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Position projet invalide",
        )

    membership = (
        db.query(ProjectMember)
        .filter(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == payload.user_id,
        )
        .first()
    )

    if membership is None:
        membership = ProjectMember(
            project_id=project_id,
            user_id=payload.user_id,
            position=payload.position,
        )
        db.add(membership)
    else:
        membership.position = payload.position
        membership.is_active = True
        membership.left_at = None

    db.commit()
    db.refresh(membership)

    return project_member_payload(membership, user)


@router.delete("/{project_id}/members/{user_id}", response_model=ProjectMemberRead)
def remove_project_member(
    project_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    row = (
        db.query(ProjectMember, User)
        .join(User, User.id == ProjectMember.user_id)
        .filter(ProjectMember.project_id == project_id, ProjectMember.user_id == user_id)
        .first()
    )

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Membre non rattaché à ce projet",
        )

    membership, user = row
    membership.is_active = False
    membership.left_at = date.today()
    db.commit()
    db.refresh(membership)

    return project_member_payload(membership, user)
