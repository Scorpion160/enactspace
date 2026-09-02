from datetime import date, datetime, timezone
from decimal import Decimal
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.account import LegalAcceptance, UserPreference
from app.models.academy import AcademyCertificate, AcademyProgress, AcademyQuizAttempt
from app.models.attendance import AttendanceRecord
from app.models.chat import ChatMessage, ChatParticipant
from app.models.event import Event, EventParticipant
from app.models.finance import Fee, FinancialAccount, Payment
from app.models.gamification import EngagementPoint, UserBadge
from app.models.impact import ImpactEvidence, ImpactMetric, ImpactProject
from app.models.mobile_money import MobileMoneyTransaction
from app.models.notification import Notification
from app.models.pole import PoleMember
from app.models.post import Post, PostComment, PostReaction
from app.models.project import ProjectMember
from app.models.recruitment import Application
from app.models.role import Role, UserRole
from app.models.task import Task, TaskAssignee, TaskComment
from app.models.user import User


EXPORT_SCHEMA_VERSION = "1.0"


def _value(value):
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, (UUID, Decimal)):
        return str(value)
    return value


def _rows(rows, fields: tuple[str, ...]) -> list[dict]:
    return [
        {field: _value(getattr(row, field, None)) for field in fields}
        for row in rows
    ]


