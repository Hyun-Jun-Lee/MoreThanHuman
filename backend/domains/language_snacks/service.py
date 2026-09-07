"""Language snack 도메인 서비스."""
from datetime import datetime
from uuid import uuid4

from domains.language_snacks.models import LanguageSnackModel
from domains.language_snacks.repository import LanguageSnackRepository
from domains.language_snacks.schemas import LanguageSnackCreate


class LanguageSnackService:
    """언어 스낵의 발행 및 조회 규칙을 담당한다."""

    def __init__(self, repository: LanguageSnackRepository):
        self.repository = repository

    def create(self, request: LanguageSnackCreate) -> LanguageSnackModel:
        """검증된 콘텐츠를 즉시 발행한다."""
        snack = LanguageSnackModel(
            id=str(uuid4()),
            category=request.category,
            left_label=request.left_label,
            left_word=request.left_word,
            right_label=request.right_label,
            right_word=request.right_word,
            meaning=request.meaning,
            example=request.example,
            published_at=datetime.utcnow(),
        )
        return self.repository.save(snack)

    def list_published(self) -> list[LanguageSnackModel]:
        """사용자 언어 설정과 무관한 공통 발행 목록을 조회한다."""
        return self.repository.list_published()
