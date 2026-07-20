"""
Conversation API Router
HTTP 요청/응답 처리
"""
import asyncio
import json
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import StreamingResponse
from pydantic import ValidationError
from sqlalchemy.orm import Session

from config import get_settings
from database import get_db
from domains.auth.dependencies import get_current_user, get_current_user_from_token_param
from domains.auth.models import ProfileModel
from domains.conversation.enums import ConversationType
from domains.conversation.repository import ConversationRepository
from domains.conversation.schemas import (
    Conversation,
    ConversationResponse,
    MessageResponse,
    MultimodalConversationResponse,
    MultimodalMessageResponse,
    PaginatedConversations,
    PaginatedMessages,
    SendMessageRequest,
    StartFreeChatRequest,
    StartRoleplayRequest,
    UpdateTitleRequest,
)
from domains.conversation.service import ConversationService
from domains.voice.schemas import VoiceAudioError, VoiceAudioResponse
from domains.voice.service import VoiceService
from shared.language import ensure_language_context
from shared.exceptions import (
    AppException,
    ExternalAPIException,
    NotFoundException,
    RateLimitException,
    ValidationException,
)
from shared.types import ErrorResponse, SuccessResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/conversations", tags=["conversations"])
settings = get_settings()


FREE_CHAT_REQUEST_BODY_OPENAPI = {
    "content": {
        "application/json": {
            "schema": {
                "type": "object",
                "required": ["first_message"],
                "properties": {
                    "first_message": {"type": "string"},
                    "search_context": {"type": "string", "nullable": True},
                    "topic": {"type": "string", "nullable": True},
                    "conversation_direction": {"type": "string", "nullable": True},
                    "selected_question": {"type": "string", "nullable": True},
                    "include_audio_response": {"type": "boolean", "default": False},
                },
            }
        },
        "multipart/form-data": {
            "schema": {
                "type": "object",
                "properties": {
                    "first_message": {"type": "string"},
                    "text": {"type": "string"},
                    "audio_file": {"type": "string", "format": "binary"},
                    "search_context": {"type": "string"},
                    "topic": {"type": "string"},
                    "conversation_direction": {"type": "string"},
                    "selected_question": {"type": "string"},
                    "include_audio_response": {"type": "boolean", "default": False},
                },
            }
        },
        "application/x-www-form-urlencoded": {
            "schema": {
                "type": "object",
                "properties": {
                    "first_message": {"type": "string"},
                    "text": {"type": "string"},
                    "search_context": {"type": "string"},
                    "topic": {"type": "string"},
                    "conversation_direction": {"type": "string"},
                    "selected_question": {"type": "string"},
                    "include_audio_response": {"type": "boolean", "default": False},
                },
            }
        },
    }
}

TURN_REQUEST_BODY_OPENAPI = {
    "content": {
        "application/json": {
            "schema": {
                "type": "object",
                "properties": {
                    "text": {"type": "string"},
                    "message": {"type": "string"},
                    "include_audio_response": {"type": "boolean", "default": False},
                },
            }
        },
        "multipart/form-data": {
            "schema": {
                "type": "object",
                "properties": {
                    "text": {"type": "string"},
                    "message": {"type": "string"},
                    "audio_file": {"type": "string", "format": "binary"},
                    "include_audio_response": {"type": "boolean", "default": False},
                },
            }
        },
        "application/x-www-form-urlencoded": {
            "schema": {
                "type": "object",
                "properties": {
                    "text": {"type": "string"},
                    "message": {"type": "string"},
                    "include_audio_response": {"type": "boolean", "default": False},
                },
            }
        },
    }
}


# Dependency
def get_conversation_service(db: Session = Depends(get_db)) -> ConversationService:
    """Conversation Service 의존성"""
    from domains.grammar.repository import GrammarRepository

    repository = ConversationRepository(db)
    grammar_repository = GrammarRepository(db)
    return ConversationService(repository, grammar_repository)


def get_voice_service() -> VoiceService:
    """Voice Service 의존성"""
    return VoiceService()


def _parse_bool_form_value(value: object, *, default: bool = False) -> bool:
    """form/json bool 값을 안전하게 변환"""
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"1", "true", "yes", "y", "on"}


def _validation_error_response(exc: ValidationError) -> HTTPException:
    """Pydantic validation error를 FastAPI 422 형태로 변환"""
    return HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail=exc.errors(),
    )


def _is_form_content_type(content_type: str) -> bool:
    """form 요청 여부 확인"""
    return content_type.startswith("multipart/form-data") or content_type.startswith(
        "application/x-www-form-urlencoded"
    )


def _is_json_content_type(content_type: str) -> bool:
    """JSON 요청 여부 확인"""
    return content_type.startswith("application/json")


