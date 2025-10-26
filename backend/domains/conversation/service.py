"""
Conversation Service Layer
비즈니스 로직 및 도메인 규칙
"""
import asyncio
import logging
import traceback
from uuid import uuid4

from config import get_model_for_provider, get_settings
from domains.conversation.enums import ConversationStatus, ConversationType, MessageRole
from domains.conversation.models import ConversationModel, MessageModel
from domains.conversation.repository import ConversationRepository
from domains.conversation.schemas import Conversation, ConversationResponse, Message, MessageResponse
from domains.grammar.repository import GrammarRepository
from domains.grammar.service import GrammarService
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest

logger = logging.getLogger(__name__)
settings = get_settings()


class ConversationService:
    """대화 서비스"""

    def __init__(self, repository: ConversationRepository, grammar_repository: GrammarRepository):
        self.repository = repository
        self.grammar_service = GrammarService(grammar_repository)

    async def start_conversation(
        self,
        first_message: str,
        search_context: str | None = None,
        conversation_type: ConversationType = ConversationType.FREE_CHAT,
        role_character: str | None = None
    ) -> ConversationResponse:
        """
        대화 시작

        Args:
            first_message: 첫 메시지
            search_context: 검색 컨텍스트 (세션 메모리)
            conversation_type: 대화 타입 (자유 대화 또는 롤플레이)
            role_character: 롤플레이 캐릭터 (예: "카페 바리스타", "영어 선생님")

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
                conversation_type=conversation_type,
                role_character=role_character,
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
            system_prompt = self.build_system_prompt(search_context, conversation_type, role_character)

            # 4. LLM 응답 생성과 문법 체크를 병렬로 실행 (첫 메시지이므로 이전 AI 메시지 없음)
            results = await asyncio.gather(
                self.generate_response(system_prompt, [], first_message),
                self.grammar_service.check_grammar(first_message, previous_ai_message=None),
                return_exceptions=True
            )

            ai_response = results[0]
            grammar_feedback = None
            if not isinstance(results[1], Exception):
                # 문법 피드백 DB에 저장
                feedback_result = results[1]
                await self.grammar_service.save_feedback(user_message.id, feedback_result)
                grammar_feedback = feedback_result.model_dump()

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
                conversation_type=conversation.conversation_type,
                role_character=conversation.role_character,
                response=ai_response,
                grammar_feedback=grammar_feedback,
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
            system_prompt = self.build_system_prompt(
                None,  # search_context는 첫 대화에만 사용
                conversation.conversation_type,
                conversation.role_character
            )

            # 6. 바로 전 AI 메시지 찾기 (문법 체크 맥락용)
            previous_ai_message = None
            # 방금 저장한 user_msg 제외하고 마지막 assistant 메시지 찾기
            for msg in reversed(recent_messages[:-1]):
                if msg.role == MessageRole.ASSISTANT:
                    previous_ai_message = msg.content
                    break

            # 7. LLM 응답 생성과 문법 체크를 병렬로 실행
            results = await asyncio.gather(
                self.generate_response(system_prompt, message_history, user_message),
                self.grammar_service.check_grammar(user_message, previous_ai_message),
                return_exceptions=True
            )

            ai_response = results[0]
            grammar_feedback = None
            if not isinstance(results[1], Exception):
                # 문법 피드백 DB에 저장
                feedback_result = results[1]
                await self.grammar_service.save_feedback(user_msg.id, feedback_result)
                grammar_feedback = feedback_result.model_dump()
            else:
                # 디버깅용 로그
                logger.error(f"Grammar check error: {type(results[1]).__name__}: {str(results[1])}")

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
                grammar_feedback=grammar_feedback,
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
        result = []
        for m in messages:
            # MessageModel을 dict로 변환
            msg_dict = {
                "id": m.id,
                "conversation_id": m.conversation_id,
                "role": m.role,
                "content": m.content,
                "created_at": m.created_at,
                "grammar_feedback": None
            }

            # grammar_feedback가 있으면 dict로 변환
            if m.grammar_feedback:
                from domains.grammar.schemas import GrammarFeedback
                msg_dict["grammar_feedback"] = GrammarFeedback.model_validate(m.grammar_feedback).model_dump()

            result.append(Message.model_validate(msg_dict))

        return result

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
    def build_system_prompt(
        self,
        search_context: str | None = None,
        conversation_type: ConversationType = ConversationType.FREE_CHAT,
        role_character: str | None = None
    ) -> str:
        """
        대화 타입에 따라 다른 시스템 프롬프트 생성

        Args:
            search_context: 검색 컨텍스트
            conversation_type: 대화 타입
            role_character: 롤플레이 캐릭터

        Returns:
            시스템 프롬프트
        """
        if conversation_type == ConversationType.ROLE_PLAYING:
            return self.build_roleplay_prompt(role_character, search_context)
        else:
            return self.build_free_chat_prompt(search_context)

    def build_roleplay_prompt(self, role_character: str, search_context: str | None = None) -> str:
        """롤플레이용 시스템 프롬프트"""

        base_prompt = f"""You are an English conversation practice partner playing the role of '{role_character}'.

        ## Role Guidelines:
        1. Always speak naturally from the perspective of '{role_character}'
        2. Use vocabulary and expressions appropriate for this role
        3. Lead the conversation immersively as if in a real situation

        ## Conversation Rules:
        - Continue the conversation with natural questions appropriate to the situation
        - Create realistic scenarios that fit the role
        - **IMPORTANT: Keep responses short - maximum 3 sentences**

        ## Scenario Examples:
        - Cafe Barista: Greeting customers, explaining and recommending menu items, taking orders, chatting during drink preparation, payment and closing
        - Interviewer: Welcoming candidates, requesting self-introduction, asking about experience and career, evaluating problem-solving skills in various situations, providing time for questions
        - English Teacher: Practicing daily conversation, introducing new expressions, explaining grammar, correcting pronunciation, reviewing homework and providing feedback
        - Hotel Front Desk: Check-in procedures, room information, introducing hotel facilities, handling requests, check-out and feedback
        """

        if search_context:
            base_prompt += f"\n\n## Reference Information:\n{search_context}"

        return base_prompt

    def build_free_chat_prompt(self, search_context: str | None = None) -> str:
        """자유 대화용 시스템 프롬프트"""

        base_prompt = """You are a friendly and helpful English conversation learning assistant.

        ## Role:
        - Help users learn by having natural English conversations
        - Answer questions about grammar and expressions
        - Teach practical English expressions

        ## Conversation Style:
        - Always communicate in English only
        - Actively utilize reference information when available
        - Use natural and fluent English expressions
        - Proceed like a real conversation
        - **IMPORTANT: Keep responses very short - maximum 3 sentences**
        """

        if search_context:
            base_prompt += f"\n\n## Reference Information:\n{search_context}"

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
