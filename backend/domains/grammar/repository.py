"""
Grammar Repository Layer
"""
from datetime import datetime, timedelta
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from backend.domains.grammar.models import GrammarFeedbackModel
from backend.shared.exceptions import NotFoundException


class GrammarRepository:
    """문법 저장소"""

    def __init__(self, db: Session):
        self.db = db

    def save(self, feedback: GrammarFeedbackModel) -> GrammarFeedbackModel:
        """
        피드백 저장

        Args:
            feedback: 문법 피드백 모델

        Returns:
            저장된 피드백
        """
        self.db.add(feedback)
        self.db.commit()
        self.db.refresh(feedback)
        return feedback

    def find_by_id(self, feedback_id: UUID) -> GrammarFeedbackModel:
        """
        ID로 피드백 조회

        Args:
            feedback_id: 피드백 ID

        Returns:
            피드백 모델

        Raises:
            NotFoundException: 피드백을 찾을 수 없을 때
        """
        feedback = self.db.query(GrammarFeedbackModel).filter(GrammarFeedbackModel.id == feedback_id).first()
        if not feedback:
            raise NotFoundException(f"Grammar feedback {feedback_id} not found")
        return feedback

    def find_by_message_id(self, message_id: UUID) -> GrammarFeedbackModel:
        """
        메시지 ID로 피드백 조회

        Args:
            message_id: 메시지 ID

        Returns:
            피드백 모델

        Raises:
            NotFoundException: 피드백을 찾을 수 없을 때
        """
        feedback = self.db.query(GrammarFeedbackModel).filter(GrammarFeedbackModel.message_id == message_id).first()
        if not feedback:
            raise NotFoundException(f"Grammar feedback for message {message_id} not found")
        return feedback

    def get_stats(self, time_range: str | None = None) -> dict:
        """
        문법 통계 조회

        Args:
            time_range: 시간 범위 ("7d", "30d", "90d", "all")

        Returns:
            통계 데이터
        """
        query = self.db.query(GrammarFeedbackModel)

        # 시간 범위 필터
        if time_range and time_range != "all":
            days = int(time_range.rstrip("d"))
            start_date = datetime.utcnow() - timedelta(days=days)
            query = query.filter(GrammarFeedbackModel.created_at >= start_date)

        # 전체 메시지 수
        total_messages = query.count()

        # 에러가 있는 메시지 수
        messages_with_errors = query.filter(GrammarFeedbackModel.has_errors == True).count()

        # 에러율 계산
        error_rate = messages_with_errors / total_messages if total_messages > 0 else 0.0

        return {
            "total_messages": total_messages,
            "messages_with_errors": messages_with_errors,
            "error_rate": error_rate,
        }
