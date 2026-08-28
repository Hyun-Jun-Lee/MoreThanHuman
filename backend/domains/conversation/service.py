"""
Conversation Service Layer
비즈니스 로직 및 도메인 규칙
"""
import asyncio
import logging
import traceback
from uuid import uuid4

from config import get_model_for_provider, get_settings
from domains.conversation.enums import ConversationStatus, ConversationType, MessageRole, RoleplayDifficulty
from domains.conversation.models import ConversationModel, MessageModel
from domains.conversation.repository import ConversationRepository
from domains.conversation.schemas import (
    Conversation,
    ConversationResponse,
    Message,
    MessageResponse,
    PaginatedConversations,
    PaginatedMessages,
    Pagination,
)
from domains.grammar.repository import GrammarRepository
from domains.grammar.service import GrammarService
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest
from shared.language import (
    LanguageCode,
    LearningLanguageContext,
    ensure_language_context,
    language_name,
)
from shared.language_prompt_policy import format_practice_priorities

logger = logging.getLogger(__name__)
settings = get_settings()
ROLEPLAY_TITLE_MAX_LENGTH = 200


class ConversationService:
    """대화 서비스"""

    def __init__(self, repository: ConversationRepository, grammar_repository: GrammarRepository):
        self.repository = repository
        self.grammar_service = GrammarService(grammar_repository)

    async def process_grammar_feedback_background(
        self,
        user_message_id: str,
        user_message: str,
        previous_ai_message: str | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> None:
        """
        백그라운드에서 문법 체크 실행 및 저장

        Args:
            user_message_id: 사용자 메시지 ID
            user_message: 사용자 메시지 내용
            previous_ai_message: 이전 AI 메시지 (맥락용)
        """
        try:
            # 문법 체크 실행
            feedback = await self.grammar_service.check_grammar(
                user_message,
                previous_ai_message,
                language_context=ensure_language_context(language_context),
            )

            # DB에 저장
            await self.grammar_service.save_feedback(user_message_id, feedback)

            logger.info(f"Grammar feedback saved for message {user_message_id}")
        except Exception as e:
            # 백그라운드 태스크 실패는 로깅만 하고 계속 진행
            logger.error(f"Background grammar check failed: {str(e)}\n{traceback.format_exc()}")

    async def start_free_chat_conversation(
        self,
        first_message: str,
        search_context: str | None = None,
        user_id: str = "",
        topic: str | None = None,
        conversation_direction: str | None = None,
        selected_question: str | None = None,
        custom_focus: str | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> ConversationResponse:
        """
        자유 대화 시작

        Args:
            first_message: 첫 메시지
            search_context: 검색 컨텍스트 (세션 메모리)
            user_id: 사용자 ID
            topic: 준비 카드 주제
            conversation_direction: 선택한 대화 방향
            selected_question: 사용자가 답변하기로 선택한 첫 질문

        Returns:
            대화 응답
        """
        try:
            # 1. Conversation 생성
            language_context = ensure_language_context(language_context)
            title = first_message[:50] if len(first_message) <= 50 else first_message[:47] + "..."

            conversation = ConversationModel(
                id=str(uuid4()),
                user_id=user_id,
                title=title,
                conversation_type=ConversationType.FREE_CHAT,
                role_character=None,
                native_language=language_context.native_language.value,
                target_language=language_context.target_language.value,
                feedback_language=language_context.feedback_language.value,
                message_count=0,
                status=ConversationStatus.ACTIVE,
            )
            self.repository.save(conversation)

            # 2. 시스템 프롬프트 생성
            system_prompt = self.build_system_prompt(
                search_context,
                ConversationType.FREE_CHAT,
                None,
                topic=topic,
                conversation_direction=conversation_direction,
                selected_question=selected_question,
                custom_focus=custom_focus,
                language_context=language_context,
            )

            # 3. 사용자 메시지 저장
            user_message = MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.USER,
                content=first_message,
            )
            self.repository.save_message(user_message)

            # 4. AI 응답만 먼저 생성 (문법 체크는 백그라운드에서 처리)
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
            self.repository.update_message_count(conversation.id, user_id, 2)

            # 7. 백그라운드에서 문법 체크 실행 (첫 메시지이므로 이전 AI 메시지 없음)
            asyncio.create_task(
                self.process_grammar_feedback_background(
                    user_message.id,
                    first_message,
                    previous_ai_message=None,
                    language_context=language_context,
                )
            )

            # 8. AI 응답 즉시 반환 (grammar_feedback=None)
            return ConversationResponse(
                conversation_id=conversation.id,
                message_id=user_message.id,
                conversation_type=ConversationType.FREE_CHAT,
                role_character=None,
                language=language_context,
                response=ai_response,
                grammar_feedback=None,  # 백그라운드에서 처리 중
            )
        except Exception as e:
            logger.error(f"Error in start_free_chat_conversation: {str(e)}\n{traceback.format_exc()}")
            raise

    async def start_roleplay_conversation(
        self,
        role_character: str,
        search_context: str | None = None,
        user_id: str = "",
        roleplay_difficulty: RoleplayDifficulty | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> ConversationResponse:
        """
        롤플레이 대화 시작 (AI가 먼저 인사)

        Args:
            role_character: 롤플레이 캐릭터 (예: "카페 바리스타", "영어 선생님")
            search_context: 검색 컨텍스트 (세션 메모리)
            user_id: 사용자 ID

        Returns:
            대화 응답
        """
        try:
            # 1. Conversation 생성
            language_context = ensure_language_context(language_context)
            roleplay_difficulty = self._resolve_roleplay_difficulty(roleplay_difficulty)
            title = self._roleplay_title(role_character)

            conversation = ConversationModel(
                id=str(uuid4()),
                user_id=user_id,
                title=title,
                conversation_type=ConversationType.ROLE_PLAYING,
                role_character=role_character,
                roleplay_difficulty=roleplay_difficulty,
                native_language=language_context.native_language.value,
                target_language=language_context.target_language.value,
                feedback_language=language_context.feedback_language.value,
                message_count=0,
                status=ConversationStatus.ACTIVE,
            )
            self.repository.save(conversation)

            # 2. 시스템 프롬프트 생성
            system_prompt = self.build_system_prompt(
                search_context,
                ConversationType.ROLE_PLAYING,
                role_character,
                roleplay_difficulty=roleplay_difficulty,
                language_context=language_context,
            )

            # 3. AI의 첫 인사 생성
            target_name = language_name(language_context.target_language)
            greeting_prompt = (
                f"You are starting a role-play as '{role_character}'. "
                f"Use this difficulty style: {self._roleplay_difficulty_instruction(roleplay_difficulty)}. "
                f"Greet the user naturally in {target_name} and start the conversation "
                "as this character would. Keep it short (1-2 sentences)."
            )
            ai_response = await self.generate_response(system_prompt, [], greeting_prompt)

            # 4. AI 메시지만 저장 (사용자 메시지 없음)
            assistant_message = MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.ASSISTANT,
                content=ai_response,
            )
            self.repository.save_message(assistant_message)

            # 5. 메시지 카운트 업데이트 (AI 메시지 1개)
            self.repository.update_message_count(conversation.id, user_id, 1)

            # 6. 롤플레이 시작이므로 grammar_feedback 없음
            return ConversationResponse(
                conversation_id=conversation.id,
                message_id=assistant_message.id,
                conversation_type=ConversationType.ROLE_PLAYING,
                role_character=role_character,
                roleplay_difficulty=roleplay_difficulty,
                language=language_context,
                response=ai_response,
                grammar_feedback=None,
            )
        except Exception as e:
            logger.error(f"Error in start_roleplay_conversation: {str(e)}\n{traceback.format_exc()}")
            raise

    async def continue_conversation(self, conversation_id: str, user_message: str, user_id: str = "") -> MessageResponse:
        """
        대화 계속하기

        Args:
            conversation_id: 대화 ID
            user_message: 사용자 메시지
            user_id: 사용자 ID

        Returns:
            메시지 응답
        """
        try:
            # 1. 대화 조회
            conversation = self.repository.find_by_id(conversation_id, user_id)
            language_context = conversation.language

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
                conversation.role_character,
                roleplay_difficulty=conversation.roleplay_difficulty,
                language_context=language_context,
            )

            # 6. 바로 전 AI 메시지 찾기 (문법 체크 맥락용)
            previous_ai_message = None
            # 방금 저장한 user_msg 제외하고 마지막 assistant 메시지 찾기
            for msg in reversed(recent_messages[:-1]):
                if msg.role == MessageRole.ASSISTANT:
                    previous_ai_message = msg.content
                    break

            # 7. AI 응답만 먼저 생성 (문법 체크는 백그라운드에서 처리)
            ai_response = await self.generate_response(system_prompt, message_history, user_message)

            # 8. AI 메시지 저장
            assistant_msg = MessageModel(
                id=str(uuid4()),
                conversation_id=conversation.id,
                role=MessageRole.ASSISTANT,
                content=ai_response,
            )
            self.repository.save_message(assistant_msg)

            # 9. 메시지 카운트 업데이트
            new_count = conversation.message_count + 2
            self.repository.update_message_count(conversation.id, user_id, new_count)

            # 10. 백그라운드에서 문법 체크 실행 (응답 반환에 영향 없음)
            asyncio.create_task(
                self.process_grammar_feedback_background(
                    user_msg.id,
                    user_message,
                    previous_ai_message,
                    language_context=language_context,
                )
            )

            # 11. AI 응답 즉시 반환 (grammar_feedback=None)
            return MessageResponse(
                message_id=user_msg.id,  # 사용자 메시지 ID (SSE로 문법 피드백 연결할 때 사용)
                response=ai_response,
                grammar_feedback=None,  # 백그라운드에서 처리 중
                turn_count=new_count // 2,
            )
        except Exception as e:
            logger.error(f"Error in continue_conversation: {str(e)}\n{traceback.format_exc()}")
            raise

    def get_conversation(self, conversation_id: str, user_id: str) -> Conversation:
        """
        대화 조회

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID

        Returns:
            대화
        """
        conversation = self.repository.find_by_id(conversation_id, user_id)
        return Conversation.model_validate(conversation)

    @staticmethod
    def _build_pagination(*, limit: int, offset: int, total_count: int, current_count: int) -> Pagination:
        has_more = (offset + current_count) < total_count
        return Pagination(
            limit=limit,
            offset=offset,
            total_count=total_count,
            has_more=has_more,
            next_offset=offset + current_count,
        )

    def get_conversations(self, user_id: str, limit: int = 50, offset: int = 0) -> PaginatedConversations:
        """
        대화 목록 조회

        Args:
            user_id: 사용자 ID
            limit: 조회 개수
            offset: 시작 위치

        Returns:
            대화 목록
        """
        conversations = self.repository.find_all(user_id, limit, offset)
        total_count = self.repository.count_conversations(user_id)
        results = [Conversation.model_validate(c) for c in conversations]
        pagination = self._build_pagination(
            limit=limit,
            offset=offset,
            total_count=total_count,
            current_count=len(results),
        )
        return PaginatedConversations(results=results, pagination=pagination)

    def get_messages(self, conversation_id: str, user_id: str, limit: int = 50, offset: int = 0) -> PaginatedMessages:
        """
        메시지 목록 조회

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID
            limit: 조회 개수
            offset: 시작 위치

        Returns:
            메시지 목록
        """
        # user_id 검증
        self.repository.find_by_id(conversation_id, user_id)
        messages = self.repository.get_messages(conversation_id, limit, offset)
        results = []
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

            results.append(Message.model_validate(msg_dict))

        total_count = self.repository.count_messages(conversation_id)
        pagination = self._build_pagination(
            limit=limit,
            offset=offset,
            total_count=total_count,
            current_count=len(results),
        )
        return PaginatedMessages(results=results, pagination=pagination)

    def end_conversation(self, conversation_id: str, user_id: str) -> None:
        """
        대화 종료

        Args:
            conversation_id: 대화 ID
            user_id: 사용자 ID
        """
        self.repository.update_status(conversation_id, user_id, ConversationStatus.COMPLETED)

    def update_conversation_title(self, conversation_id: str, title: str, user_id: str = "") -> None:
        """
        대화 제목 업데이트

        Args:
            conversation_id: 대화 ID
            title: 새로운 제목
            user_id: 사용자 ID
        """
        self.repository.update_title(conversation_id, user_id, title)

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
        role_character: str | None = None,
        roleplay_difficulty: RoleplayDifficulty | None = None,
        topic: str | None = None,
        conversation_direction: str | None = None,
        selected_question: str | None = None,
        custom_focus: str | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> str:
        """
        대화 타입에 따라 다른 시스템 프롬프트 생성

        Args:
            search_context: 검색 컨텍스트
            conversation_type: 대화 타입
            role_character: 롤플레이 캐릭터
            topic: 준비 카드 주제
            conversation_direction: 선택한 대화 방향
            selected_question: 사용자가 답변하기로 선택한 첫 질문

        Returns:
            시스템 프롬프트
        """
        language_context = ensure_language_context(language_context)
        if conversation_type == ConversationType.ROLE_PLAYING:
            return self.build_roleplay_prompt(
                role_character,
                search_context,
                roleplay_difficulty=roleplay_difficulty,
                language_context=language_context,
            )
        else:
            return self.build_free_chat_prompt(
                search_context,
                topic=topic,
                conversation_direction=conversation_direction,
                selected_question=selected_question,
                custom_focus=custom_focus,
                language_context=language_context,
            )

    def build_roleplay_prompt(
        self,
        role_character: str,
        search_context: str | None = None,
        roleplay_difficulty: RoleplayDifficulty | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> str:
        """롤플레이용 시스템 프롬프트"""
        language_context = ensure_language_context(language_context)
        target_name = language_name(language_context.target_language)
        feedback_name = language_name(language_context.feedback_language)
        native_name = language_name(language_context.native_language)

        scenario_examples = self._roleplay_scenario_examples(language_context)
        practice_priorities = format_practice_priorities(language_context.target_language)
        difficulty = self._resolve_roleplay_difficulty(roleplay_difficulty)
        difficulty_instruction = self._roleplay_difficulty_instruction(difficulty)

        base_prompt = f"""You are a {target_name} conversation practice partner playing the role of '{role_character}'.

        ## Learner Language Context:
        - Native language: {native_name}
        - Practice target language: {target_name}
        - Feedback/explanation language: {feedback_name}

        ## Target Language Practice Priorities:
{practice_priorities}

        ## Role Guidelines:
        1. Always speak naturally from the perspective of '{role_character}'
        2. Use vocabulary and expressions appropriate for this role
        3. Lead the conversation immersively as if in a real situation

        ## Roleplay Difficulty:
        - Selected difficulty: {difficulty.value}
        - Style: {difficulty_instruction}

        ## Conversation Rules:
        - Always communicate in {target_name}
        - Use {feedback_name} only for brief explanations when the learner needs help
        - Continue the conversation with natural questions appropriate to the situation
        - Create realistic scenarios that fit the role
        - **IMPORTANT: Keep responses short - maximum 3 sentences**

        ## Scenario Examples:
{scenario_examples}
        """

        if search_context:
            base_prompt += f"\n\n## Reference Information:\n{search_context}"

        return base_prompt

    def _resolve_roleplay_difficulty(self, roleplay_difficulty: RoleplayDifficulty | None) -> RoleplayDifficulty:
        """기존 클라이언트/데이터의 누락 값을 Normal로 보정"""
        return roleplay_difficulty or RoleplayDifficulty.NORMAL

    def _roleplay_difficulty_instruction(self, roleplay_difficulty: RoleplayDifficulty) -> str:
        """롤플레이 난이도를 prompt 스타일 지침으로 변환"""
        return {
            RoleplayDifficulty.EASY: "uses short prompts, clear context, and a gentle pace",
            RoleplayDifficulty.NORMAL: "keeps everyday pacing and asks useful follow-up questions",
            RoleplayDifficulty.CHALLENGE: (
                "asks unexpected follow-up questions and encourages longer, more precise answers"
            ),
        }[roleplay_difficulty]

    def _roleplay_title(self, role_character: str) -> str:
        """Roleplay title을 DB title 길이 안에 맞춤"""
        title = f"Role: {role_character}"
        if len(title) <= ROLEPLAY_TITLE_MAX_LENGTH:
            return title
        return title[: ROLEPLAY_TITLE_MAX_LENGTH - 3] + "..."

    def _roleplay_scenario_examples(self, language_context: LearningLanguageContext) -> str:
        """목표 언어에 맞는 롤플레이 예시 목록"""
        if language_context.target_language == LanguageCode.KOREAN:
            return (
                """        - Korean Cafe Staff: Taking polite orders, explaining menu options, checking preferences, handling payment, and closing with natural endings
        - Front Desk Staff: Helping with check-in, directions, reservations, and polite requests using appropriate honorific level
        - New Colleague: Exchanging greetings, self-introductions, workplace small talk, and simple follow-up questions
        - Friend: Having casual conversation about plans, opinions, and daily life while keeping the tone natural"""
            )
        return (
            """        - Cafe Barista: Greeting customers, explaining and recommending menu items, taking orders, chatting during drink preparation, payment and closing
        - Interviewer: Welcoming candidates, requesting self-introduction, asking about experience and career, evaluating problem-solving skills in various situations, providing time for questions
        - Hotel Front Desk: Check-in procedures, room information, introducing hotel facilities, handling requests, check-out and feedback
        - Meeting Participant: Making small talk, asking for opinions, responding to ideas, and encouraging practical follow-up answers"""
        )

    def build_free_chat_prompt(
        self,
        search_context: str | None = None,
        topic: str | None = None,
        conversation_direction: str | None = None,
        selected_question: str | None = None,
        custom_focus: str | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> str:
        """자유 대화용 시스템 프롬프트"""
        language_context = ensure_language_context(language_context)
        target_name = language_name(language_context.target_language)
        feedback_name = language_name(language_context.feedback_language)
        native_name = language_name(language_context.native_language)
        practice_priorities = format_practice_priorities(language_context.target_language)

        base_prompt = f"""You are a natural {target_name} conversation partner for a learner.

        ## Role:
        - Respond to what the user means and keep a real conversation going
        - Ask a natural follow-up question when it helps the conversation continue
        - Explain grammar or expressions only when the user explicitly asks for that help

        ## Learner Language Context:
        - Native language: {native_name}
        - Practice target language: {target_name}
        - Feedback/explanation language: {feedback_name}

        ## Target Language Practice Priorities:
{practice_priorities}

        ## Conversation Style:
        - Always communicate in {target_name}
        - Use {feedback_name} only for brief explanations when the learner needs help
        - Actively utilize reference information when available
        - Use natural and fluent {target_name} expressions
        - Proceed like a real conversation
        - Do not proactively correct, evaluate, or teach the user's language; separate grammar feedback handles that work
        - **IMPORTANT: Keep responses very short - maximum 3 sentences**
        """

        if search_context:
            base_prompt += f"\n\n## Reference Information:\n{search_context}"

        topic_prep_prompt = self.build_topic_prep_prompt(
            topic,
            conversation_direction,
            selected_question,
            language_context=language_context,
        )
        if topic_prep_prompt:
            base_prompt += topic_prep_prompt

        return base_prompt

    def build_topic_prep_prompt(
        self,
        topic: str | None = None,
        conversation_direction: str | None = None,
        selected_question: str | None = None,
        custom_focus: str | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> str:
        """주제 준비 카드 handoff 프롬프트"""
        if not any([topic, conversation_direction, selected_question, custom_focus]):
            return ""

        language_context = ensure_language_context(language_context)
        direction_guidance = self._conversation_direction_guidance(
            conversation_direction,
            language_context=language_context,
        )
        prompt = "\n\n## Topic Prep Handoff:"
        if topic:
            prompt += f"\n- Topic: {topic}"
        if conversation_direction:
            prompt += f"\n- Selected conversation direction: {conversation_direction}"
        if custom_focus:
            prompt += f"\n- User's custom conversation focus: {custom_focus}"
        if selected_question:
            prompt += f"\n- The user is answering this first question: {selected_question}"
        if direction_guidance:
            prompt += f"\n- Direction guidance: {direction_guidance}"

        target_name = language_name(language_context.target_language)
        prompt += f"""

Use the user's first message as an answer to the selected first question.
Continue naturally in {target_name} in the selected direction or custom focus while keeping the conversation short and interactive.
Do not re-ask the selected first question unless the user's answer is unclear."""
        return prompt

    def _conversation_direction_guidance(
        self,
        conversation_direction: str | None = None,
        language_context: LearningLanguageContext | None = None,
    ) -> str:
        """대화 방향별 프롬프트 가이드"""
        target_name = language_name(ensure_language_context(language_context).target_language)
        guidance = {
            "CASUAL_CHAT": f"Have a relaxed {target_name} conversation about opinions, reactions, and personal experiences.",
            "DEBATE": f"Encourage the user to take a position in {target_name}, give reasons, and consider counterarguments.",
            "INTERVIEW_QA": f"Ask focused follow-up questions in {target_name} as if interviewing the user about the topic.",
            "EXPLANATION_PRACTICE": f"Help the user explain the topic clearly in simple, organized {target_name}.",
        }
        if not conversation_direction:
            return ""
        return guidance.get(conversation_direction.upper(), "")

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
