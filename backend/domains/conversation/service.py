"""
Conversation Service Layer
비즈니스 로직 및 도메인 규칙
"""
import logging
import traceback
from uuid import uuid4

from config import get_model_for_provider, get_settings
from domains.conversation.enums import ConversationStatus, MessageRole
from domains.conversation.models import ConversationModel, MessageModel
from domains.conversation.repository import ConversationRepository
from domains.conversation.schemas import Conversation, ConversationResponse, Message, MessageResponse
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest

logger = logging.getLogger(__name__)
settings = get_settings()


class ConversationService:
    """대화 서비스"""

    def __init__(self, repository: ConversationRepository):
        self.repository = repository

    async def start_conversation(self, first_message: str, search_context: str | None = None) -> ConversationResponse:
        """
        대화 시작

        Args:
            first_message: 첫 메시지
            search_context: 검색 컨텍스트 (세션 메모리)

        Returns:
            대화 응답
        """
        try:
            # 1. Conversation 생성
            # 첫 메시지를 title로 설정 (최대 50자)
            title = first_message[:50] if len(first_message) <= 50 else first_message[:47] + "..."

            conversation = ConversationModel(
                id=str(uuid4()),
                title=title,
                message_count=0,
                status=ConversationStatus.ACTIVE,
            )
            self.repository.save(conversation)

            # 2. 사용자 메시지 저장
            user_message = MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.USER,
                content=first_message,
            )
            self.repository.save_message(user_message)

            # 3. 시스템 프롬프트 생성
            system_prompt = self.build_system_prompt(first_message, search_context)

            # 4. LLM 응답 생성
            ai_response = await self.generate_response(system_prompt, [], first_message)

            # 5. AI 메시지 저장
            assistant_message = MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.ASSISTANT,
                content=ai_response,
            )
            self.repository.save_message(assistant_message)

            # 6. 메시지 카운트 업데이트
            self.repository.update_message_count(conversation.id, 2)

            return ConversationResponse(
                conversation_id=conversation.id,
                response=ai_response,
                grammar_feedback=None,  # Grammar 모듈에서 처리
            )
        except Exception as e:
            logger.error(f"Error in start_conversation: {str(e)}\n{traceback.format_exc()}")
            raise

    async def continue_conversation(self, conversation_id: str, user_message: str) -> MessageResponse:
        """
        대화 계속하기

        Args:
            conversation_id: 대화 ID
            user_message: 사용자 메시지

        Returns:
            메시지 응답
        """
        try:
            # 1. 대화 조회
            conversation = self.repository.find_by_id(conversation_id)

            # 2. 사용자 메시지 저장
            user_msg = MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.USER,
                content=user_message,
            )
            self.repository.save_message(user_msg)

            # 3. 최근 10턴 조회
            recent_messages = self.repository.get_recent_messages(conversation.id, settings.max_history_turns)

            # 4. 메시지 히스토리 구성
            message_history = self.prepare_message_history(recent_messages[:-1])  # 방금 저장한 메시지 제외

            # 5. 시스템 프롬프트 생성
            system_prompt = self.build_system_prompt(user_message)

            # 6. LLM 응답 생성
            ai_response = await self.generate_response(system_prompt, message_history, user_message)

            # 7. AI 메시지 저장
            assistant_msg = MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.ASSISTANT,
                content=ai_response,
            )
            self.repository.save_message(assistant_msg)

            # 8. 메시지 카운트 업데이트
            new_count = conversation.message_count + 2
            self.repository.update_message_count(conversation.id, new_count)

            return MessageResponse(
                message_id=assistant_msg.id,
                response=ai_response,
                grammar_feedback=None,  # Grammar 모듈에서 처리
                turn_count=new_count // 2,
            )
        except Exception as e:
            logger.error(f"Error in continue_conversation: {str(e)}\n{traceback.format_exc()}")
            raise

    def get_conversation(self, conversation_id: str) -> Conversation:
        """
        대화 조회

        Args:
            conversation_id: 대화 ID

        Returns:
            대화
        """
        conversation = self.repository.find_by_id(conversation_id)
        return Conversation.model_validate(conversation)

    def get_conversations(self, limit: int = 50, offset: int = 0) -> list[Conversation]:
        """
        대화 목록 조회

        Args:
            limit: 조회 개수
            offset: 시작 위치

        Returns:
            대화 목록
        """
        conversations = self.repository.find_all(limit, offset)
        return [Conversation.model_validate(c) for c in conversations]

    def get_messages(self, conversation_id: str, limit: int = 50, offset: int = 0) -> list[Message]:
        """
        메시지 목록 조회

        Args:
            conversation_id: 대화 ID
            limit: 조회 개수
            offset: 시작 위치

        Returns:
            메시지 목록
        """
        messages = self.repository.get_messages(conversation_id, limit, offset)
        return [Message.model_validate(m) for m in messages]

    def end_conversation(self, conversation_id: str) -> None:
        """
        대화 종료

        Args:
            conversation_id: 대화 ID
        """
        self.repository.update_status(conversation_id, ConversationStatus.COMPLETED)

    # LLM 호출
    async def generate_response(
        self, system_prompt: str, message_history: list[dict], user_input: str
    ) -> str:
        """
        LLM 응답 생성

        Args:
            system_prompt: 시스템 프롬프트
            message_history: 메시지 히스토리
            user_input: 사용자 입력

        Returns:
            AI 응답

        Raises:
            RateLimitException: Rate limit 도달
            ExternalAPIException: LLM API 호출 실패
        """
        # Create provider
        provider = LLMProviderFactory.create_provider()

        # Build message list
        messages = [
            LLMMessage(role="system", content=system_prompt),
            *[LLMMessage(role=msg["role"], content=msg["content"]) for msg in message_history],
            LLMMessage(role="user", content=user_input),
        ]

        # Create request with provider-specific model
        request = LLMRequest(
            messages=messages,
            model=get_model_for_provider(),
            max_tokens=settings.max_tokens,
            temperature=settings.temperature,
        )

        # Call provider
        response = await provider.chat_completion(request)
        return response.content

    # Helper 함수
    def build_system_prompt(self, user_message: str, search_context: str | None = None) -> str:
        """
        시스템 프롬프트 구성

        Args:
            user_message: 사용자 메시지
            search_context: 검색 컨텍스트

        Returns:
            시스템 프롬프트
        """
        base_prompt = """You are a helpful English conversation partner.
Your role is to engage in natural, flowing conversations to help users practice English.

Guidelines:
- Speak naturally and conversationally
- Ask follow-up questions to keep the conversation going
- Use varied vocabulary and sentence structures
- Be encouraging and supportive
- Keep responses concise (2-4 sentences)
"""

        if search_context:
            base_prompt += f"\n\nRelevant context:\n{search_context}\n"

        return base_prompt

    def prepare_message_history(self, messages: list[MessageModel], turn_limit: int = 10) -> list[dict]:
        """
        메시지 히스토리 준비

        Args:
            messages: 메시지 목록
            turn_limit: 최대 턴 수

        Returns:
            LLM 포맷의 메시지 히스토리
        """
        # 최근 N턴만 유지
        recent_messages = messages[-(turn_limit * 2) :]

        return [{"role": msg.role.value, "content": msg.content} for msg in recent_messages]