def _enforce_voice_content_length_limit(http_request: Request) -> None:
    """multipart/form 요청의 body 크기를 form 파싱 전에 1차 제한"""
    content_length = http_request.headers.get("content-length")
    if not content_length:
        return

    try:
        length = int(content_length)
    except ValueError:
        return

    max_bytes = settings.voice_max_upload_mb * 1024 * 1024
    form_overhead_allowance = 1024 * 1024
    if length > max_bytes + form_overhead_allowance:
        raise ValidationException(
            f"request body exceeds {settings.voice_max_upload_mb} MB upload limit.",
            details={"max_upload_mb": settings.voice_max_upload_mb},
        )


def _reject_unsupported_content_type(content_type: str) -> None:
    """지원하지 않는 요청 Content-Type 거절"""
    if _is_json_content_type(content_type) or _is_form_content_type(content_type):
        return
    raise HTTPException(
        status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
        detail=(
            "Unsupported Content-Type. Use application/json, multipart/form-data, "
            "or application/x-www-form-urlencoded."
        ),
    )


async def _parse_free_chat_input(http_request: Request) -> tuple[StartFreeChatRequest, bool, object | None]:
    """JSON 또는 multipart free-chat 시작 요청 파싱"""
    content_type = http_request.headers.get("content-type", "")
    _reject_unsupported_content_type(content_type)

    if _is_form_content_type(content_type):
        _enforce_voice_content_length_limit(http_request)
        form = await http_request.form()
        audio_file = form.get("audio_file")
        include_audio_response = _parse_bool_form_value(form.get("include_audio_response"))
        payload = {
            "first_message": form.get("first_message") or form.get("text") or "",
            "search_context": form.get("search_context"),
            "topic": form.get("topic"),
            "conversation_direction": form.get("conversation_direction"),
            "selected_question": form.get("selected_question"),
        }
        return StartFreeChatRequest.model_validate(payload), include_audio_response, audio_file

    try:
        payload = await http_request.json()
    except json.JSONDecodeError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Malformed JSON body.")
    include_audio_response = _parse_bool_form_value(payload.get("include_audio_response"))
    return StartFreeChatRequest.model_validate(payload), include_audio_response, None


async def _parse_turn_input(http_request: Request) -> tuple[str | None, bool, object | None]:
    """JSON 또는 multipart turn 요청 파싱"""
    content_type = http_request.headers.get("content-type", "")
    _reject_unsupported_content_type(content_type)

    if _is_form_content_type(content_type):
        _enforce_voice_content_length_limit(http_request)
        form = await http_request.form()
        return (
            form.get("text") or form.get("message"),
            _parse_bool_form_value(form.get("include_audio_response")),
            form.get("audio_file"),
        )

    try:
        payload = await http_request.json()
    except json.JSONDecodeError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Malformed JSON body.")
    return (
        payload.get("text") or payload.get("message"),
        _parse_bool_form_value(payload.get("include_audio_response")),
        None,
    )


async def _synthesize_optional_audio(
    *,
    include_audio_response: bool,
    response_text: str,
    voice_service: VoiceService,
) -> tuple[VoiceAudioResponse | None, VoiceAudioError | None]:
    """요청 시 AI 응답 TTS를 생성하고 실패는 응답 필드로 격리"""
    if not include_audio_response:
        return None, None

    try:
        audio = await voice_service.synthesize_response(response_text)
        return audio, None
    except AppException as exc:
        return None, VoiceAudioError(
            message=exc.message,
            provider=voice_service.provider.get_provider_name(),
        )


