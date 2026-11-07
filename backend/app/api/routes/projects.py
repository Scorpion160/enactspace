from uuid import UUID
from app.core.time import utc_now
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

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
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.notification_service import notify_user
from app.services.operational_integrity import assert_active_operational_member, assert_operational_actor, lock_row, lock_structure_write, assert_existing_year, assert_project_dates, get_or_create_role
from app.services.institutional_memory_capture import capture_project_completion


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
PROJECT_STATUS_TRANSITIONS = {
    "idee": {"etude", "suspendu"},
    "etude": {"idee", "prototype", "suspendu"},
    "prototype": {"etude", "test", "suspendu"},
    "test": {"prototype", "deploiement", "suspendu"},
    "deploiement": {"test", "termine", "suspendu"},
    "suspendu": {"idee", "etude", "prototype", "test", "deploiement"},
    "termine": set(),
}
VALID_PROJECT_POSITIONS = {"membre", "chef_projet", "adjoint_chef_projet"}
GLOBAL_PROJECT_MANAGERS = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}
PROJECT_LEADERSHIP_POSITIONS = {"chef_projet", "adjoint_chef_projet"}


def get_project_or_404(db: Session, project_id: UUID) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if project is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Projet introuvable",
        )
    return project


def get_user_or_404(db: Session, user_id: UUID) -> User:
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
    project_id: UUID,
) -> bool:
    assert_operational_actor(current_user)
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
    role = get_or_create_role(db, role_name)

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


def apply_project_status(project: Project, next_status: str) -> bool:
    if next_status not in VALID_PROJECT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut projet invalide",
        )
    if next_status == project.status:
        return False
    if next_status not in PROJECT_STATUS_TRANSITIONS.get(project.status, set()):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Transition projet interdite : {project.status} -> {next_status}",
        )
    project.status = next_status
    return True


@router.post("/", response_model=ProjectRead)
def create_project(
    payload: ProjectCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    if payload.status not in VALID_PROJECT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut projet invalide",
        )
    current_user, _, _ = lock_structure_write(db, current_user.id, Project)
    if not get_user_role_names(db, current_user.id).intersection(GLOBAL_PROJECT_MANAGERS):
        raise HTTPException(403, "Gestion réservée à la direction du club.")
    assert_existing_year(db, payload.season_id)
    assert_project_dates(payload.started_at, payload.ended_at)

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
    db.flush()
    create_audit_log(
        db=db,
        action="creation_projet",
        user_id=current_user.id,
        entity_type="project",
        entity_id=project.id,
        new_value={"name": project.name, "status": project.status},
        ip_address=get_client_ip(request),
    )
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
    project_id: UUID,
    payload: ProjectUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current_user, _, project = lock_structure_write(db, current_user.id, Project, project_id)
    global_manager = require_project_manager(db, current_user, project_id)
    data = payload.model_dump(exclude_unset=True)

    if "season_id" in data and data["season_id"] != project.season_id and not global_manager:
        raise HTTPException(403, "Le changement d'année relève de la direction du club.")
    if "season_id" in data:
        assert_existing_year(db, data["season_id"])
    if "started_at" in data or "ended_at" in data:
        assert_project_dates(data.get("started_at", project.started_at), data.get("ended_at", project.ended_at))
    old_value = {key: getattr(project, key) for key in data}
    next_status = data.pop("status", None)
    status_changed = False
    if next_status is not None:
        status_changed = apply_project_status(project, next_status)
    for field, value in data.items():
        setattr(project, field, value)

    project.updated_at = utc_now()
    new_value = {key: getattr(project, key) for key in old_value}
    if next_status is not None:
        old_value["status"] = old_value.get("status", project.status if not status_changed else None)
        new_value["status"] = project.status
    create_audit_log(
        db=db,
        action="changement_statut_projet" if status_changed else "modification_projet",
        user_id=current_user.id,
        entity_type="project",
        entity_id=project.id,
        old_value={key: str(value) if value is not None else None for key, value in old_value.items()},
        new_value={key: str(value) if value is not None else None for key, value in new_value.items()},
        ip_address=get_client_ip(request),
    )
    if status_changed and project.status == "termine":
        capture_project_completion(db, project, actor_id=current_user.id)
    db.commit()
    db.refresh(project)

    return project


