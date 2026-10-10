"""Keep Alumni account transitions and the directory in the same transaction."""
from sqlalchemy.orm import Session
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
