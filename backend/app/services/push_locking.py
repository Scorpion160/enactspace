"""DB lock order: user -> preference -> installations -> deliveries.

Auth operations keep their established user -> auth-session ordering before
continuing to installations and deliveries. The short outbox claim transaction
locks delivery rows only and commits before any user-scoped processing begins.
"""

from sqlalchemy.orm import Session

from app.models.account import UserPreference
from app.models.product_services import AppInstallation, PushDelivery
from app.models.user import User


def lock_push_user(db: Session, user_id) -> User | None:
    return (
        db.query(User)
        .filter(User.id == user_id)
        .populate_existing()
        .with_for_update()
        .first()
    )


def lock_push_preference(db: Session, user_id) -> UserPreference | None:
    lock_push_user(db, user_id)
    return (
        db.query(UserPreference)
        .filter(UserPreference.user_id == user_id)
        .populate_existing()
        .with_for_update()
        .first()
    )


def lock_user_installations(db: Session, user_id) -> list[AppInstallation]:
    lock_push_preference(db, user_id)
    return (
        db.query(AppInstallation)
        .filter(AppInstallation.user_id == user_id)
        .order_by(AppInstallation.id)
        .populate_existing()
        .with_for_update()
        .all()
    )


def lock_user_installation(
    db: Session, user_id, installation_id
) -> AppInstallation | None:
    lock_push_preference(db, user_id)
    return (
        db.query(AppInstallation)
        .filter(
            AppInstallation.id == installation_id,
            AppInstallation.user_id == user_id,
        )
        .populate_existing()
        .with_for_update()
        .first()
    )


def lock_push_delivery(db: Session, delivery_id) -> PushDelivery | None:
    return (
        db.query(PushDelivery)
        .filter(PushDelivery.id == delivery_id)
        .populate_existing()
        .with_for_update()
        .first()
    )
