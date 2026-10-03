"""인증된 사용자의 주간 추천 목록."""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database import get_db
from domains.auth.dependencies import get_current_user
from domains.auth.models import ProfileModel
from domains.conversation.schemas import WeeklyTopicItem, WeeklyTopicsResponse
from domains.conversation.topic_repository import WeeklyTopicRepository
from shared.types import SuccessResponse

router = APIRouter(prefix="/api/conversation-topics", tags=["conversation-topics"])


@router.get("/weekly/", response_model=SuccessResponse[WeeklyTopicsResponse])
def weekly_topics(
    current_user: ProfileModel = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    language = current_user.language
    week, topics = WeeklyTopicRepository(db).latest(
        language.native_language.value, language.target_language.value
    )
    return SuccessResponse(data=WeeklyTopicsResponse(
        week_start=week.isoformat() if week else None,
        topics=[WeeklyTopicItem(id=topic.id, text=topic.text) for topic in topics],
    ))
