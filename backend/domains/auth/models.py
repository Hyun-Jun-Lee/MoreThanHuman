"""
Auth 도메인 SQLAlchemy 모델 정의
"""
from datetime import datetime

from sqlalchemy import Boolean, Column, DateTime, String
from sqlalchemy.orm import relationship

from database import Base


class UserModel(Base):
    """사용자 테이블"""

    __tablename__ = "users"

    id = Column(String(36), primary_key=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=True)  # OAuth 전용 사용자는 null
    name = Column(String(100), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    oauth_provider = Column(String(50), nullable=True)  # "google" 또는 null
    oauth_provider_id = Column(String(255), nullable=True)  # Google sub ID
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    conversations = relationship("ConversationModel", back_populates="user", cascade="all, delete-orphan")
