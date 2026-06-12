from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, extract

from app.db.database import get_db
from app.models.gamification import EngagementPoint, Badge, UserBadge
from app.models.user import User
from app.schemas.gamification import (
    EngagementPointCreate,
    EngagementPointRead,
    BadgeCreate,
    BadgeUpdate,
    BadgeRead,
    UserBadgeCreate,
    UserBadgeRead,
    UserRankingRead,
    PoleRankingRead,
    MonthlyWinnerRead,
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/gamification", tags=["Gamification"])


VALID_POINT_SOURCES = {
    "task_validated",
    "attendance_present",
    "attendance_late",
    "event_participation",
    "training_completed",
    "document_shared",
    "project_progress",
    "mentorship",
    "leader_rating",
    "manual",
}

DEFAULT_BADGES = [
    {
        "name": "membre_actif",
        "label": "Membre actif",
        "description": "Attribué aux enacteurs très engagés dans les activités du club.",
    },
    {
        "name": "ponctuel",
        "label": "Ponctuel",
        "description": "Attribué aux enacteurs réguliers et ponctuels.",
    },
    {
        "name": "leader",
        "label": "Leader",
        "description": "Attribué aux enacteurs qui prennent des initiatives et encadrent les autres.",
    },
    {
        "name": "innovateur",
        "label": "Innovateur",
        "description": "Attribué aux enacteurs qui proposent des idées nouvelles.",
    },
    {
        "name": "finisher",
        "label": "Finisher",
        "description": "Attribué aux enacteurs qui terminent et livrent leurs tâches.",
    },
    {
        "name": "mentor",
        "label": "Mentor",
        "description": "Attribué aux alumni ou enacteurs qui accompagnent les autres.",
    },
    {
        "name": "communicateur",
        "label": "Communicateur",
        "description": "Attribué aux enacteurs actifs dans la communication.",
    },
    {
        "name": "batisseur",
        "label": "Bâtisseur",
        "description": "Attribué aux enacteurs qui construisent concrètement les projets.",
    },
]


def get_badge_or_404(db: Session, badge_id: str) -> Badge:
    badge = db.query(Badge).filter(Badge.id == badge_id).first()

    if not badge:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Badge introuvable",
        )

    return badge


def get_user_badge_or_404(db: Session, user_badge_id: str) -> UserBadge:
    user_badge = db.query(UserBadge).filter(UserBadge.id == user_badge_id).first()

    if not user_badge:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Badge utilisateur introuvable",
        )

    return user_badge


@router.post("/points", response_model=EngagementPointRead)
def create_engagement_point(
    payload: EngagementPointCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.source_type not in VALID_POINT_SOURCES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Source de points invalide",
        )

    if payload.points == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le nombre de points ne peut pas être nul",
        )

    point = EngagementPoint(
        user_id=payload.user_id,
        season_id=payload.season_id,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        source_type=payload.source_type,
        source_id=payload.source_id,
        points=payload.points,
        reason=payload.reason,
        awarded_by=current_user.id,
    )

    db.add(point)
    db.commit()
    db.refresh(point)

    return point


@router.get("/points", response_model=list[EngagementPointRead])
def list_engagement_points(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    user_id: str | None = Query(default=None),
    season_id: str | None = Query(default=None),
    pole_id: str | None = Query(default=None),
    project_id: str | None = Query(default=None),
    source_type: str | None = Query(default=None),
):
    query = db.query(EngagementPoint)

    if user_id:
        query = query.filter(EngagementPoint.user_id == user_id)

    if season_id:
        query = query.filter(EngagementPoint.season_id == season_id)

    if pole_id:
        query = query.filter(EngagementPoint.pole_id == pole_id)

    if project_id:
        query = query.filter(EngagementPoint.project_id == project_id)

    if source_type:
        query = query.filter(EngagementPoint.source_type == source_type)

    return query.order_by(EngagementPoint.created_at.desc()).all()


@router.get("/ranking/users", response_model=list[UserRankingRead])
def get_user_ranking(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    season_id: str | None = Query(default=None),
    month: int | None = Query(default=None),
    year: int | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
):
    query = db.query(
        EngagementPoint.user_id,
        func.coalesce(func.sum(EngagementPoint.points), 0).label("total_points"),
    )

    if season_id:
        query = query.filter(EngagementPoint.season_id == season_id)

    if month:
        query = query.filter(extract("month", EngagementPoint.created_at) == month)

    if year:
        query = query.filter(extract("year", EngagementPoint.created_at) == year)

    rows = query.group_by(EngagementPoint.user_id).order_by(
        func.sum(EngagementPoint.points).desc()
    ).limit(limit).all()

    return [
        UserRankingRead(user_id=row.user_id, total_points=int(row.total_points or 0))
        for row in rows
    ]


@router.get("/ranking/poles", response_model=list[PoleRankingRead])
def get_pole_ranking(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    season_id: str | None = Query(default=None),
    month: int | None = Query(default=None),
    year: int | None = Query(default=None),
    limit: int = Query(default=20, ge=1, le=100),
):
    query = db.query(
        EngagementPoint.pole_id,
        func.coalesce(func.sum(EngagementPoint.points), 0).label("total_points"),
    ).filter(EngagementPoint.pole_id.isnot(None))

    if season_id:
        query = query.filter(EngagementPoint.season_id == season_id)

    if month:
        query = query.filter(extract("month", EngagementPoint.created_at) == month)

    if year:
        query = query.filter(extract("year", EngagementPoint.created_at) == year)

    rows = query.group_by(EngagementPoint.pole_id).order_by(
        func.sum(EngagementPoint.points).desc()
    ).limit(limit).all()

    return [
        PoleRankingRead(pole_id=row.pole_id, total_points=int(row.total_points or 0))
        for row in rows
    ]


