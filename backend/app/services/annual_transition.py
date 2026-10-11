"""Serialize year changes and retain every operational and academic record."""
from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session
from app.models.season import Season
from app.models.user import User
from app.services.audit_service import create_audit_log
from app.services.notification_service import notify_user


def lock_year_transition(db: Session) -> None:
    # Covers the empty-years case too; released when the transaction ends.
    if db.get_bind().dialect.name == "postgresql":
        db.execute(text("SELECT pg_advisory_xact_lock(196042, 114)"))


def activate_year(db: Session, year: Season, *, expected_current_id, actor_id=None):
    lock_year_transition(db)
    years = db.query(Season).populate_existing().with_for_update().all()
    year = next((row for row in years if row.id == year.id), year)
    current = next((row for row in years if row.is_current), None)
    if current is not None and current.id == year.id:
        return year
    if (current.id if current else None) != expected_current_id:
        raise HTTPException(409, "L’année courante a changé. Actualisez avant de poursuivre.")
    if year.archived:
        raise HTTPException(409, "Une année archivée ne peut pas redevenir courante.")
    if current is not None and year.start_date <= current.start_date:
        raise HTTPException(409, "La nouvelle année doit commencer après l’année courante.")
    if current is not None and current.end_date and year.start_date <= current.end_date:
        raise HTTPException(409, "Les dates des deux années se chevauchent.")
    if current is not None:
        current.is_current = False
        current.archived = True
        db.flush()  # Release the unique-current index before activating the next year.
    year.is_current = True
    year.archived = False
    db.flush()
    create_audit_log(db=db, action="activation_annee", user_id=actor_id,
                     entity_type="season", entity_id=year.id,
                     old_value={"current_year_id": str(current.id) if current else None},
                     new_value={"current_year_id": str(year.id), "name": year.name})
    for member in db.query(User).filter(User.status == "active", User.is_active.is_(True)).all():
        notify_user(db, user_id=member.id, title="Une nouvelle année commence",
                    message=f"{year.name} est ouverte. Confirmez votre cursus dans Réglages > Profil académique. Vos tâches et votre historique sont conservés.",
                    notification_type="general", related_type="user", related_id=member.id)
    return year
