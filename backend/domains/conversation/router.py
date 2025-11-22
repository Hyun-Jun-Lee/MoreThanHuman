"""
Conversation API Router
HTTP 요청/응답 처리
"""
import asyncio
import json
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from database import get_db
from domains.conversation.enums import ConversationType
from domains.conversation.repository import ConversationRepository
from domains.conversation.schemas import Conversation, ConversationResponse, Message, MessageResponse
from domains.conversation.service import ConversationService
from shared.exceptions import AppException, NotFoundException, RateLimitException
from shared.types import ErrorResponse, SuccessResponse

router = APIRouter(prefix="/api/conversations", tags=["conversations"])


# Request Models
class StartFreeChatRequest(BaseModel):
    """자유 대화 시작 요청"""

    first_message: str
    search_context: str | None = None


class StartRoleplayRequest(BaseModel):
    """롤플레이 대화 시작 요청"""

    role_character: str
    search_context: str | None = None


class SendMessageRequest(BaseModel):
    """메시지 전송 요청"""

    message: str


class UpdateTitleRequest(BaseModel):
    """대화 제목 수정 요청"""

    title: str


# Dependency
def get_conversation_service(db: Session = Depends(get_db)) -> ConversationService:
    """Conversation Service 의존성"""
    from domains.grammar.repository import GrammarRepository

    repository = ConversationRepository(db)
    grammar_repository = GrammarRepository(db)
    return ConversationService(repository, grammar_repository)


