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
from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
    require_sg_or_admin,
)
from app.models.role import Role, UserRole
from app.models.user import User
from app.services.notification_service import notify_user


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
GLOBAL_PROJECT_MANAGERS = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}
PROJECT_LEADERSHIP_POSITIONS = {"chef_projet", "adjoint_chef_projet"}


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
        photo_url=user.photo_url,
        status=user.status,
    )


def require_project_manager(
    db: Session,
    current_user: User,
    project_id: str,
) -> bool:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_PROJECT_MANAGERS):
        return True

    membership = (
        db.query(ProjectMember.id)
        .filter(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == current_user.id,
            ProjectMember.is_active.is_(True),
            ProjectMember.left_at.is_(None),
            ProjectMember.position.in_(PROJECT_LEADERSHIP_POSITIONS),
        )
        .first()
    )
    if membership:
        return False

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Gestion réservée aux responsables de ce projet",
    )


def sync_project_responsibility_role(
    db: Session,
    user_id,
    role_name: str,
) -> None:
    role = db.query(Role).filter(Role.name == role_name).first()
    if role is None:
        role = Role(name=role_name, description="Responsabilité de projet")
        db.add(role)
        db.flush()

    should_have_role = (
        db.query(ProjectMember.id)
        .filter(
            ProjectMember.user_id == user_id,
            ProjectMember.position == role_name,
            ProjectMember.is_active.is_(True),
            ProjectMember.left_at.is_(None),
        )
        .first()
        is not None
    )
    assignment = (
        db.query(UserRole)
        .filter(UserRole.user_id == user_id, UserRole.role_id == role.id)
        .first()
    )
    if should_have_role and assignment is None:
        db.add(UserRole(user_id=user_id, role_id=role.id))
    elif not should_have_role and assignment is not None:
        db.delete(assignment)


@router.post("/", response_model=ProjectRead)
def create_project(
    payload: ProjectCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
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
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(Project).order_by(Project.created_at.desc()).all()


@router.patch("/{project_id}", response_model=ProjectRead)
def update_project(
    project_id: str,
    payload: ProjectUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    project = get_project_or_404(db, project_id)
    require_project_manager(db, current_user, project_id)
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
    current_user: User = Depends(get_current_active_validated_user),
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
    current_user: User = Depends(get_current_active_validated_user),
):
    project = get_project_or_404(db, project_id)
    user = get_user_or_404(db, str(payload.user_id))
    is_global_manager = require_project_manager(db, current_user, project_id)

    if payload.position not in VALID_PROJECT_POSITIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Position projet invalide",
        )
    if (
        payload.position in PROJECT_LEADERSHIP_POSITIONS
        and not is_global_manager
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seuls Admin, Team Leader ou SG nomment les responsables",
        )
    if user.status != "active" or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le membre sélectionné n'est pas actif",
        )

    membership = (
        db.query(ProjectMember)
        .filter(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == payload.user_id,
        )
        .first()
    )

    previous_position = None
    membership_created = membership is None
    if membership is None:
        membership = ProjectMember(
            project_id=project_id,
            user_id=payload.user_id,
            position=payload.position,
        )
        db.add(membership)
    else:
        previous_position = membership.position
        membership.position = payload.position
        membership.is_active = True
        membership.left_at = None

    if payload.position in PROJECT_LEADERSHIP_POSITIONS:
        existing_leaders = (
            db.query(ProjectMember)
            .filter(
                ProjectMember.project_id == project_id,
                ProjectMember.user_id != payload.user_id,
                ProjectMember.position == payload.position,
                ProjectMember.is_active.is_(True),
            )
            .all()
        )
        for existing_leader in existing_leaders:
            existing_leader.position = "membre"
            sync_project_responsibility_role(
                db,
                existing_leader.user_id,
                payload.position,
            )
            notify_user(
                db,
                user_id=existing_leader.user_id,
                title=f"Responsabilité mise à jour dans {project.name}",
                message="Votre position est désormais membre du projet.",
                notification_type="role_assigned",
                related_type="project",
                related_id=project.id,
            )

    if previous_position in PROJECT_LEADERSHIP_POSITIONS:
        sync_project_responsibility_role(db, payload.user_id, previous_position)
    if payload.position in PROJECT_LEADERSHIP_POSITIONS:
        sync_project_responsibility_role(db, payload.user_id, payload.position)
    if membership_created or previous_position != payload.position:
        notify_user(
            db,
            user_id=payload.user_id,
            title=f"Affectation au projet {project.name}",
            message=f"Votre position est désormais : {payload.position}.",
            notification_type="role_assigned",
            related_type="project",
            related_id=project.id,
        )

    db.commit()
    db.refresh(membership)

    return project_member_payload(membership, user)


@router.delete("/{project_id}/members/{user_id}", response_model=ProjectMemberRead)
def remove_project_member(
    project_id: str,
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    project = get_project_or_404(db, project_id)
    is_global_manager = require_project_manager(db, current_user, project_id)
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
    if (
        membership.position in PROJECT_LEADERSHIP_POSITIONS
        and not is_global_manager
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seuls Admin, Team Leader ou SG retirent un responsable",
        )
    previous_position = membership.position
    membership.is_active = False
    membership.left_at = date.today()
    if previous_position in PROJECT_LEADERSHIP_POSITIONS:
        sync_project_responsibility_role(db, membership.user_id, previous_position)
    notify_user(
        db,
        user_id=membership.user_id,
        title=f"Fin d'affectation au projet {project.name}",
        message="Vous ne faites plus partie de l'équipe de ce projet.",
        notification_type="role_assigned",
        related_type="project",
        related_id=project.id,
    )
    db.commit()
    db.refresh(membership)

    return project_member_payload(membership, user)
