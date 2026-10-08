import secrets
from app.core.time import utc_now
from datetime import date, datetime
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, status, Request, UploadFile
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.models.stored_file import StoredFile
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
from app.core.roles import (
    ADMIN_MANAGED_ROLES,
    GLOBAL_MANAGEMENT_ROLES,
    SECRETARIAT_ROLES,
    ADMIN_ROLE,
    ALUMNI_ROLE,
    BASE_ACTIVE_ROLE,
    RESPONSIBILITY_ROLES,
    SCOPED_RESPONSIBILITY_ROLES,
    SECRETARY_MANAGED_ROLES,
    SECRETARY_ROLE,
    TEAM_LEADER_MANAGED_ROLES,
    TEAM_LEADER_ROLE,
    normalize_role_name,
    normalize_role_names,
)
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
from app.services.file_storage_service import delete_physical_file, infer_mime_type, store_bytes
from app.services.operational_integrity import (
    assert_active_operational_member,
    assert_can_make_alumni,
    assert_suspendable_lifecycle,
    lock_exclusive_role,
    lock_user,
    lock_role_write,
    reconcile_user_lifecycle,
)


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

PROFILE_PHOTO_MAX_BYTES = 8 * 1024 * 1024
PROFILE_PHOTO_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}

def lock_account_management(db: Session, actor_id, target_id=None, *, reviewer=False, allowed_roles=None):
    actor, target = lock_role_write(db, actor_id, target_id if target_id is not None else actor_id)
    authorized = (can_review_join_requests(db, actor) if reviewer
                  else bool(get_user_role_names(db, actor.id).intersection(allowed_roles)))
    if not authorized:
        raise HTTPException(403, "Action réservée aux responsables habilités.")
    return actor, target


def get_managed_role_names(db: Session, current_user: User) -> set[str]:
    roles = get_user_role_names(db, current_user.id)

    if ADMIN_ROLE in roles:
        return ADMIN_MANAGED_ROLES

    if TEAM_LEADER_ROLE in roles:
        return TEAM_LEADER_MANAGED_ROLES

    if SECRETARY_ROLE in roles:
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


def ensure_admin_removal_allowed(db: Session, user_id) -> None:
    # Serialize both role-editing paths on the same role row.
    role = lock_exclusive_role(db, ADMIN_ROLE)
    admin_links = (
        db.query(UserRole)
        .join(User, User.id == UserRole.user_id)
        .filter(UserRole.role_id == role.id, User.status == "active",
                User.is_active.is_(True), User.email_verified.is_(True),
                User.profile_type.in_({"enacteur", "enactrice"}))
        .with_for_update(of=UserRole)
        .all()
    )
    if any(link.user_id == user_id for link in admin_links) and len(admin_links) <= 1:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Le dernier administrateur ne peut pas être retiré",
        )


def normalize_lifecycle_roles(db: Session, user: User, role_names: set[str]) -> set[str]:
    role_names = normalize_role_names(role_names)

    if user.status == ALUMNI_ROLE:
        return role_names

    if user.status in {"active", "pending", "inactive"}:
        role_names.add(BASE_ACTIVE_ROLE)

    if role_names.intersection(RESPONSIBILITY_ROLES):
        role_names.add(BASE_ACTIVE_ROLE)

    return role_names


def get_user_or_404(db: Session, user_id: str) -> User:
    try:
        parsed_id = UUID(str(user_id))
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    user = db.query(User).filter(User.id == parsed_id).first()

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
    from app.api.deps import can_access_recruitment
    data["can_access_recruitment"] = can_access_recruitment(db, user)
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
        username=user.username,
        phone=user.phone,
        photo_url=user.photo_url,
        gender=user.gender,
        profile_type=user.profile_type,
        department=user.department,
        cursus=user.cursus,
        study_level=user.study_level,
        specialty=user.specialty,
        promotion=user.promotion,
        enactus_join_year=user.enactus_join_year,
        bio=user.bio,
        core_pole_id=pole_member.pole_id if pole_member else None,
        pole_position=pole_member.position if pole_member else None,
        status=user.status,
        roles=sorted(get_user_role_names(db, user.id)),
        created_at=user.created_at,
    )


