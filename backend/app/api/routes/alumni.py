from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from app.db.database import get_db
from app.models.alumni import AlumniProfile, Mentorship
from app.models.user import User
from app.core.roles import ENACCHEF_ROLES, SECRETARIAT_ROLES
from app.schemas.alumni import (
    AlumniProfileCreate,
    AlumniProfileUpdate,
    AlumniProfileRead,
    MentorshipCreate,
    MentorshipUpdate,
    MentorshipRead,
)
from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
    require_enacchef_or_admin,
)


router = APIRouter(prefix="/alumni", tags=["Alumni & Mentorat"])


VALID_ALUMNI_VISIBILITIES = {
    "internal",
    "alumni_only",
    "enacchef_only",
    "private",
}

VALID_MENTORSHIP_STATUSES = {
    "active",
    "paused",
    "completed",
    "cancelled",
}

ALUMNI_MANAGER_ROLES = SECRETARIAT_ROLES
ALUMNI_ENACCHEF_ROLES = ENACCHEF_ROLES


def can_manage_alumni(db: Session, user: User) -> bool:
    return bool(get_user_role_names(db, user.id).intersection(ALUMNI_MANAGER_ROLES))


def can_view_profile(db: Session, user: User, profile: AlumniProfile) -> bool:
    if profile.user_id == user.id or can_manage_alumni(db, user):
        return True
    if profile.visibility == "private":
        return False
    if profile.visibility == "enacchef_only":
        return bool(
            get_user_role_names(db, user.id).intersection(ALUMNI_ENACCHEF_ROLES)
        )
    if profile.visibility == "alumni_only":
        return user.status == "alumni"
    return True


def ensure_profile_access(
    db: Session,
    user: User,
    profile: AlumniProfile,
    *,
    manage: bool = False,
) -> None:
    allowed = (
        profile.user_id == user.id or can_manage_alumni(db, user)
        if manage
        else can_view_profile(db, user, profile)
    )
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès non autorisé à ce profil alumni",
        )


def get_alumni_profile_or_404(db: Session, profile_id: str) -> AlumniProfile:
    profile = db.query(AlumniProfile).filter(
        AlumniProfile.id == profile_id
    ).first()

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profil alumni introuvable",
        )

    return profile


def get_mentorship_or_404(db: Session, mentorship_id: str) -> Mentorship:
    mentorship = db.query(Mentorship).filter(
        Mentorship.id == mentorship_id
    ).first()

    if not mentorship:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Mentorat introuvable",
        )

    return mentorship


@router.post("/profiles", response_model=AlumniProfileRead)
def create_alumni_profile(
    payload: AlumniProfileCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if payload.visibility not in VALID_ALUMNI_VISIBILITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Visibilité invalide",
        )

    if str(current_user.id) != str(payload.user_id) and not can_manage_alumni(
        db, current_user
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez créer que votre propre profil alumni",
        )

    target_user = db.query(User).filter(User.id == payload.user_id).first()
    if not target_user or target_user.status != "alumni":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le profil doit être rattaché à un compte Alumni validé",
        )

    existing = db.query(AlumniProfile).filter(
        AlumniProfile.user_id == payload.user_id
    ).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cet utilisateur possède déjà un profil alumni",
        )

    profile = AlumniProfile(
        user_id=payload.user_id,
        graduation_year=payload.graduation_year,
        current_company=payload.current_company,
        current_position=payload.current_position,
        domain=payload.domain,
        skills=payload.skills,
        experience_summary=payload.experience_summary,
        available_for_mentoring=payload.available_for_mentoring,
        linkedin_url=payload.linkedin_url,
        portfolio_url=payload.portfolio_url,
        visibility=payload.visibility,
    )

    db.add(profile)
    db.commit()
    db.refresh(profile)

    return profile


@router.get("/profiles", response_model=list[AlumniProfileRead])
def list_alumni_profiles(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    search: str | None = Query(default=None),
    domain: str | None = Query(default=None),
    graduation_year: int | None = Query(default=None),
    available_for_mentoring: bool | None = Query(default=None),
):
    query = (
        db.query(AlumniProfile)
        .join(User, User.id == AlumniProfile.user_id)
        .options(joinedload(AlumniProfile.user))
    )

    if not can_manage_alumni(db, current_user):
        visible = ["internal"]
        if current_user.status == "alumni":
            visible.append("alumni_only")
        if get_user_role_names(db, current_user.id).intersection(
            ALUMNI_ENACCHEF_ROLES
        ):
            visible.append("enacchef_only")
        query = query.filter(
            or_(
                AlumniProfile.user_id == current_user.id,
                AlumniProfile.visibility.in_(visible),
            )
        )

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (AlumniProfile.current_company.ilike(pattern)) |
            (AlumniProfile.current_position.ilike(pattern)) |
            (AlumniProfile.domain.ilike(pattern)) |
            (AlumniProfile.skills.ilike(pattern)) |
            (AlumniProfile.experience_summary.ilike(pattern)) |
            (User.first_name.ilike(pattern)) |
            (User.last_name.ilike(pattern))
        )

    if domain:
        query = query.filter(AlumniProfile.domain.ilike(f"%{domain}%"))

    if graduation_year:
        query = query.filter(AlumniProfile.graduation_year == graduation_year)

    if available_for_mentoring is not None:
        query = query.filter(
            AlumniProfile.available_for_mentoring == available_for_mentoring
        )

    return query.order_by(
        AlumniProfile.graduation_year.desc().nullslast(),
        AlumniProfile.created_at.desc(),
    ).all()


