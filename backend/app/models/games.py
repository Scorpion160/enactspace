"""Multiplayer club games: durable rooms, participants and one response per round."""
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.core.time import utc_now
from app.db.database import Base
from app.db.types import GUID


class GameRoom(Base):
    __tablename__ = "game_rooms"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(8), nullable=False, unique=True)
    host_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id"), nullable=False)
    game: Mapped[str] = mapped_column(String(30), nullable=False)
    mode: Mapped[str] = mapped_column(String(20), default="individual")
    theme: Mapped[str] = mapped_column(String(40), default="mix")
    status: Mapped[str] = mapped_column(String(20), default="lobby")
    round_number: Mapped[int] = mapped_column(Integer, default=0)
    max_rounds: Mapped[int] = mapped_column(Integer, default=5)
    state: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, onupdate=utc_now)


class GamePlayer(Base):
    __tablename__ = "game_players"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    room_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("game_rooms.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    team: Mapped[str | None] = mapped_column(String(30))
    score: Mapped[int] = mapped_column(Integer, default=0)
    role: Mapped[str | None] = mapped_column(String(30))
    secret: Mapped[str | None] = mapped_column(Text)
    eliminated: Mapped[bool] = mapped_column(default=False)
    won: Mapped[bool] = mapped_column(default=False)
    __table_args__ = (UniqueConstraint("room_id", "user_id", name="uq_game_player_room_user"),)


class GameResponse(Base):
    __tablename__ = "game_responses"
    id: Mapped[uuid.UUID] = mapped_column(GUID(), primary_key=True, default=uuid.uuid4)
    room_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("game_rooms.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(GUID(), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    round_number: Mapped[int] = mapped_column(Integer, nullable=False)
    answer: Mapped[str] = mapped_column(String(150), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now)
    __table_args__ = (UniqueConstraint("room_id", "user_id", "round_number", name="uq_game_response_round"),)