def build_user_data_export(db: Session, user: User, app_version: str) -> dict:
    user_id = user.id
    roles = (
        db.query(Role.name)
        .join(UserRole, UserRole.role_id == Role.id)
        .filter(UserRole.user_id == user_id)
        .all()
    )
    assigned_tasks = (
        db.query(Task)
        .join(TaskAssignee, TaskAssignee.task_id == Task.id)
        .filter(TaskAssignee.user_id == user_id)
        .all()
    )
    participated_events = (
        db.query(Event)
        .join(EventParticipant, EventParticipant.event_id == Event.id)
        .filter(EventParticipant.user_id == user_id)
        .all()
    )
    impact_projects = db.query(ImpactProject).filter(ImpactProject.created_by_id == user_id).all()
    impact_ids = [item.id for item in impact_projects]
    impact_metrics = (
        db.query(ImpactMetric).filter(ImpactMetric.impact_project_id.in_(impact_ids)).all()
        if impact_ids else []
    )
    metric_ids = [item.id for item in impact_metrics]
    impact_evidence = (
        db.query(ImpactEvidence).filter(
            (ImpactEvidence.impact_project_id.in_(impact_ids))
            | (ImpactEvidence.metric_id.in_(metric_ids))
        ).all()
        if impact_ids or metric_ids else []
    )
    preference = db.query(UserPreference).filter(UserPreference.user_id == user_id).first()

    return {
        "metadata": {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "user_id": str(user_id),
            "app_version": app_version,
            "schema_version": EXPORT_SCHEMA_VERSION,
        },
        "data": {
            "profile": {
                field: _value(getattr(user, field))
                for field in (
                    "id", "first_name", "last_name", "email", "phone", "gender",
                    "profile_type", "photo_url", "department", "study_level", "promotion",
                    "bio", "linkedin_url", "github_url", "portfolio_url", "status",
                    "email_verified", "is_active", "created_at", "updated_at",
                )
            },
            "preferences": _rows([preference] if preference else [], (
                "locale", "theme", "notification_in_app_enabled",
                "notification_email_enabled", "created_at", "updated_at",
            )),
            "roles": [row[0] for row in roles],
            "pole_memberships": _rows(
                db.query(PoleMember).filter(PoleMember.user_id == user_id).all(),
                ("id", "pole_id", "position", "joined_at", "left_at", "is_active"),
            ),
            "project_memberships": _rows(
                db.query(ProjectMember).filter(ProjectMember.user_id == user_id).all(),
                ("id", "project_id", "position", "joined_at", "left_at", "is_active"),
            ),
            "attendance": _rows(
                db.query(AttendanceRecord).filter(AttendanceRecord.user_id == user_id).all(),
                ("id", "session_id", "status", "checkin_time", "delay_minutes", "source",
                 "recorded_at", "justification", "justification_status", "is_justified",
                 "penalty_amount", "note", "created_at", "updated_at"),
            ),
            "posts": _rows(
                db.query(Post).filter(Post.author_id == user_id).all(),
                ("id", "title", "content", "post_type", "pole_id", "project_id", "event_id",
                 "document_id", "media_url", "media_name", "media_mime_type", "visibility",
                 "is_official", "is_pinned", "created_at", "updated_at"),
            ),
            "post_comments": _rows(
                db.query(PostComment).filter(PostComment.user_id == user_id).all(),
                ("id", "post_id", "content", "created_at"),
            ),
            "post_reactions": _rows(
                db.query(PostReaction).filter(PostReaction.user_id == user_id).all(),
                ("id", "post_id", "reaction_type", "created_at"),
            ),
            "chat_memberships": _rows(
                db.query(ChatParticipant).filter(ChatParticipant.user_id == user_id).all(),
                ("thread_id", "participant_role", "joined_at", "last_read_at"),
            ),
            "chat_messages_authored": _rows(
                db.query(ChatMessage).filter(ChatMessage.author_id == user_id).all(),
                ("id", "thread_id", "content", "message_type", "created_at", "edited_at", "deleted_at"),
            ),
            "notifications": _rows(
                db.query(Notification).filter(Notification.user_id == user_id).all(),
                ("id", "title", "message", "type", "is_read", "related_type", "related_id", "created_at", "read_at"),
            ),
            "tasks_assigned": _rows(
                assigned_tasks,
                ("id", "title", "description", "pole_id", "project_id", "priority", "status",
                 "due_date", "completed_at", "validated_at", "proof_required", "proof_url", "created_at", "updated_at"),
            ),
            "task_comments_authored": _rows(
                db.query(TaskComment).filter(TaskComment.user_id == user_id).all(),
                ("id", "task_id", "content", "created_at"),
            ),
            "events_participated": _rows(
                participated_events,
                ("id", "title", "description", "event_type", "location", "start_time", "end_time", "pole_id", "project_id"),
            ),
            "events_created": _rows(
                db.query(Event).filter(Event.created_by == user_id).all(),
                ("id", "title", "description", "event_type", "location", "start_time", "end_time", "pole_id", "project_id"),
            ),
            "finance": {
                "account": _rows(db.query(FinancialAccount).filter(FinancialAccount.user_id == user_id).all(), ("balance_due", "total_paid", "updated_at")),
                "fees": _rows(db.query(Fee).filter(Fee.user_id == user_id).all(), ("id", "type", "category", "label", "description", "amount", "amount_paid", "currency", "status", "due_date", "paid_at", "cancelled_at", "created_at", "updated_at")),
                "payments": _rows(db.query(Payment).filter(Payment.user_id == user_id).all(), ("id", "amount", "currency", "method", "status", "reference", "proof_url", "validated_at", "rejected_at", "rejection_reason", "receipt_url", "created_at")),
                "mobile_money": _rows(db.query(MobileMoneyTransaction).filter(MobileMoneyTransaction.member_id == user_id).all(), ("id", "finance_item_id", "payment_id", "provider", "amount", "currency", "phone_number_masked", "channel", "status", "created_at", "updated_at", "completed_at", "cancelled_at", "refunded_at")),
            },
            "academy": {
                "progress": _rows(db.query(AcademyProgress).filter(AcademyProgress.user_id == user_id).all(), ("id", "course_id", "lesson_id", "status", "progress_percent", "started_at", "completed_at", "updated_at")),
                "quiz_attempts": _rows(db.query(AcademyQuizAttempt).filter(AcademyQuizAttempt.user_id == user_id).all(), ("id", "quiz_id", "answers", "score", "max_score", "passed", "attempt_number", "started_at", "submitted_at")),
                "certificates": _rows(db.query(AcademyCertificate).filter(AcademyCertificate.user_id == user_id).all(), ("id", "course_id", "certificate_code", "issued_at", "file_id")),
            },
            "gamification": {
                "points": _rows(db.query(EngagementPoint).filter(EngagementPoint.user_id == user_id).all(), ("id", "season_id", "pole_id", "project_id", "source_type", "source_id", "points", "reason", "created_at")),
                "badges": _rows(db.query(UserBadge).filter(UserBadge.user_id == user_id).all(), ("id", "badge_id", "season_id", "awarded_at")),
            },
            "impact_created": {
                "projects": _rows(impact_projects, ("id", "project_id", "season_id", "title", "summary", "status", "created_at", "updated_at")),
                "metrics": _rows(impact_metrics, ("id", "impact_project_id", "title", "category", "unit", "value", "source", "status", "created_at", "updated_at")),
                "evidence": _rows(impact_evidence, ("id", "impact_project_id", "metric_id", "title", "description", "category", "status", "created_at", "updated_at")),
            },
            "recruitment_applications": _rows(
                db.query(Application).filter(Application.email == user.email).all(),
                ("id", "campaign_id", "first_name", "last_name", "gender", "email", "phone",
                 "department", "study_level", "motivation", "preferred_pole", "project_interest",
                 "availability", "status", "created_at", "updated_at"),
            ),
            "legal_acceptances": _rows(
                db.query(LegalAcceptance).filter(LegalAcceptance.user_id == user_id).all(),
                ("id", "legal_document_id", "document_version", "source", "accepted_at"),
            ),
        },
    }