@router.post("/", response_model=UserRead)
def create_user(
    payload: UserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    current_user, _ = lock_account_management(db, current_user.id, allowed_roles=SECRETARIAT_ROLES)
    normalized_email = payload.email.strip().lower()
    existing = db.query(User).filter(func.lower(User.email) == normalized_email).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un compte existe déjà avec cet email",
        )
    if payload.password is not None and len(payload.password.strip()) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mot de passe doit contenir au moins 8 caractères",
        )
    if payload.profile_type not in {BASE_ACTIVE_ROLE, 'enactrice', ALUMNI_ROLE}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de profil invalide",
        )

    user = User(
        first_name=payload.first_name,
        last_name=payload.last_name,
        email=normalized_email,
        username=payload.username,
        enactus_join_year=payload.enactus_join_year,
        cursus=payload.cursus,
        specialty=payload.specialty,
        phone=payload.phone,
        gender=payload.gender,
        profile_type=payload.profile_type,
        password_hash=hash_password(secrets.token_urlsafe(32)),
        credential_setup_required=True,
        onboarding_required=True,
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
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un compte existe déjà avec cet email ou ce nom d'utilisateur",
        ) from exc
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
    current_user = lock_user(db, current_user.id)
    if not current_user.is_active or current_user.status not in {"active", "alumni"} or not current_user.email_verified:
        raise HTTPException(403, "Compte indisponible.")
    fields = [
        "first_name",
        "last_name",
        "phone",
        "photo_url",
        "department",
        "cursus",
        "study_level",
        "specialty",
        "promotion",
        "enactus_join_year",
        "bio",
        "linkedin_url",
        "github_url",
        "portfolio_url",
    ]

    for field in fields:
        value = getattr(payload, field)
        if value is not None:
            setattr(current_user, field, value)

    if payload.enactus_join_year is not None:
        from app.services.alumni_profiles import sync_alumni_join_year
        sync_alumni_join_year(db, current_user)
    current_user.updated_at = utc_now()

    db.commit()
    db.refresh(current_user)

    return current_user


@router.post("/me/photo", response_model=UserRead)
async def upload_my_profile_photo(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    data = await file.read(PROFILE_PHOTO_MAX_BYTES + 1)
    mime_type = infer_mime_type(
        file.filename or "photo-profil.jpg",
        file.content_type,
    ).lower()
    if mime_type not in PROFILE_PHOTO_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Format de photo non pris en charge. Utilisez JPEG, PNG ou WebP.",
        )
    if not data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La photo est vide.",
        )
    if len(data) > PROFILE_PHOTO_MAX_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="La photo de profil ne doit pas dépasser 8 Mo.",
        )

    previous_files = (
        db.query(StoredFile)
        .filter(
            StoredFile.entity_type == "profile_photo",
            StoredFile.entity_id == current_user.id,
        )
        .all()
    )
    stored_file = store_bytes(
        db,
        data=data,
        original_filename=file.filename or "photo-profil.jpg",
        uploaded_by=current_user,
        mime_type=mime_type,
        storage_scope="profile",
        visibility="public_club",
        entity_type="profile_photo",
        entity_id=current_user.id,
        is_temporary=False,
    )
    current_user.photo_url = f"/api/files/{stored_file.id}/profile-photo"
    current_user.updated_at = utc_now()
    for old_file in previous_files:
        db.delete(old_file)

    db.commit()
    db.refresh(current_user)
    for old_file in previous_files:
        delete_physical_file(old_file)
    return current_user


