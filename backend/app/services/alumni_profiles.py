"""Keep Alumni account transitions and the directory in the same transaction."""
from sqlalchemy.orm import Session

from app.core.roles import ALUMNI_ROLE
from app.models.audit import AuditLog
from app.models.alumni import AlumniProfile
from app.models.user import User


def ensure_alumni_profile(db: Session, user: User) -> AlumniProfile:
    """Caller locks the user. Preserve existing profile choices and personal data."""
    existing = db.query(AlumniProfile).filter(AlumniProfile.user_id == user.id).first()
    if existing is not None:
        if user.enactus_join_year is None:
            user.enactus_join_year = existing.enactus_join_year
        elif existing.enactus_join_year is None:
            existing.enactus_join_year = user.enactus_join_year
        return existing
    profile = AlumniProfile(user_id=user.id, enactus_join_year=user.enactus_join_year, visibility="internal",
                           available_for_mentoring=False)
    db.add(profile)
    db.flush()
    return profile


def sync_alumni_join_year(db: Session, user: User) -> None:
    """Caller holds the user lock; synchronize an existing directory profile."""
    profile = db.query(AlumniProfile).filter(AlumniProfile.user_id == user.id).first()
    if profile is not None:
        profile.enactus_join_year = user.enactus_join_year


def alumni_transition_control(db: Session, user: User, roles: set[str]) -> dict:
    """Only a recorded account conversion confirms an Enacteur → Alumni passage."""
    events = db.query(AuditLog).filter_by(
        action="passage_alumni", entity_type="user", entity_id=user.id,
    ).order_by(AuditLog.created_at.desc(), AuditLog.id.desc())
    confirmation = next(
        (event for event in events if (event.new_value or {}).get("status") == ALUMNI_ROLE),
        None,
    )
    profile = db.query(AlumniProfile).filter_by(user_id=user.id).one_or_none()
    if confirmation is None:
        state = "unconfirmed"
    elif not (user.status == ALUMNI_ROLE and user.profile_type == ALUMNI_ROLE
              and user.is_active and roles == {ALUMNI_ROLE}):
        state = "inconsistent_account"
    elif profile is None:
        state = "missing_profile"
    else:
        state = "linked_visible" if profile.visibility == "internal" else "linked_restricted"
    return {
        "state": state,
        "confirmed_at": confirmation.created_at if confirmation else None,
        "profile_id": profile.id if profile else None,
        "visibility": profile.visibility if profile else None,
        "can_repair": state == "missing_profile",
    }