@router.get("/winner/member-of-month", response_model=MonthlyWinnerRead)
def get_member_of_month(
    month: int,
    year: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    season_id: str | None = Query(default=None),
):
    query = db.query(
        EngagementPoint.user_id,
        func.coalesce(func.sum(EngagementPoint.points), 0).label("total_points"),
    ).filter(
        extract("month", EngagementPoint.created_at) == month,
        extract("year", EngagementPoint.created_at) == year,
    )

    if season_id:
        query = query.filter(EngagementPoint.season_id == season_id)

    row = query.group_by(EngagementPoint.user_id).order_by(
        func.sum(EngagementPoint.points).desc()
    ).first()

    if not row:
        return MonthlyWinnerRead(month=month, year=year, user_id=None, total_points=0)

    return MonthlyWinnerRead(
        month=month,
        year=year,
        user_id=row.user_id,
        total_points=int(row.total_points or 0),
    )


@router.get("/winner/pole-of-month", response_model=MonthlyWinnerRead)
def get_pole_of_month(
    month: int,
    year: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    season_id: str | None = Query(default=None),
):
    query = db.query(
        EngagementPoint.pole_id,
        func.coalesce(func.sum(EngagementPoint.points), 0).label("total_points"),
    ).filter(
        EngagementPoint.pole_id.isnot(None),
        extract("month", EngagementPoint.created_at) == month,
        extract("year", EngagementPoint.created_at) == year,
    )

    if season_id:
        query = query.filter(EngagementPoint.season_id == season_id)

    row = query.group_by(EngagementPoint.pole_id).order_by(
        func.sum(EngagementPoint.points).desc()
    ).first()

    if not row:
        return MonthlyWinnerRead(month=month, year=year, pole_id=None, total_points=0)

    return MonthlyWinnerRead(
        month=month,
        year=year,
        pole_id=row.pole_id,
        total_points=int(row.total_points or 0),
    )


@router.post("/badges", response_model=BadgeRead)
def create_badge(
    payload: BadgeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    existing = db.query(Badge).filter(Badge.name == payload.name).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un badge existe déjà avec ce nom",
        )

    badge = Badge(
        name=payload.name,
        label=payload.label,
        description=payload.description,
        icon_url=payload.icon_url,
    )

    db.add(badge)
    db.commit()
    db.refresh(badge)

    return badge


@router.post("/badges/init-defaults", response_model=list[BadgeRead])
def init_default_badges(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    created_badges = []

    for item in DEFAULT_BADGES:
        existing = db.query(Badge).filter(Badge.name == item["name"]).first()

        if existing:
            continue

        badge = Badge(
            name=item["name"],
            label=item["label"],
            description=item["description"],
        )

        db.add(badge)
        created_badges.append(badge)

    db.commit()

    for badge in created_badges:
        db.refresh(badge)

    return created_badges


@router.get("/badges", response_model=list[BadgeRead])
def list_badges(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Badge).order_by(Badge.label.asc()).all()


@router.get("/badges/{badge_id}", response_model=BadgeRead)
def get_badge(
    badge_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_badge_or_404(db, badge_id)


@router.patch("/badges/{badge_id}", response_model=BadgeRead)
def update_badge(
    badge_id: str,
    payload: BadgeUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    badge = get_badge_or_404(db, badge_id)

    if payload.label is not None:
        badge.label = payload.label

    if payload.description is not None:
        badge.description = payload.description

    if payload.icon_url is not None:
        badge.icon_url = payload.icon_url

    db.commit()
    db.refresh(badge)

    return badge


@router.delete("/badges/{badge_id}")
def delete_badge(
    badge_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    badge = get_badge_or_404(db, badge_id)

    db.delete(badge)
    db.commit()

    return {
        "ok": True,
        "message": "Badge supprimé",
    }


@router.post("/user-badges", response_model=UserBadgeRead)
def award_badge_to_user(
    payload: UserBadgeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    get_badge_or_404(db, str(payload.badge_id))

    existing = db.query(UserBadge).filter(
        UserBadge.user_id == payload.user_id,
        UserBadge.badge_id == payload.badge_id,
        UserBadge.season_id == payload.season_id,
    ).first()

    if existing:
        return existing

    user_badge = UserBadge(
        user_id=payload.user_id,
        badge_id=payload.badge_id,
        season_id=payload.season_id,
        awarded_by=current_user.id,
    )

    db.add(user_badge)
    db.commit()
    db.refresh(user_badge)

    return user_badge


@router.get("/user-badges", response_model=list[UserBadgeRead])
def list_user_badges(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    user_id: str | None = Query(default=None),
    season_id: str | None = Query(default=None),
):
    query = db.query(UserBadge)

    if user_id:
        query = query.filter(UserBadge.user_id == user_id)

    if season_id:
        query = query.filter(UserBadge.season_id == season_id)

    return query.order_by(UserBadge.awarded_at.desc()).all()


@router.delete("/user-badges/{user_badge_id}")
def remove_user_badge(
    user_badge_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    user_badge = get_user_badge_or_404(db, user_badge_id)

    db.delete(user_badge)
    db.commit()

    return {
        "ok": True,
        "message": "Badge retiré à l'utilisateur",
    }