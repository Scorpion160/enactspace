from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.models.role import Role, UserRole
from app.schemas.user import (
    UserCreate,
    UserRead,
    UserUpdate,
    UserAdminUpdate,
    UserDirectoryRead,
    UserRoleAssign,
    UserWithRolesRead,
)
from app.core.security import hash_password
from app.api.deps import (
    get_current_user,
    get_current_active_validated_user,
    require_admin_or_team_leader,
    require_join_request_reviewer,
    require_sg_or_admin,
    can_review_join_requests,
    get_user_role_names,
)
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.notification_service import notify_user


router = APIRouter(prefix="/users", tags=["Utilisateurs"])


VALID_USER_STATUSES = {
    "pending",
    "active",
    "inactive",
    "alumni",
    "candidate",
    "rejected",
    "suspended",
}


BASE_ACTIVE_ROLE = "enacteur"

RESPONSIBILITY_ROLES = {
    "team_leader",
    "secretaire_generale",
    "financier",
    "chef_pole",
    "adjoint_chef_pole",
    "chef_projet",
    "adjoint_chef_projet",
}

SCOPED_RESPONSIBILITY_ROLES = {
    "chef_pole",
    "adjoint_chef_pole",
    "chef_projet",
    "adjoint_chef_projet",
}

ADMIN_MANAGED_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
    "financier",
    "faculty_advisor",
    "enacteur",
}

TEAM_LEADER_MANAGED_ROLES = {
    "secretaire_generale",
    "financier",
    "faculty_advisor",
    "enacteur",
}

SECRETARY_MANAGED_ROLES = {
    "financier",
    "enacteur",
}


def get_managed_role_names(db: Session, current_user: User) -> set[str]:
    roles = get_user_role_names(db, current_user.id)

    if "administrateur" in roles:
        return ADMIN_MANAGED_ROLES

    if "team_leader" in roles:
        return TEAM_LEADER_MANAGED_ROLES

    if "secretaire_generale" in roles:
        return SECRETARY_MANAGED_ROLES

    return set()


def ensure_role_authority(
    db: Session,
    current_user: User,
    requested_roles: set[str],
) -> set[str]:
    managed_roles = get_managed_role_names(db, current_user)

    if not managed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission insuffisante pour gérer les responsabilités",
        )

    forbidden = requested_roles - managed_roles

    if forbidden:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Rôle(s) non autorisé(s) : {', '.join(sorted(forbidden))}",
        )

    return managed_roles


def normalize_lifecycle_roles(db: Session, user: User, role_names: set[str]) -> set[str]:
    if user.status == "alumni":
        return role_names

    if user.status in {"active", "pending", "inactive"}:
        role_names.add(BASE_ACTIVE_ROLE)

    if role_names.intersection(RESPONSIBILITY_ROLES):
        role_names.add(BASE_ACTIVE_ROLE)

    return role_names


def get_user_or_404(db: Session, user_id: str) -> User:
    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utilisateur introuvable",
        )

    return user


def build_user_with_roles(db: Session, user: User) -> UserWithRolesRead:
    data = UserRead.model_validate(user).model_dump()
    data["roles"] = sorted(list(get_user_role_names(db, user.id)))
    pole_member = (
        db.query(PoleMember)
        .filter(PoleMember.user_id == user.id, PoleMember.is_active.is_(True))
        .order_by(PoleMember.joined_at.desc())
        .first()
    )
    data["core_pole_id"] = pole_member.pole_id if pole_member else None
    data["pole_position"] = pole_member.position if pole_member else None
    data["can_review_join_requests"] = can_review_join_requests(db, user)
    return UserWithRolesRead(**data)


def build_directory_user(db: Session, user: User) -> UserDirectoryRead:
    pole_member = (
        db.query(PoleMember)
        .filter(PoleMember.user_id == user.id, PoleMember.is_active.is_(True))
        .order_by(PoleMember.joined_at.desc())
        .first()
    )
    return UserDirectoryRead(
        id=user.id,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        photo_url=user.photo_url,
        profile_type=user.profile_type,
        department=user.department,
        core_pole_id=pole_member.pole_id if pole_member else None,
        pole_position=pole_member.position if pole_member else None,
        status=user.status,
        roles=sorted(get_user_role_names(db, user.id)),
    )


