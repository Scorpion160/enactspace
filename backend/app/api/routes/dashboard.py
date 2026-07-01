from datetime import datetime

from fastapi import APIRouter, Depends
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, get_user_role_names
from app.core.roles import (
    ALUMNI_ROLE,
    ENACCHEF_ROLES,
    FINANCE_MANAGEMENT_ROLES,
    GLOBAL_MANAGEMENT_ROLES,
    RECRUITMENT_ACCESS_ROLES,
    SCOPED_RESPONSIBILITY_ROLES,
    SECRETARIAT_ROLES,
)
from app.db.database import get_db
from app.models.audit import AuditLog
from app.models.attendance import AttendanceRecord
from app.models.chat import ChatMessage, ChatParticipant
from app.models.document import Document
from app.models.event import Event
from app.models.finance import FinancialAccount, Payment
from app.models.gamification import EngagementPoint, UserBadge
from app.models.notification import Notification
from app.models.pole import Pole, PoleMember
from app.models.post import Post
from app.models.project import Project, ProjectMember
from app.models.recruitment import Application
from app.models.task import Task, TaskAssignee
from app.models.user import User


router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/summary")
def get_dashboard_summary(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    roles = get_user_role_names(db, current_user.id)
    flags = _permission_flags(roles)
    scope = _user_scope(db, current_user.id)

    summary = {
        "profile": {
            "id": str(current_user.id),
            "display_name": _display_name(current_user),
            "status": current_user.status,
            "profile_type": current_user.profile_type,
            "roles": sorted(roles),
            **flags,
        },
        "counts": {
            "notifications_unread": _count(
                db.query(Notification.id).filter(
                    Notification.user_id == current_user.id,
                    Notification.is_read.is_(False),
                )
            ),
            "tasks_assigned": _assigned_tasks_query(db, current_user.id).count(),
            "tasks_late": _late_tasks_query(db, current_user.id).count(),
            "tasks_done": _done_tasks_query(db, current_user.id).count(),
            "messages_unread": _unread_messages_count(db, current_user.id),
            "events_upcoming": _upcoming_events_query(db, current_user.id, flags, scope).count(),
            "posts_recent": _recent_posts_query(db, current_user, flags, scope).count(),
            "documents_accessible": _documents_query(db, current_user, flags, scope).count(),
            "badges_points": _engagement_points(db, current_user.id),
            "badges_count": _count(
                db.query(UserBadge.id).filter(UserBadge.user_id == current_user.id)
            ),
            "documents_pending_validation": 0,
            "members_active": None,
            "members_inactive": None,
            "projects_active": None,
            "poles": None,
            "absences_recent": None,
            "late_attendance_recent": None,
            "payments_pending": None,
            "finance_due": None,
            "finance_paid": None,
            "applications_pending": None,
        },
        "recent_activity": _recent_activity(db, current_user, flags, scope),
    }

    if flags["can_manage_documents"]:
        summary["counts"]["documents_pending_validation"] = _count(
            db.query(Document.id).filter(Document.status == "pending_validation")
        )

    if flags["can_view_global_members"]:
        summary["counts"]["members_active"] = _count(
            db.query(User.id).filter(User.status == "active", User.is_active.is_(True))
        )
        summary["counts"]["members_inactive"] = _count(
            db.query(User.id).filter(
                or_(User.status != "active", User.is_active.is_(False))
            )
        )

    if flags["is_enacchef"]:
        summary["counts"]["projects_active"] = _count(
            db.query(Project.id).filter(Project.status.notin_(["termine", "suspendu"]))
        )
        summary["counts"]["poles"] = _count(db.query(Pole.id))

    if flags["can_view_attendance"]:
        attendance_query = db.query(AttendanceRecord.id)
        if not flags["can_view_global_attendance"]:
            attendance_query = attendance_query.filter(
                AttendanceRecord.user_id == current_user.id
            )
        summary["counts"]["absences_recent"] = _count(
            attendance_query.filter(AttendanceRecord.status == "absent")
        )
        summary["counts"]["late_attendance_recent"] = _count(
            attendance_query.filter(AttendanceRecord.status == "late")
        )

    if flags["can_view_finance"]:
        summary["counts"]["payments_pending"] = _count(
            db.query(Payment.id).filter(Payment.status == "pending")
        )
        totals = db.query(
            func.coalesce(func.sum(FinancialAccount.balance_due), 0),
            func.coalesce(func.sum(FinancialAccount.total_paid), 0),
        ).first()
        summary["counts"]["finance_due"] = float(totals[0] or 0)
        summary["counts"]["finance_paid"] = float(totals[1] or 0)

    if flags["can_view_recruitment"]:
        summary["counts"]["applications_pending"] = _count(
            db.query(Application.id).filter(
                Application.status.in_(["received", "shortlisted", "interview"])
            )
        )

    return summary


def _permission_flags(roles: set[str]) -> dict:
    return {
        "is_alumni": ALUMNI_ROLE in roles,
        "is_enacchef": bool(roles.intersection(ENACCHEF_ROLES)),
        "can_view_global": bool(roles.intersection(GLOBAL_MANAGEMENT_ROLES)),
        "can_view_global_members": bool(roles.intersection(SECRETARIAT_ROLES)),
        "can_view_global_attendance": bool(roles.intersection(SECRETARIAT_ROLES)),
        "can_view_attendance": bool(
            roles.intersection(SECRETARIAT_ROLES | SCOPED_RESPONSIBILITY_ROLES)
        ),
        "can_view_finance": bool(roles.intersection(FINANCE_MANAGEMENT_ROLES)),
        "can_manage_documents": bool(roles.intersection(SECRETARIAT_ROLES)),
        "can_view_recruitment": bool(roles.intersection(RECRUITMENT_ACCESS_ROLES)),
    }


def _user_scope(db: Session, user_id) -> dict:
    pole_ids = [
        row[0]
        for row in db.query(PoleMember.pole_id)
        .filter(
            PoleMember.user_id == user_id,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
        )
        .all()
    ]
    project_ids = [
        row[0]
        for row in db.query(ProjectMember.project_id)
        .filter(
            ProjectMember.user_id == user_id,
            ProjectMember.is_active.is_(True),
            ProjectMember.left_at.is_(None),
        )
        .all()
    ]
    return {"pole_ids": pole_ids, "project_ids": project_ids}


def _count(query) -> int:
    return query.count()


def _assigned_tasks_query(db: Session, user_id):
    return (
        db.query(Task.id)
        .join(TaskAssignee, TaskAssignee.task_id == Task.id)
        .filter(TaskAssignee.user_id == user_id)
    )


def _late_tasks_query(db: Session, user_id):
    return _assigned_tasks_query(db, user_id).filter(
        Task.status.notin_(["termine", "valide", "done"]),
        Task.due_date.isnot(None),
        Task.due_date < datetime.utcnow(),
    )


def _done_tasks_query(db: Session, user_id):
    return _assigned_tasks_query(db, user_id).filter(
        Task.status.in_(["termine", "valide", "done"])
    )


def _unread_messages_count(db: Session, user_id) -> int:
    return _count(
        db.query(ChatMessage.id)
        .join(ChatParticipant, ChatParticipant.thread_id == ChatMessage.thread_id)
        .filter(
            ChatParticipant.user_id == user_id,
            ChatMessage.author_id != user_id,
            ChatMessage.deleted_at.is_(None),
            or_(
                ChatParticipant.last_read_at.is_(None),
                ChatMessage.created_at > ChatParticipant.last_read_at,
            ),
        )
    )


def _upcoming_events_query(db: Session, user_id, flags: dict, scope: dict):
    query = db.query(Event.id).filter(Event.start_time >= datetime.utcnow())
    if (
        flags["can_view_global"]
        or flags["can_view_global_attendance"]
        or flags["is_alumni"]
    ):
        return query
    return query.filter(
        or_(
            Event.pole_id.is_(None),
            Event.pole_id.in_(scope["pole_ids"]),
            Event.project_id.in_(scope["project_ids"]),
            Event.created_by == user_id,
        )
    )


def _recent_posts_query(db: Session, current_user: User, flags: dict, scope: dict):
    query = db.query(Post.id)
    if flags["can_view_global"]:
        return query
    if flags["is_alumni"]:
        return query.filter(Post.visibility.in_(["public", "alumni"]))
    return query.filter(
        or_(
            Post.visibility.in_(["internal", "public"]),
            Post.author_id == current_user.id,
            Post.pole_id.in_(scope["pole_ids"]),
            Post.project_id.in_(scope["project_ids"]),
        )
    )


def _documents_query(db: Session, current_user: User, flags: dict, scope: dict):
    query = db.query(Document.id)
    if flags["can_view_global"] or flags["can_manage_documents"]:
        return query
    if flags["is_alumni"]:
        return query.filter(Document.visibility.in_(["public", "alumni"]))
    return query.filter(
        or_(
            Document.visibility.in_(["internal", "public"]),
            Document.uploaded_by == current_user.id,
            Document.pole_id.in_(scope["pole_ids"]),
            Document.project_id.in_(scope["project_ids"]),
        )
    )


def _engagement_points(db: Session, user_id) -> int:
    value = (
        db.query(func.coalesce(func.sum(EngagementPoint.points), 0))
        .filter(EngagementPoint.user_id == user_id)
        .scalar()
    )
    return int(value or 0)


def _recent_activity(db: Session, current_user: User, flags: dict, scope: dict) -> list[dict]:
    items = []

    notifications = (
        db.query(Notification)
        .filter(Notification.user_id == current_user.id)
        .order_by(Notification.created_at.desc())
        .limit(4)
        .all()
    )
    for notification in notifications:
        items.append(
            _activity_item(
                "notification",
                notification.title,
                notification.created_at,
                "/notifications",
            )
        )

    recent_post_ids = [
        row[0]
        for row in _recent_posts_query(db, current_user, flags, scope).limit(5).all()
    ]
    post_rows = (
        db.query(Post)
        .filter(Post.id.in_(recent_post_ids))
        .order_by(Post.created_at.desc())
        .limit(3)
        .all()
    )
    for post in post_rows:
        items.append(
            _activity_item(
                "post",
                post.title or post.content[:80],
                post.created_at,
                "/posts",
            )
        )

    if flags["can_view_global_members"]:
        logs = (
            db.query(AuditLog)
            .filter(AuditLog.action.in_(["affectation_pole", "affectation_projet"]))
            .order_by(AuditLog.created_at.desc())
            .limit(3)
            .all()
        )
        for log in logs:
            target = (log.new_value or {}).get("pole_name") or (
                log.new_value or {}
            ).get("project_name")
            items.append(
                _activity_item(
                    "assignment",
                    f"{log.action.replace('_', ' ')} {target or ''}".strip(),
                    log.created_at,
                    "/members",
                )
            )

    items.sort(key=lambda item: item["created_at"], reverse=True)
    return items[:8]


def _activity_item(kind: str, title: str, created_at: datetime, route: str) -> dict:
    return {
        "type": kind,
        "title": title,
        "created_at": created_at.isoformat(),
        "route": route,
    }


def _display_name(user: User) -> str:
    value = f"{user.first_name or ''} {user.last_name or ''}".strip()
    return value or user.email
