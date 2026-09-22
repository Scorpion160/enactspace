import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Index, String, Text, DateTime, Date, Boolean, ForeignKey, Numeric, UniqueConstraint, text
from app.db.types import GUID
from sqlalchemy.orm import Mapped, mapped_column, validates

from app.db.database import Base


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(),
        ForeignKey("seasons.id"),
        nullable=True,
    )

    name: Mapped[str] = mapped_column(String(150), nullable=False)

    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    problem_statement: Mapped[str | None] = mapped_column(Text, nullable=True)
    solution: Mapped[str | None] = mapped_column(Text, nullable=True)
    objectives: Mapped[str | None] = mapped_column(Text, nullable=True)
    expected_impact: Mapped[str | None] = mapped_column(Text, nullable=True)

    budget_estimated: Mapped[float] = mapped_column(Numeric(12, 2), default=0)
    status: Mapped[str] = mapped_column(String(50), default="idee")

    started_at: Mapped[date | None] = mapped_column(Date, nullable=True)
    ended_at: Mapped[date | None] = mapped_column(Date, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    @validates("status")
    def normalize_status(self, _key, value):
        return "termine" if value in {"completed", "done"} else value

    __table_args__ = (
        CheckConstraint(
            "status IN ('idee','etude','prototype','test','deploiement','termine','suspendu')",
            name="ck_projects_status",
        ),
    )


class ProjectMember(Base):
    __tablename__ = "project_members"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )

    position: Mapped[str] = mapped_column(String(50), default="membre")
    joined_at: Mapped[date] = mapped_column(Date, default=date.today)
    left_at: Mapped[date | None] = mapped_column(Date, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    __table_args__ = (
        UniqueConstraint("project_id", "user_id", name="uq_project_user"),
        Index(
            "ux_project_members_active_leadership_position",
            "project_id",
            "position",
            unique=True,
            sqlite_where=text(
                "is_active = 1 AND left_at IS NULL "
                "AND position IN ('chef_projet', 'adjoint_chef_projet')"
            ),
            postgresql_where=text(
                "is_active = true AND left_at IS NULL "
                "AND position IN ('chef_projet', 'adjoint_chef_projet')"
            ),
        ),
    )


class ProjectPole(Base):
    __tablename__ = "project_poles"

    id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        primary_key=True,
        default=uuid.uuid4,
    )

    project_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("projects.id", ondelete="CASCADE"),
        nullable=False,
    )

    pole_id: Mapped[uuid.UUID] = mapped_column(
        GUID(),
        ForeignKey("poles.id", ondelete="CASCADE"),
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint("project_id", "pole_id", name="uq_project_pole"),
    )
