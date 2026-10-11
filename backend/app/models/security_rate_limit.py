"""Shared counters for anonymous sensitive endpoints; no raw identifiers."""
from datetime import datetime
from sqlalchemy import String, Integer, DateTime, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column
from app.db.database import Base

class SecurityRateLimit(Base):
    __tablename__="security_rate_limits"
    key: Mapped[str]=mapped_column(String(64),primary_key=True)
    count: Mapped[int]=mapped_column(Integer,nullable=False)
    expires_at: Mapped[datetime]=mapped_column(DateTime,nullable=False,index=True)
    __table_args__=(CheckConstraint("count > 0",name="ck_security_rate_limit_count"),)
