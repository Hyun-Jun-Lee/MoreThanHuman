"""기기별 진행은 유지하고 운영 리셋 신호만 서버에 보관해요."""

from datetime import datetime
from typing import Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.orm import Session

from domains.language_snacks.models import LanguageSnackBasketResetModel, utcnow


class BasketResetRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    user_id: UUID
    content_language: Literal["en", "ko"]


class BasketResetState(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    content_language: Literal["en", "ko"]
    reset_id: UUID | None = None
    reset_at: datetime | None = None


class BasketResetRepository:
    def __init__(self, db: Session):
        self.db = db

    def read(self, user_id: str, language: str):
        return (
            self.db.query(LanguageSnackBasketResetModel)
            .filter_by(user_id=user_id, content_language=language)
            .populate_existing()
            .first()
        )

    def reset(self, user_id: str, language: str):
        values = {"reset_id": str(uuid4()), "reset_at": utcnow()}
        insert = (
            sqlite_insert if self.db.get_bind().dialect.name == "sqlite" else pg_insert
        )
        statement = insert(LanguageSnackBasketResetModel).values(
            user_id=user_id, content_language=language, **values
        )
        self.db.execute(
            statement.on_conflict_do_update(
                index_elements=["user_id", "content_language"], set_=values
            )
        )
        self.db.commit()
        return self.read(user_id, language)