@router.delete("/me/photo", response_model=UserRead)
def delete_my_profile_photo(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    previous_files = (
        db.query(StoredFile)
        .filter(
            StoredFile.entity_type == "profile_photo",
            StoredFile.entity_id == current_user.id,
        )
        .all()
    )
    current_user.photo_url = None
    current_user.updated_at = utc_now()
    for old_file in previous_files:
        db.delete(old_file)

    db.commit()
    db.refresh(current_user)
    for old_file in previous_files:
        delete_physical_file(old_file)
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
            User.status.in_(("active", ALUMNI_ROLE)),
        )
        .order_by(func.lower(User.last_name).asc(), func.lower(User.first_name).asc(), User.id.asc())
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
    current_user, user = lock_account_management(db, current_user.id, user_id, allowed_roles=SECRETARIAT_ROLES)

    forbidden_lifecycle_fields = {"status", "is_active"}.intersection(
        payload.model_fields_set
    )
    if forbidden_lifecycle_fields:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Le cycle de vie se modifie uniquement avec les actions "
                "d'approbation, rejet, suspension, réactivation ou Alumni"
            ),
        )

    old_value = {
        "status": user.status,
        "email_verified": user.email_verified,
        "is_active": user.is_active,
        "department": user.department,
        "study_level": user.study_level,
        "promotion": user.promotion,
    }

    if payload.email_verified is False and user.email_verified and ADMIN_ROLE in get_user_role_names(db, user.id):
        ensure_admin_removal_allowed(db, user.id)
    if payload.email_verified is not None:
        user.email_verified = payload.email_verified

    if payload.department is not None:
        user.department = payload.department

    if payload.study_level is not None:
        user.study_level = payload.study_level

    if payload.promotion is not None:
        user.promotion = payload.promotion
    if payload.enactus_join_year is not None:
        user.enactus_join_year = payload.enactus_join_year
        from app.services.alumni_profiles import sync_alumni_join_year
        sync_alumni_join_year(db, user)

    user.updated_at = utc_now()

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

    if (
        payload.department is not None
        and payload.department != old_value["department"]
    ):
        create_audit_log(
            db=db,
            action="changement_pole_coeur",
            user_id=current_user.id,
            entity_type="user",
            entity_id=user.id,
            old_value={"department": old_value["department"]},
            new_value={"department": user.department},
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
    current_user, user = lock_account_management(db, current_user.id, user_id, reviewer=True)
    if user.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Seul un compte en attente peut être approuvé",
        )

    old_value = {
        "status": user.status,
        "email_verified": user.email_verified,
    }

    is_alumni = user.profile_type == ALUMNI_ROLE
    reconcile_user_lifecycle(db, user, ALUMNI_ROLE if is_alumni else "active")
    user.email_verified = True
    if user.credential_setup_required:
        from app.services.first_access import issue_activation
        issue_activation(db, user)

    notification_title = (
        "Compte Alumni EnactSpace validé"
        if is_alumni
        else "Compte EnactSpace validé"
    )
    notification_message = (
        "Votre compte Alumni est validé. Vous pouvez accéder à l'espace Alumni."
        if is_alumni
        else "Votre compte est validé. Vous pouvez maintenant vous connecter."
    )

    notify_user(
        db,
        user_id=user.id,
        title=notification_title,
        message=notification_message,
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
    current_user, user = lock_account_management(db, current_user.id, user_id, reviewer=True)
    if user.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Seul un compte en attente peut être rejeté",
        )

    old_value = {
        "status": user.status,
    }

    reconcile_user_lifecycle(db, user, "rejected")

    is_alumni = user.profile_type == ALUMNI_ROLE
    notify_user(
        db,
        user_id=user.id,
        title=(
            "Demande Alumni non validée"
            if is_alumni
            else "Demande de compte non validée"
        ),
        message=(
            "Votre demande de compte Alumni EnactSpace n’a pas été validée."
            if is_alumni
            else "Votre demande EnactSpace n’a pas été validée."
        ),
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
    current_user, user = lock_account_management(db, current_user.id, user_id, allowed_roles=GLOBAL_MANAGEMENT_ROLES)
    current_roles = get_user_role_names(db, current_user.id)
    target_roles = get_user_role_names(db, user.id)

    if user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas suspendre votre propre compte",
        )
    if ADMIN_ROLE in target_roles and ADMIN_ROLE not in current_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seul un administrateur peut suspendre un administrateur",
        )
    if user.status == "suspended":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce compte est déjà suspendu",
        )
    assert_suspendable_lifecycle(user)

    old_value = {
        "status": user.status,
        "is_active": user.is_active,
    }

    reconcile_user_lifecycle(db, user, "suspended")

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
    current_user, user = lock_account_management(db, current_user.id, user_id, allowed_roles=GLOBAL_MANAGEMENT_ROLES)
    if user.status not in {"suspended", "inactive"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Seul un compte suspendu ou inactif peut être réactivé",
        )

    old_value = {"status": user.status, "is_active": user.is_active}
    lifecycle = ALUMNI_ROLE if user.profile_type == ALUMNI_ROLE else "active"
    reconcile_user_lifecycle(db, user, lifecycle)

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


@router.get("/{user_id}/alumni-transition")
def preview_alumni_transition(user_id: str, db:Session=Depends(get_db), current_user:User=Depends(require_admin_or_team_leader)):
    current_user,user=lock_account_management(db,current_user.id,user_id,allowed_roles=GLOBAL_MANAGEMENT_ROLES)
    from app.models.task import Task,TaskAssignee
    from app.models.pole import PoleMember,Pole
    from app.models.project import ProjectMember,Project
    roles=sorted(get_user_role_names(db,user.id))
    poles=[{"name":p.name,"position":m.position} for m,p in db.query(PoleMember,Pole).join(Pole,Pole.id==PoleMember.pole_id).filter(PoleMember.user_id==user.id,PoleMember.is_active.is_(True),PoleMember.left_at.is_(None)).all()]
    projects=[{"name":p.name,"position":m.position} for m,p in db.query(ProjectMember,Project).join(Project,Project.id==ProjectMember.project_id).filter(ProjectMember.user_id==user.id,ProjectMember.is_active.is_(True),ProjectMember.left_at.is_(None)).all()]
    tasks=[{"id":str(t.id),"title":t.title,"status":t.status} for t in db.query(Task).join(TaskAssignee,TaskAssignee.task_id==Task.id).filter(TaskAssignee.user_id==user.id,Task.status.notin_({"valide","annule"})).all()]
    return {"member_id":str(user.id),"status":user.status,"roles":roles,"poles":poles,"projects":projects,"pending_tasks":tasks,
        "can_convert":user.status=="active" and user.is_active and user.profile_type in {"enacteur","enactrice"} and user.id!=current_user.id and "administrateur" not in roles,
        "message":"Le compte et l’historique sont conservés. Les responsabilités et affectations actives dans les pôles et projets sont clôturées. Les tâches ouvertes restent à transmettre ; elles ne sont ni supprimées ni validées automatiquement."}


