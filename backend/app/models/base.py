from app.db.database import Base
from app.db.types import GUID
from app.models.user import User, PasswordResetOtp
from app.models.role import Role, UserRole
from app.models.season import Season
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember, ProjectPole
from app.models.event import Event, EventParticipant
from app.models.attendance import (
    AttendanceSession,
    AttendanceExpectedMember,
    AttendanceRecord,
)
from app.models.finance import (
    FinancialAccount,
    Fee,
    Payment,
    PaymentAllocation,
    ClubTransaction,
)
from app.models.task import (
    Task,
    TaskAssignee,
    TaskChecklistItem,
    TaskComment,
)
from app.models.document import Document
from app.models.post import Post, PostComment, PostReaction
from app.models.chat import (
    ChatThread,
    ChatParticipant,
    ChatMessage,
    ChatMessageReaction,
)
from app.models.recruitment import (
    RecruitmentCampaign,
    Application,
    ApplicationReview,
)
from app.models.alumni import AlumniProfile, Mentorship
from app.models.notification import Notification
from app.models.gamification import EngagementPoint, Badge, UserBadge
from app.models.audit import AuditLog