@router.get("/profiles/user/{user_id}", response_model=AlumniProfileRead)
def get_alumni_profile_by_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    profile = (
        db.query(AlumniProfile)
        .options(joinedload(AlumniProfile.user))
        .filter(AlumniProfile.user_id == user_id)
        .first()
    )

    if not profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profil alumni introuvable pour cet utilisateur",
        )

    ensure_profile_access(db, current_user, profile)
    return profile


@router.get("/profiles/{profile_id}", response_model=AlumniProfileRead)
def get_alumni_profile(
    profile_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    profile = get_alumni_profile_or_404(db, profile_id)
    ensure_profile_access(db, current_user, profile)
    return profile


@router.patch("/profiles/{profile_id}", response_model=AlumniProfileRead)
def update_alumni_profile(
    profile_id: str,
    payload: AlumniProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    profile = get_alumni_profile_or_404(db, profile_id)
    ensure_profile_access(db, current_user, profile, manage=True)

    if payload.visibility is not None:
        if payload.visibility not in VALID_ALUMNI_VISIBILITIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Visibilité invalide",
            )
        profile.visibility = payload.visibility

    fields = [
        "graduation_year",
        "current_company",
        "current_position",
        "domain",
        "skills",
        "experience_summary",
        "available_for_mentoring",
        "linkedin_url",
        "portfolio_url",
    ]

    for field in fields:
        value = getattr(payload, field)
        if value is not None:
            setattr(profile, field, value)

    profile.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(profile)

    return profile


@router.delete("/profiles/{profile_id}")
def delete_alumni_profile(
    profile_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    profile = get_alumni_profile_or_404(db, profile_id)
    ensure_profile_access(db, current_user, profile, manage=True)

    db.delete(profile)
    db.commit()

    return {
        "ok": True,
        "message": "Profil alumni supprimé",
    }


@router.post("/mentorships", response_model=MentorshipRead)
def create_mentorship(
    payload: MentorshipCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    if payload.status not in VALID_MENTORSHIP_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de mentorat invalide",
        )

    if not payload.project_id and not payload.pole_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mentorat doit être lié à un projet ou à un pôle",
        )

    alumni_profile = db.query(AlumniProfile).filter(
        AlumniProfile.user_id == payload.alumni_id
    ).first()
    if not alumni_profile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mentor doit posséder un profil Alumni validé",
        )

    mentorship = Mentorship(
        alumni_id=payload.alumni_id,
        project_id=payload.project_id,
        pole_id=payload.pole_id,
        assigned_by=current_user.id,
        title=payload.title,
        objective=payload.objective,
        status=payload.status,
        started_at=payload.started_at or date.today(),
        ended_at=payload.ended_at,
    )

    db.add(mentorship)
    db.commit()
    db.refresh(mentorship)

    return mentorship


@router.get("/mentorships", response_model=list[MentorshipRead])
def list_mentorships(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    alumni_id: str | None = Query(default=None),
    project_id: str | None = Query(default=None),
    pole_id: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
):
    query = db.query(Mentorship)

    if alumni_id:
        query = query.filter(Mentorship.alumni_id == alumni_id)

    if project_id:
        query = query.filter(Mentorship.project_id == project_id)

    if pole_id:
        query = query.filter(Mentorship.pole_id == pole_id)

    if status_filter:
        query = query.filter(Mentorship.status == status_filter)

    return query.order_by(Mentorship.created_at.desc()).all()


@router.get("/mentorships/{mentorship_id}", response_model=MentorshipRead)
def get_mentorship(
    mentorship_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return get_mentorship_or_404(db, mentorship_id)


@router.patch("/mentorships/{mentorship_id}", response_model=MentorshipRead)
def update_mentorship(
    mentorship_id: str,
    payload: MentorshipUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    mentorship = get_mentorship_or_404(db, mentorship_id)

    if payload.status is not None:
        if payload.status not in VALID_MENTORSHIP_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Statut de mentorat invalide",
            )
        mentorship.status = payload.status

    if payload.project_id is not None:
        mentorship.project_id = payload.project_id

    if payload.pole_id is not None:
        mentorship.pole_id = payload.pole_id

    if payload.title is not None:
        mentorship.title = payload.title

    if payload.objective is not None:
        mentorship.objective = payload.objective

    if payload.started_at is not None:
        mentorship.started_at = payload.started_at

    if payload.ended_at is not None:
        mentorship.ended_at = payload.ended_at

    mentorship.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(mentorship)

    return mentorship


@router.post("/mentorships/{mentorship_id}/complete", response_model=MentorshipRead)
def complete_mentorship(
    mentorship_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    mentorship = get_mentorship_or_404(db, mentorship_id)

    mentorship.status = "completed"
    mentorship.ended_at = date.today()
    mentorship.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(mentorship)

    return mentorship


@router.delete("/mentorships/{mentorship_id}")
def delete_mentorship(
    mentorship_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    mentorship = get_mentorship_or_404(db, mentorship_id)

    db.delete(mentorship)
    db.commit()

    return {
        "ok": True,
        "message": "Mentorat supprimé",
    }