# Endpoints
@router.post(
    "/start/free-chat/",
    response_model=SuccessResponse[MultimodalConversationResponse],
    openapi_extra={"requestBody": FREE_CHAT_REQUEST_BODY_OPENAPI},
)
async def start_free_chat_conversation(
    http_request: Request,
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
    voice_service: VoiceService = Depends(get_voice_service),
):
    """자유 대화 시작"""
    try:
        request, include_audio_response, audio_file = await _parse_free_chat_input(http_request)
        input_mode, first_message = await voice_service.resolve_input_text(
            text=request.first_message,
            audio_file=audio_file,
        )
        response = await service.start_free_chat_conversation(
            first_message,
            request.search_context,
            user_id=current_user.id,
            topic=request.topic,
            conversation_direction=(
                request.conversation_direction.value
                if request.conversation_direction
                else None
            ),
            selected_question=request.selected_question,
            language_context=ensure_language_context(getattr(current_user, "language", None)),
        )
        audio, audio_error = await _synthesize_optional_audio(
            include_audio_response=include_audio_response,
            response_text=response.response,
            voice_service=voice_service,
        )
        data = MultimodalConversationResponse(
            **response.model_dump(),
            input_mode=input_mode,
            transcript=first_message,
            audio=audio,
            audio_error=audio_error,
        )
        return SuccessResponse(data=data, message="자유 대화가 시작되었습니다")
    except ValidationError as e:
        raise _validation_error_response(e)
    except RateLimitException as e:
        logger.warning(f"RateLimitException in start_free_chat_conversation: {e.message}")
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)
    except ExternalAPIException as e:
        logger.error(f"ExternalAPIException in start_free_chat_conversation: {e.message}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)
    except AppException as e:
        logger.error(f"AppException in start_free_chat_conversation: {e.message}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in start_free_chat_conversation: {str(e)}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.post("/start/roleplay/", response_model=SuccessResponse[ConversationResponse])
async def start_roleplay_conversation(
    request: StartRoleplayRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
):
    """롤플레이 대화 시작 (AI가 먼저 인사)"""
    try:
        response = await service.start_roleplay_conversation(
            request.role_character,
            request.search_context,
            user_id=current_user.id,
            language_context=ensure_language_context(getattr(current_user, "language", None)),
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
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
):
    """메시지 전송"""
    try:
        response = await service.continue_conversation(
            str(conversation_id), request.message, user_id=current_user.id
        )
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


@router.post(
    "/{conversation_id}/turn/",
    response_model=SuccessResponse[MultimodalMessageResponse],
    openapi_extra={"requestBody": TURN_REQUEST_BODY_OPENAPI},
)
async def send_multimodal_turn(
    conversation_id: UUID,
    http_request: Request,
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
    voice_service: VoiceService = Depends(get_voice_service),
):
    """텍스트 또는 음성 파일로 대화 이어가기"""
    try:
        text, include_audio_response, audio_file = await _parse_turn_input(http_request)
        input_mode, user_text = await voice_service.resolve_input_text(
            text=text,
            audio_file=audio_file,
        )
        response = await service.continue_conversation(
            str(conversation_id),
            user_text,
            user_id=current_user.id,
        )
        audio, audio_error = await _synthesize_optional_audio(
            include_audio_response=include_audio_response,
            response_text=response.response,
            voice_service=voice_service,
        )
        data = MultimodalMessageResponse(
            **response.model_dump(),
            input_mode=input_mode,
            transcript=user_text,
            audio=audio,
            audio_error=audio_error,
        )
        return SuccessResponse(data=data)
    except ValidationError as e:
        raise _validation_error_response(e)
    except RateLimitException as e:
        logger.warning(f"RateLimitException in send_multimodal_turn: {e.message}")
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=e.message)
    except ExternalAPIException as e:
        logger.error(f"ExternalAPIException in send_multimodal_turn: {e.message}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=e.message)
    except NotFoundException as e:
        logger.error(f"NotFoundException in send_multimodal_turn: {e.message}")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        logger.error(f"AppException in send_multimodal_turn: {e.message}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in send_multimodal_turn: {str(e)}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get("/", response_model=SuccessResponse[PaginatedConversations])
def get_conversations(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
):
    """대화 목록 조회"""
    try:
        conversations = service.get_conversations(current_user.id, limit, offset)
        return SuccessResponse(data=conversations)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/{conversation_id}/", response_model=SuccessResponse[Conversation])
def get_conversation(
    conversation_id: UUID,
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
):
    """대화 조회"""
    try:
        conversation = service.get_conversation(str(conversation_id), current_user.id)
        return SuccessResponse(data=conversation)
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/{conversation_id}/messages/", response_model=SuccessResponse[PaginatedMessages])
def get_messages(
    conversation_id: UUID,
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
):
    """메시지 목록 조회"""
    try:
        messages = service.get_messages(str(conversation_id), current_user.id, limit, offset)
        return SuccessResponse(data=messages)
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.put("/{conversation_id}/end/", response_model=SuccessResponse[dict])
def end_conversation(
    conversation_id: UUID,
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
):
    """대화 종료"""
    try:
        service.end_conversation(str(conversation_id), current_user.id)
        return SuccessResponse(data={}, message="대화가 종료되었습니다")
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.put("/{conversation_id}/title/", response_model=SuccessResponse[dict])
def update_conversation_title(
    conversation_id: UUID,
    request: UpdateTitleRequest,
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
):
    """대화 제목 수정"""
    try:
        service.update_conversation_title(str(conversation_id), request.title, current_user.id)
        return SuccessResponse(data={}, message="대화 제목이 수정되었습니다")
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.delete("/{conversation_id}/", response_model=SuccessResponse[dict])
def delete_conversation(
    conversation_id: UUID,
    current_user: ProfileModel = Depends(get_current_user),
    service: ConversationService = Depends(get_conversation_service),
):
    """대화 삭제"""
    try:
        service.repository.delete_by_id(str(conversation_id), current_user.id)
        return SuccessResponse(data={}, message="대화가 삭제되었습니다")
    except NotFoundException as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=e.message)
    except AppException as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=e.message)


@router.get("/messages/{message_id}/grammar-feedback/stream")
async def stream_grammar_feedback(
    message_id: UUID,
    current_user: ProfileModel = Depends(get_current_user_from_token_param),
    service: ConversationService = Depends(get_conversation_service),
):
    """선택적 SSE 문법 피드백 스트리밍 (토큰은 쿼리 파라미터로 전달)"""
    try:
        service.repository.ensure_message_belongs_to_user(str(message_id), current_user.id)
    except NotFoundException as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=exc.message)

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