@router.post("/", response_model=UserRead)
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    existing = db.query(User).filter(User.email == payload.email).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un compte existe déjà avec cet email",
        )
    if len(payload.password.strip()) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mot de passe doit contenir au moins 8 caractères",
        )
    if payload.profile_type not in {"enacteur", "alumni"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de profil invalide",
        )

    user = User(
        first_name=payload.first_name,
        last_name=payload.last_name,
        email=payload.email,
        phone=payload.phone,
        gender=payload.gender,
        profile_type=payload.profile_type,
        password_hash=hash_password(payload.password),
        department=payload.department,
        study_level=payload.study_level,
        promotion=payload.promotion,
        bio=payload.bio,
        linkedin_url=payload.linkedin_url,
        github_url=payload.github_url,
        portfolio_url=payload.portfolio_url,
        status="pending",
        email_verified=False,
        is_active=True,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


@router.get("/me", response_model=UserWithRolesRead)
def read_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return build_user_with_roles(db, current_user)


@router.patch("/me", response_model=UserRead)
def update_me(
    payload: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    fields = [
        "first_name",
        "last_name",
        "phone",
        "photo_url",
        "department",
        "study_level",
        "promotion",
        "bio",
        "linkedin_url",
        "github_url",
        "portfolio_url",
    ]

    for field in fields:
        value = getattr(payload, field)
        if value is not None:
            setattr(current_user, field, value)

    current_user.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(current_user)

    return current_user


@router.get("/", response_model=list[UserWithRolesRead])
def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    users = db.query(User).order_by(User.created_at.desc()).all()
    return [build_user_with_roles(db, user) for user in users]


@router.get("/directory", response_model=list[UserDirectoryRead])
def list_user_directory(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    users = (
        db.query(User)
        .filter(
            User.is_active.is_(True),
            User.status.in_(("active", "alumni")),
        )
        .order_by(User.first_name.asc(), User.last_name.asc())
        .all()
    )
    return [build_directory_user(db, user) for user in users]


@router.get("/pending", response_model=list[UserWithRolesRead])
def list_pending_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_join_request_reviewer),
):
    users = db.query(User).filter(
        User.status == "pending"
    ).order_by(User.created_at.desc()).all()

    return [build_user_with_roles(db, user) for user in users]


@router.get("/{user_id}", response_model=UserWithRolesRead)
def get_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    user = get_user_or_404(db, user_id)
    return build_user_with_roles(db, user)


@router.patch("/{user_id}/admin", response_model=UserRead)
def admin_update_user(
    user_id: str,
    payload: UserAdminUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    user = get_user_or_404(db, user_id)

    old_value = {
        "status": user.status,
        "email_verified": user.email_verified,
        "is_active": user.is_active,
        "department": user.department,
        "study_level": user.study_level,
        "promotion": user.promotion,
    }

    if payload.status is not None:
        if payload.status not in VALID_USER_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Statut utilisateur invalide",
            )
        user.status = payload.status

    if payload.email_verified is not None:
        user.email_verified = payload.email_verified

    if payload.is_active is not None:
        user.is_active = payload.is_active

    if payload.department is not None:
        user.department = payload.department

    if payload.study_level is not None:
        user.study_level = payload.study_level

    if payload.promotion is not None:
        user.promotion = payload.promotion

    user.updated_at = datetime.utcnow()

    create_audit_log(
        db=db,
        action="modification_admin_utilisateur",
        user_id=current_user.id,
        entity_type="user",
        entity_id=user.id,
        old_value=old_value,
        new_value={
            "status": user.status,
            "email_verified": user.email_verified,
            "is_active": user.is_active,
            "department": user.department,
            "study_level": user.study_level,
            "promotion": user.promotion,
        },
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(user)

    return user


@router.post("/{user_id}/approve", response_model=UserRead)
def approve_user(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_join_request_reviewer),
):
    user = get_user_or_404(db, user_id)
    if user.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Seul un compte en attente peut être approuvé",
        )

    old_value = {
        "status": user.status,
        "email_verified": user.email_verified,
    }

    is_alumni = user.profile_type == "alumni"
    user.status = "alumni" if is_alumni else "active"
    user.email_verified = True
    user.is_active = True
    user.updated_at = datetime.utcnow()

    role_name = "alumni" if is_alumni else BASE_ACTIVE_ROLE
    role = db.query(Role).filter(Role.name == role_name).first()
    if not role:
        role = Role(name=role_name, description=f"Rôle de base {role_name}")
        db.add(role)
        db.flush()

    existing_role = db.query(UserRole).filter(
        UserRole.user_id == user.id,
        UserRole.role_id == role.id,
    ).first()
    if not existing_role:
        db.add(UserRole(user_id=user.id, role_id=role.id))

    notify_user(
        db,
        user_id=user.id,
        title="Compte EnactSpace validé",
        message="Votre compte est validé. Vous pouvez maintenant vous connecter.",
        notification_type="account_approved",
        related_type="user",
        related_id=user.id,
    )

    create_audit_log(
        db=db,
        action="validation_compte",
        user_id=current_user.id,
        entity_type="user",
        entity_id=user.id,
        old_value=old_value,
        new_value={
            "status": user.status,
            "email_verified": user.email_verified,
            "is_active": user.is_active,
        },
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(user)

    return user


@router.post("/{user_id}/reject", response_model=UserRead)
def reject_user(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_join_request_reviewer),
):
    user = get_user_or_404(db, user_id)
    if user.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Seul un compte en attente peut être rejeté",
        )

    old_value = {
        "status": user.status,
    }

    user.status = "rejected"
    user.updated_at = datetime.utcnow()

    notify_user(
        db,
        user_id=user.id,
        title="Demande de compte non validée",
        message="Votre demande EnactSpace n’a pas été validée.",
        notification_type="account_rejected",
        related_type="user",
        related_id=user.id,
    )

    create_audit_log(
        db=db,
        action="rejet_compte",
        user_id=current_user.id,
        entity_type="user",
        entity_id=user.id,
        old_value=old_value,
        new_value={"status": user.status},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(user)

    return user


@router.post("/{user_id}/suspend", response_model=UserRead)
def suspend_user(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    user = get_user_or_404(db, user_id)
    current_roles = get_user_role_names(db, current_user.id)
    target_roles = get_user_role_names(db, user.id)

    if user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas suspendre votre propre compte",
        )
    if "administrateur" in target_roles and "administrateur" not in current_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seul un administrateur peut suspendre un administrateur",
        )
    if user.status == "suspended":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce compte est déjà suspendu",
        )

    old_value = {
        "status": user.status,
        "is_active": user.is_active,
    }

    user.status = "suspended"
    user.is_active = False
    user.updated_at = datetime.utcnow()

    create_audit_log(
        db=db,
        action="suspension_compte",
        user_id=current_user.id,
        entity_type="user",
        entity_id=user.id,
        old_value=old_value,
        new_value={
            "status": user.status,
            "is_active": user.is_active,
        },
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(user)

    return user


@router.post("/{user_id}/reactivate", response_model=UserRead)
def reactivate_user(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    user = get_user_or_404(db, user_id)
    if user.status not in {"suspended", "inactive"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Seul un compte suspendu ou inactif peut être réactivé",
        )

    old_value = {"status": user.status, "is_active": user.is_active}
    role_name = "alumni" if user.profile_type == "alumni" else BASE_ACTIVE_ROLE
    role = db.query(Role).filter(Role.name == role_name).first()
    if role is None:
        role = Role(name=role_name, description=f"Rôle de base {role_name}")
        db.add(role)
        db.flush()

    user.status = "alumni" if user.profile_type == "alumni" else "active"
    user.is_active = True
    user.updated_at = datetime.utcnow()

    assignment = db.query(UserRole).filter(
        UserRole.user_id == user.id,
        UserRole.role_id == role.id,
    ).first()
    if assignment is None:
        db.add(UserRole(user_id=user.id, role_id=role.id))

    notify_user(
        db,
        user_id=user.id,
        title="Compte réactivé",
        message="Votre accès EnactSpace est de nouveau actif.",
        notification_type="account_approved",
        related_type="user",
        related_id=user.id,
    )
    create_audit_log(
        db=db,
        action="reactivation_compte",
        user_id=current_user.id,
        entity_type="user",
        entity_id=user.id,
        old_value=old_value,
        new_value={"status": user.status, "is_active": user.is_active},
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(user)
    return user


@router.post("/{user_id}/make-alumni", response_model=UserRead)
def make_user_alumni(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    user = get_user_or_404(db, user_id)
    target_roles = get_user_role_names(db, user.id)

    if user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas modifier votre propre cycle de membre",
        )
    if user.status == "alumni":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce membre est déjà Alumni",
        )
    if "administrateur" in target_roles:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Retirez d'abord le rôle administrateur de ce membre",
        )

    old_value = {
        "status": user.status,
    }

    user.status = "alumni"
    user.profile_type = "alumni"
    user.updated_at = datetime.utcnow()

    alumni_role = db.query(Role).filter(Role.name == "alumni").first()
    if not alumni_role:
        alumni_role = Role(name="alumni", description="Ancien membre Enactus")
        db.add(alumni_role)
        db.flush()

    current_links = db.query(UserRole).filter(UserRole.user_id == user.id).all()
    for link in current_links:
        if link.role and (
            link.role.name == BASE_ACTIVE_ROLE
            or link.role.name in RESPONSIBILITY_ROLES
        ):
            db.delete(link)

    has_alumni_role = any(
        link.role_id == alumni_role.id for link in current_links
    )
    if not has_alumni_role:
        db.add(UserRole(user_id=user.id, role_id=alumni_role.id))

    for membership in db.query(PoleMember).filter(
        PoleMember.user_id == user.id,
        PoleMember.is_active.is_(True),
    ).all():
        membership.is_active = False
        membership.left_at = date.today()

    for membership in db.query(ProjectMember).filter(
        ProjectMember.user_id == user.id,
        ProjectMember.is_active.is_(True),
    ).all():
        membership.is_active = False
        membership.left_at = date.today()

    notify_user(
        db,
        user_id=user.id,
        title="Passage au statut Alumni",
        message="Votre espace EnactSpace est désormais adapté au parcours Alumni.",
        notification_type="role_assigned",
        related_type="user",
        related_id=user.id,
    )

    create_audit_log(
        db=db,
        action="passage_alumni",
        user_id=current_user.id,
        entity_type="user",
        entity_id=user.id,
        old_value=old_value,
        new_value={"status": user.status},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(user)

    return user


@router.post("/{user_id}/roles", response_model=UserWithRolesRead)
def assign_roles_to_user(
    user_id: str,
    payload: UserRoleAssign,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    user = get_user_or_404(db, user_id)

    requested_role_names = set(payload.role_names)
    scoped_roles = requested_role_names.intersection(SCOPED_RESPONSIBILITY_ROLES)
    if scoped_roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Les responsabilités de pôle ou projet se gèrent depuis "
                "le module concerné"
            ),
        )
    if user.status != "active" or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Les responsabilités sont réservées aux membres actifs",
        )
    managed_roles = ensure_role_authority(db, current_user, requested_role_names)
    current_role_names = get_user_role_names(db, user.id)
    old_roles = sorted(list(current_role_names))

    roles = db.query(Role).filter(Role.name.in_(requested_role_names)).all()
    found_role_names = {role.name for role in roles}
    missing_roles = requested_role_names - found_role_names

    if missing_roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Rôles introuvables : {', '.join(sorted(missing_roles))}",
        )

    exclusive_roles = requested_role_names.intersection(
        {"team_leader", "secretaire_generale"}
    )
    for exclusive_role_name in exclusive_roles:
        exclusive_role = next(
            role for role in roles if role.name == exclusive_role_name
        )
        previous_links = (
            db.query(UserRole)
            .filter(
                UserRole.role_id == exclusive_role.id,
                UserRole.user_id != user.id,
            )
            .all()
        )
        for previous_link in previous_links:
            previous_user_id = previous_link.user_id
            db.delete(previous_link)
            notify_user(
                db,
                user_id=previous_user_id,
                title="Fin de responsabilité",
                message=(
                    f"Votre mandat {exclusive_role_name} est terminé. "
                    "Votre accès Enacteur reste actif."
                ),
                notification_type="role_assigned",
                related_type="user",
                related_id=previous_user_id,
            )

    next_role_names = (current_role_names - managed_roles) | requested_role_names
    next_role_names = normalize_lifecycle_roles(db, user, next_role_names)

    next_roles = db.query(Role).filter(Role.name.in_(next_role_names)).all()
    next_roles_by_name = {role.name: role for role in next_roles}
    missing_next_roles = next_role_names - set(next_roles_by_name.keys())

    if missing_next_roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Rôles introuvables : {', '.join(sorted(missing_next_roles))}",
        )

    existing_links = (
        db.query(UserRole)
        .join(Role, UserRole.role_id == Role.id)
        .filter(UserRole.user_id == user.id)
        .all()
    )

    for link in existing_links:
        if link.role.name in managed_roles and link.role.name not in next_role_names:
            db.delete(link)

    for role_name in next_role_names:
        role = next_roles_by_name[role_name]
        existing = db.query(UserRole).filter(
            UserRole.user_id == user.id,
            UserRole.role_id == role.id,
        ).first()

        if existing:
            continue

        db.add(UserRole(user_id=user.id, role_id=role.id))

    db.flush()

    new_roles = sorted(list(get_user_role_names(db, user.id)))

    if new_roles != old_roles:
        notify_user(
            db,
            user_id=user.id,
            title="Responsabilités mises à jour",
            message="Vos rôles EnactSpace ont été mis à jour.",
            notification_type="role_assigned",
            related_type="user",
            related_id=user.id,
        )

    create_audit_log(
        db=db,
        action="synchronisation_roles_utilisateur",
        user_id=current_user.id,
        entity_type="user",
        entity_id=user.id,
        old_value={"roles": old_roles},
        new_value={"roles": new_roles},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(user)

    return build_user_with_roles(db, user)


@router.delete("/{user_id}/roles/{role_name}", response_model=UserWithRolesRead)
def remove_role_from_user(
    user_id: str,
    role_name: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    user = get_user_or_404(db, user_id)
    ensure_role_authority(db, current_user, {role_name})

    old_roles = sorted(list(get_user_role_names(db, user.id)))

    role = db.query(Role).filter(Role.name == role_name).first()

    if not role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Rôle introuvable",
        )

    link = db.query(UserRole).filter(
        UserRole.user_id == user.id,
        UserRole.role_id == role.id,
    ).first()

    if link:
        db.delete(link)

    db.flush()

    normalized_roles = normalize_lifecycle_roles(db, user, get_user_role_names(db, user.id))
    missing_roles = normalized_roles - get_user_role_names(db, user.id)

    if missing_roles:
        roles = db.query(Role).filter(Role.name.in_(missing_roles)).all()
        for role in roles:
            db.add(UserRole(user_id=user.id, role_id=role.id))

        db.flush()

    new_roles = sorted(list(get_user_role_names(db, user.id)))

    create_audit_log(
        db=db,
        action="suppression_role_utilisateur",
        user_id=current_user.id,
        entity_type="user",
        entity_id=user.id,
        old_value={"roles": old_roles},
        new_value={"roles": new_roles},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(user)

    return build_user_with_roles(db, user)