@router.post("/{user_id}/make-alumni", response_model=UserRead)
def make_user_alumni(
    user_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    current_user, user = lock_account_management(db, current_user.id, user_id, allowed_roles=GLOBAL_MANAGEMENT_ROLES)
    target_roles = get_user_role_names(db, user.id)

    if user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous ne pouvez pas modifier votre propre cycle de membre",
        )
    if user.status == ALUMNI_ROLE:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce membre est déjà Alumni",
        )
    if ADMIN_ROLE in target_roles:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Retirez d'abord le rôle administrateur de ce membre",
        )
    assert_can_make_alumni(user)

    old_value = {
        "status": user.status,
    }

    reconcile_user_lifecycle(db, user, ALUMNI_ROLE)
    from app.models.task import Task, TaskAssignee
    for task in db.query(Task).join(TaskAssignee,TaskAssignee.task_id==Task.id).filter(TaskAssignee.user_id==user.id,Task.status.notin_({"valide","annule"})).all():
        recipient=task.assigned_by or task.creator_id
        if recipient and recipient!=user.id:
            notify_user(db,user_id=recipient,title="Une tâche à transmettre",message=f"{user.first_name} {user.last_name} rejoint les alumni. Organisez le relais pour : {task.title}.",notification_type="task_updated",related_type="task",related_id=task.id)

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
    current_user, user = lock_role_write(db, current_user.id, user_id)

    requested_role_names = normalize_role_names(payload.role_names)
    scoped_roles = requested_role_names.intersection(SCOPED_RESPONSIBILITY_ROLES)
    if scoped_roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Les responsabilités de pôle ou projet se gèrent depuis "
                "le module concerné"
            ),
        )
    assert_active_operational_member(user)
    managed_roles = ensure_role_authority(db, current_user, requested_role_names)
    current_role_names = get_user_role_names(db, user.id)
    old_roles = sorted(list(current_role_names))
    if ADMIN_ROLE in current_role_names and ADMIN_ROLE in managed_roles and ADMIN_ROLE not in requested_role_names:
        ensure_admin_removal_allowed(db, user.id)
        ensure_role_authority(db, current_user, requested_role_names)

    roles = db.query(Role).filter(Role.name.in_(requested_role_names)).all()
    found_role_names = {role.name for role in roles}
    missing_roles = requested_role_names - found_role_names

    if missing_roles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Rôles introuvables : {', '.join(sorted(missing_roles))}",
        )

    exclusive_roles = requested_role_names.intersection(
        {TEAM_LEADER_ROLE, SECRETARY_ROLE}
    )
    for exclusive_role_name in sorted(exclusive_roles):
        exclusive_role = lock_exclusive_role(db, exclusive_role_name)
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
            create_audit_log(
                db=db,
                action="remplacement_role_exclusif",
                user_id=current_user.id,
                entity_type="user",
                entity_id=previous_user_id,
                old_value={"role": exclusive_role_name},
                new_value={"role": None, "replacement_user_id": str(user.id)},
                ip_address=get_client_ip(request),
            )
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
        current_link_role_name = normalize_role_name(link.role.name)
        if (
            current_link_role_name in managed_roles
            and current_link_role_name not in next_role_names
        ):
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
    current_user, user = lock_role_write(db, current_user.id, user_id)
    role_name = normalize_role_name(role_name)
    ensure_role_authority(db, current_user, {role_name})

    old_roles = sorted(list(get_user_role_names(db, user.id)))

    role = db.query(Role).filter(Role.name == role_name).first()

    if not role:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Rôle introuvable",
        )

    if role_name == ADMIN_ROLE:
        ensure_admin_removal_allowed(db, user.id)
        ensure_role_authority(db, current_user, {role_name})

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