# Endpoints
@router.post("/start/free-chat/", response_model=SuccessResponse[ConversationResponse])
async def start_free_chat_conversation(
    request: StartFreeChatRequest,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    자유 대화 시작

    Args:
        request: 자유 대화 시작 요청
        service: Conversation Service

    Returns:
        대화 응답
    """
    try:
        response = await service.start_free_chat_conversation(
            request.first_message,
            request.search_context
        )
        return SuccessResponse(data=response, message="자유 대화가 시작되었습니다")
    except RateLimitException as e:
        logger.warning(f"RateLimitException in start_free_chat_conversation: {e.message}")
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)
    except AppException as e:
        logger.error(f"AppException in start_free_chat_conversation: {e.message}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)
    except Exception as e:
        logger.error(f"Unexpected error in start_free_chat_conversation: {str(e)}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/start/roleplay/", response_model=SuccessResponse[ConversationResponse])
async def start_roleplay_conversation(
    request: StartRoleplayRequest,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    롤플레이 대화 시작 (AI가 먼저 인사)

    Args:
        request: 롤플레이 시작 요청
        service: Conversation Service

    Returns:
        대화 응답
    """
    try:
        response = await service.start_roleplay_conversation(
            request.role_character,
            request.search_context
        )
        return SuccessResponse(data=response, message="롤플레이 대화가 시작되었습니다")
    except RateLimitException as e:
        logger.warning(f"RateLimitException in start_roleplay_conversation: {e.message}")
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)
    except AppException as e:
        logger.error(f"AppException in start_roleplay_conversation: {e.message}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)
    except Exception as e:
        logger.error(f"Unexpected error in start_roleplay_conversation: {str(e)}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/{conversation_id}/message/", response_model=SuccessResponse[MessageResponse])
async def send_message(
    conversation_id: UUID,
    request: SendMessageRequest,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    메시지 전송

    Args:
        conversation_id: 대화 ID
        request: 메시지 요청
        service: Conversation Service

    Returns:
        메시지 응답
    """
    try:
        response = await service.continue_conversation(str(conversation_id), request.message)
        return SuccessResponse(data=response)
    except RateLimitException as e:
        logger.warning(f"RateLimitException in send_message: {e.message}")
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)
    except NotFoundException as e:
        logger.error(f"NotFoundException in send_message: {e.message}")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        logger.error(f"AppException in send_message: {e.message}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)
    except Exception as e:
        logger.error(f"Unexpected error in send_message: {str(e)}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/", response_model=SuccessResponse[list[Conversation]])
def get_conversations(
    limit: int = 50,
    offset: int = 0,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    대화 목록 조회

    Args:
        limit: 조회 개수
        offset: 시작 위치
        service: Conversation Service

    Returns:
        대화 목록
    """
    try:
        conversations = service.get_conversations(limit, offset)
        return SuccessResponse(data=conversations)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/{conversation_id}/", response_model=SuccessResponse[Conversation])
def get_conversation(
    conversation_id: UUID,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    대화 조회

    Args:
        conversation_id: 대화 ID
        service: Conversation Service

    Returns:
        대화
    """
    try:
        conversation = service.get_conversation(str(conversation_id))
        return SuccessResponse(data=conversation)
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/{conversation_id}/messages/", response_model=SuccessResponse[list[Message]])
def get_messages(
    conversation_id: UUID,
    limit: int = 50,
    offset: int = 0,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    메시지 목록 조회

    Args:
        conversation_id: 대화 ID
        limit: 조회 개수
        offset: 시작 위치
        service: Conversation Service

    Returns:
        메시지 목록
    """
    try:
        messages = service.get_messages(str(conversation_id), limit, offset)
        return SuccessResponse(data=messages)
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.put("/{conversation_id}/end/", response_model=SuccessResponse[dict])
def end_conversation(
    conversation_id: UUID,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    대화 종료

    Args:
        conversation_id: 대화 ID
        service: Conversation Service

    Returns:
        성공 응답
    """
    try:
        service.end_conversation(str(conversation_id))
        return SuccessResponse(data={}, message="대화가 종료되었습니다")
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.put("/{conversation_id}/title/", response_model=SuccessResponse[dict])
def update_conversation_title(
    conversation_id: UUID,
    request: UpdateTitleRequest,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    대화 제목 수정

    Args:
        conversation_id: 대화 ID
        request: 제목 수정 요청
        service: Conversation Service

    Returns:
        성공 응답
    """
    try:
        service.update_conversation_title(str(conversation_id), request.title)
        return SuccessResponse(data={}, message="대화 제목이 수정되었습니다")
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.delete("/{conversation_id}/", response_model=SuccessResponse[dict])
def delete_conversation(
    conversation_id: UUID,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    대화 삭제

    Args:
        conversation_id: 대화 ID
        service: Conversation Service

    Returns:
        성공 응답
    """
    try:
        service.repository.delete_by_id(str(conversation_id))
        return SuccessResponse(data={}, message="대화가 삭제되었습니다")
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/messages/{message_id}/grammar-feedback/stream")
async def stream_grammar_feedback(
    message_id: UUID,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    SSE로 문법 피드백 스트리밍

    Args:
        message_id: 사용자 메시지 ID
        service: Conversation Service

    Returns:
        SSE 스트림
    """
    async def event_generator():
        """SSE 이벤트 생성기"""
        max_wait_seconds = 20  # 최대 20초 대기
        check_interval = 1
        elapsed = 0

        try:
            while elapsed < max_wait_seconds:
                # DB에서 문법 피드백 조회
                from domains.grammar.repository import GrammarRepository
                from database import get_db

                # DB 세션을 컨텍스트 매니저로 관리하여 자동으로 닫기
                db = next(get_db())
                try:
                    grammar_repo = GrammarRepository(db)

                    try:
                        feedback = grammar_repo.find_by_message_id(str(message_id))
                        # 문법 피드백 발견 - JSON으로 변환하여 전송
                        from domains.grammar.schemas import GrammarFeedback
                        feedback_data = GrammarFeedback.model_validate(feedback).model_dump_json()
                        yield f"data: {feedback_data}\n\n"
                        break
                    except NotFoundException:
                        # 아직 생성 중 - 정상적인 대기 상태, 계속 polling
                        pass
                finally:
                    # DB 세션 명시적으로 닫기
                    db.close()

                # 아직 없으면 대기
                await asyncio.sleep(check_interval)
                elapsed += check_interval

            # 타임아웃 또는 완료 후 연결 종료
            if elapsed >= max_wait_seconds:
                # 타임아웃 - 빈 응답 전송
                logger.warning(f"Grammar feedback timeout for message {message_id} after {max_wait_seconds}s")
                timeout_data = {'timeout': True}
                yield f"data: {json.dumps(timeout_data)}\n\n"

        except Exception as e:
            # NotFoundException이 아닌 실제 에러만 여기서 처리
            logger.error(f"SSE stream error for message {message_id}: {str(e)}", exc_info=True)
            error_data = {'error': str(e)}
            yield f"data: {json.dumps(error_data)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # Nginx 버퍼링 비활성화
        }
    )