@router.get("/{project_id}/members", response_model=list[ProjectMemberRead])
def list_project_members(
    project_id: UUID,
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
            ProjectMember.left_at.is_(None),
        )
        .order_by(ProjectMember.position.asc(), ProjectMember.joined_at.asc())
        .all()
    )
    return [project_member_payload(membership, user) for membership, user in rows]


@router.post("/{project_id}/members", response_model=ProjectMemberRead)
def assign_project_member(
    project_id: UUID,
    payload: ProjectMemberAssign,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current_user, user, project = lock_structure_write(db, current_user.id, Project, project_id, payload.user_id)
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
    assert_active_operational_member(user)

    membership = (
        db.query(ProjectMember)
        .filter(
            ProjectMember.project_id == project_id,
            ProjectMember.user_id == payload.user_id,
        )
        .with_for_update()
        .first()
    )

    if membership is not None and membership.position in PROJECT_LEADERSHIP_POSITIONS and not is_global_manager:
        raise HTTPException(403, "La modification d'une responsabilité relève de la direction du club.")

    previous_position = None
    membership_created = membership is None
    old_value = None
    if membership is None:
        membership = ProjectMember(
            project_id=project_id,
            user_id=payload.user_id,
            position="membre",
        )
        db.add(membership)
    else:
        previous_position = membership.position
        old_value = {
            "project_id": str(membership.project_id),
            "project_name": project.name,
            "position": membership.position,
            "is_active": membership.is_active,
            "left_at": membership.left_at.isoformat()
            if membership.left_at
            else None,
        }
        membership.position = "membre"
        membership.is_active = True
        membership.left_at = None

    db.flush()
    if payload.position in PROJECT_LEADERSHIP_POSITIONS:
        existing_leaders = (
            db.query(ProjectMember)
            .filter(
                ProjectMember.project_id == project_id,
                ProjectMember.user_id != payload.user_id,
                ProjectMember.position == payload.position,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
            )
            .order_by(ProjectMember.id.asc())
            .with_for_update()
            .all()
        )
        for existing_leader in existing_leaders:
            previous_leader_position = existing_leader.position
            existing_leader.position = "membre"
            db.flush()
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
            create_audit_log(
                db=db,
                action="remplacement_responsable_projet",
                user_id=current_user.id,
                entity_type="user",
                entity_id=existing_leader.user_id,
                old_value={
                    "project_id": str(project.id),
                    "project_name": project.name,
                    "position": previous_leader_position,
                },
                new_value={
                    "project_id": str(project.id),
                    "project_name": project.name,
                    "position": "membre",
                },
                ip_address=get_client_ip(request),
            )

    membership.position = payload.position
    db.flush()
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

    create_audit_log(
        db=db,
        action="affectation_projet",
        user_id=current_user.id,
        entity_type="user",
        entity_id=payload.user_id,
        old_value=old_value,
        new_value={
            "project_id": str(project.id),
            "project_name": project.name,
            "position": membership.position,
            "is_active": membership.is_active,
        },
        ip_address=get_client_ip(request),
    )

    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cette responsabilité de projet vient d'être attribuée",
        ) from exc
    db.refresh(membership)

    return project_member_payload(membership, user)


@router.delete("/{project_id}/members/{user_id}", response_model=ProjectMemberRead)
def remove_project_member(
    project_id: UUID,
    user_id: UUID,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current_user, _, project = lock_structure_write(db, current_user.id, Project, project_id, user_id)
    is_global_manager = require_project_manager(db, current_user, project_id)
    row = (
        db.query(ProjectMember, User)
        .join(User, User.id == ProjectMember.user_id)
        .filter(ProjectMember.project_id == project_id, ProjectMember.user_id == user_id)
        .with_for_update()
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
    old_value = {
        "project_id": str(membership.project_id),
        "project_name": project.name,
        "position": previous_position,
        "is_active": membership.is_active,
        "left_at": membership.left_at.isoformat() if membership.left_at else None,
    }
    membership.is_active = False
    membership.left_at = date.today()
    db.flush()
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
    create_audit_log(
        db=db,
        action="retrait_projet",
        user_id=current_user.id,
        entity_type="user",
        entity_id=membership.user_id,
        old_value=old_value,
        new_value={
            "project_id": str(project.id),
            "project_name": project.name,
            "position": membership.position,
            "is_active": membership.is_active,
            "left_at": membership.left_at.isoformat()
            if membership.left_at
            else None,
        },
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(membership)

    return project_member_payload(membership, user)
