"""One-use first-access challenges; raw codes are never stored here."""
import uuid
from datetime import datetime
from sqlalchemy import String, Integer, DateTime, ForeignKey, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.database import Base
from app.db.types import GUID
from app.core.time import utc_now

class ActivationChallenge(Base):
    __tablename__ = "activation_challenges"
    id: Mapped[uuid.UUID] = mapped_column(GUID(),primary_key=True,default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(GUID(),ForeignKey("users.id",ondelete="CASCADE"),unique=True,nullable=False)
    code_hash: Mapped[str] = mapped_column(String(64),nullable=False)
    email_snapshot: Mapped[str] = mapped_column(String(150),nullable=False)
    failed_attempts: Mapped[int] = mapped_column(Integer,default=0,server_default="0",nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime,nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime,default=utc_now,nullable=False)
    __table_args__ = (CheckConstraint("failed_attempts >= 0 AND failed_attempts <= 5",name="ck_activation_failed_attempts"),)
