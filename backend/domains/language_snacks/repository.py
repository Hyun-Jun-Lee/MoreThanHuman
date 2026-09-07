"""Language snack 데이터 접근 계층."""
from sqlalchemy import desc
from sqlalchemy.orm import Session

from domains.language_snacks.models import LanguageSnackModel


class LanguageSnackRepository:
    """언어 스낵 저장소."""

    def __init__(self, db: Session):
        self.db = db

    def save(self, snack: LanguageSnackModel) -> LanguageSnackModel:
        """새 언어 스낵을 저장한다."""
        self.db.add(snack)
        self.db.commit()
        self.db.refresh(snack)
        return snack

    def list_published(self) -> list[LanguageSnackModel]:
        """발행된 스낵만 최신 순서와 안정적인 보조 정렬로 반환한다."""
        return (
            self.db.query(LanguageSnackModel)
            .filter(LanguageSnackModel.published_at.isnot(None))
            .order_by(
                desc(LanguageSnackModel.published_at),
                desc(LanguageSnackModel.id),
            )
            .all()
        )
