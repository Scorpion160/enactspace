from app.core.time import utc_now
import uuid
from datetime import datetime

from sqlalchemy import Boolean, CheckConstraint, Integer, String, Text, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base
from app.db.types import GUID


class ChatThread(Base):
    __tablename__ = "chat_threads"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    title: Mapped[str | None] = mapped_column(String(180), nullable=True)
    thread_type: Mapped[str] = mapped_column(String(40), default="group")
    scope_type: Mapped[str | None] = mapped_column(String(40), nullable=True)
    scope_id: Mapped[uuid.UUID | None] = mapped_column(GUID(), nullable=True)
    created_by: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        default=utc_now,
        onupdate=utc_now,
    )

    participants = relationship(
        "ChatParticipant",
        back_populates="thread",
        cascade="all, delete-orphan",
    )
    messages = relationship(
        "ChatMessage",
        back_populates="thread",
        cascade="all, delete-orphan",
    )


class ChatParticipant(Base):
    __tablename__ = "chat_participants"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    thread_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("chat_threads.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    participant_role: Mapped[str] = mapped_column(String(40), default="member")
    joined_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    last_read_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    thread = relationship("ChatThread", back_populates="participants")
    user = relationship("User")

    __table_args__ = (
        UniqueConstraint("thread_id", "user_id", name="uq_chat_participant"),
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    thread_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("chat_threads.id", ondelete="CASCADE"),
        nullable=False,
    )
    author_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id"),
        nullable=False,
    )
    client_message_id: Mapped[str | None] = mapped_column(String(120), nullable=True)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    message_type: Mapped[str] = mapped_column(String(40), default="text")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    edited_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    thread = relationship("ChatThread", back_populates="messages")
    author = relationship("User")
    __table_args__ = (
        UniqueConstraint("author_id", "client_message_id", name="uq_chat_message_author_client_id"),
    )

    reactions = relationship(
        "ChatMessageReaction",
        back_populates="message",
        cascade="all, delete-orphan",
    )


class ChatMessageReaction(Base):
    __tablename__ = "chat_message_reactions"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("chat_messages.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    reaction_type: Mapped[str] = mapped_column(String(40), default="👍")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)

    message = relationship("ChatMessage", back_populates="reactions")
    user = relationship("User")

    __table_args__ = (
        UniqueConstraint("message_id", "user_id", name="uq_chat_message_reaction"),
    )


class ChatPoll(Base):
    __tablename__ = "chat_polls"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    message_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("chat_messages.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
    )
    question: Mapped[str] = mapped_column(Text, nullable=False)
    allows_multiple: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    closes_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)

    options = relationship(
        "ChatPollOption",
        back_populates="poll",
        cascade="all, delete-orphan",
        order_by="ChatPollOption.position",
    )
    votes = relationship(
        "ChatPollVote",
        back_populates="poll",
        cascade="all, delete-orphan",
    )


class ChatPollOption(Base):
    __tablename__ = "chat_poll_options"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    poll_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("chat_polls.id", ondelete="CASCADE"),
        nullable=False,
    )
    label: Mapped[str] = mapped_column(String(240), nullable=False)
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)

    poll = relationship("ChatPoll", back_populates="options")
    votes = relationship(
        "ChatPollVote",
        back_populates="option",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        CheckConstraint("position >= 0", name="ck_chat_poll_option_position"),
        UniqueConstraint("poll_id", "position", name="uq_chat_poll_option_position"),
    )


class ChatPollVote(Base):
    __tablename__ = "chat_poll_votes"

    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    poll_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("chat_polls.id", ondelete="CASCADE"),
        nullable=False,
    )
    option_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("chat_poll_options.id", ondelete="CASCADE"),
        nullable=False,
    )
    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, nullable=False)

    poll = relationship("ChatPoll", back_populates="votes")
    option = relationship("ChatPollOption", back_populates="votes")
    user = relationship("User")

    __table_args__ = (
        UniqueConstraint(
            "poll_id", "option_id", "user_id",
            name="uq_chat_poll_vote_option_user",
        ),
    )
