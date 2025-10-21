"""
Conversation API Router
HTTP 요청/응답 처리
"""
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from database import get_db
from domains.conversation.models import Conversation, ConversationResponse, Message, MessageResponse
from domains.conversation.repository import ConversationRepository
from domains.conversation.service import ConversationService
from shared.exceptions import AppException, NotFoundException
from shared.types import ErrorResponse, SuccessResponse

router = APIRouter(prefix="/api/conversations", tags=["conversations"])


# Request Models
class StartConversationRequest(BaseModel):
    """대화 시작 요청"""

    first_message: str


class SendMessageRequest(BaseModel):
    """메시지 전송 요청"""

    message: str


# Dependency
def get_conversation_service(db: Session = Depends(get_db)) -> ConversationService:
    """Conversation Service 의존성"""
    repository = ConversationRepository(db)
    return ConversationService(repository)


# Endpoints
@router.post("/start/", response_model=SuccessResponse[ConversationResponse])
async def start_conversation(
    request: StartConversationRequest,
    service: ConversationService = Depends(get_conversation_service),
):
    """
    새 대화 시작

    Args:
        request: 대화 시작 요청
        service: Conversation Service

    Returns:
        대화 응답
    """
    try:
        response = await service.start_conversation(request.first_message)
        return SuccessResponse(data=response, message="대화가 시작되었습니다")
    except AppException as e:
        logger.error(f"AppException in start_conversation: {e.message}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)
    except Exception as e:
        logger.error(f"Unexpected error in start_conversation: {str(e)}", exc_info=True)
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
