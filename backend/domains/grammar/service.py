"""
Grammar Service Layer
"""
import json
from uuid import uuid4

from config import get_model_for_provider, get_settings
from domains.grammar.models import GrammarFeedbackModel
from domains.grammar.repository import GrammarRepository
from domains.grammar.schemas import GrammarAnalysis, GrammarFeedback, GrammarStats
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest
from shared.exceptions import ExternalAPIException, RateLimitException

settings = get_settings()


class GrammarService:
    """문법 서비스"""

    def __init__(self, repository: GrammarRepository):
        self.repository = repository

    async def check_grammar(self, text: str, previous_ai_message: str | None = None) -> GrammarFeedback:
        """
        문법 체크

        Args:
            text: 체크할 텍스트
            previous_ai_message: 바로 전 AI 메시지 (대화 맥락)

        Returns:
            문법 피드백
        """
        # LLM을 통한 문법 분석
        analysis = await self.analyze_grammar(text, previous_ai_message)

        return GrammarFeedback(
            id=str(uuid4()),
            message_id=str(uuid4()),  # 임시 ID, 실제로는 메시지 저장 시 설정
            original_text=text,
            corrected_text=analysis.corrected_sentence,
            has_errors=analysis.has_errors,
            errors=analysis.errors,
        )

    async def save_feedback(self, message_id: str, feedback: GrammarFeedback) -> str:
        """
        피드백 저장

        Args:
            message_id: 메시지 ID
            feedback: 문법 피드백

        Returns:
            저장된 피드백 ID
        """
        feedback_model = GrammarFeedbackModel(
            id=str(uuid4()),
            message_id=message_id,
            original_text=feedback.original_text,
            corrected_text=feedback.corrected_text,
            has_errors=feedback.has_errors,
            errors=[error.model_dump() for error in feedback.errors],
        )

        saved = self.repository.save(feedback_model)
        return saved.id

    def get_feedback(self, message_id: str) -> GrammarFeedback:
        """
        메시지 ID로 피드백 조회

        Args:
            message_id: 메시지 ID

        Returns:
            문법 피드백
        """
        feedback = self.repository.find_by_message_id(message_id)
        return GrammarFeedback.model_validate(feedback)

    async def analyze_grammar(self, text: str, previous_ai_message: str | None = None) -> GrammarAnalysis:
        """
        LLM을 사용한 문법 분석

        Args:
            text: 분석할 텍스트
            previous_ai_message: 바로 전 AI 메시지 (대화 맥락)

        Returns:
            문법 분석 결과

        Raises:
            RateLimitException: Rate limit 도달
            ExternalAPIException: LLM API 호출 실패
        """
        # Create provider
        provider = LLMProviderFactory.create_provider()

        # Build prompt
        prompt = self.build_grammar_prompt(text, previous_ai_message)

        # Create request with provider-specific model
        request = LLMRequest(
            messages=[LLMMessage(role="user", content=prompt)],
            model=get_model_for_provider(),
            max_tokens=1000,
            temperature=0.3,
        )

        # Call provider
        response = await provider.chat_completion(request)
        return self.parse_grammar_response(response.content)

    def build_grammar_prompt(self, text: str, previous_ai_message: str | None = None) -> str:
        """
        문법 체크용 프롬프트 생성

        Args:
            text: 체크할 텍스트
            previous_ai_message: 바로 전 AI 메시지 (대화 맥락)

        Returns:
            프롬프트
        """
        context_part = ""
        if previous_ai_message:
            context_part = f"""
Context (previous AI message): "{previous_ai_message}"

IMPORTANT: Consider the conversation context when analyzing.
- Short responses like "Went to the park" are natural replies to questions like "What did you do?"
- Don't mark conversational responses as errors if they're natural in context
- However, still check for actual grammar errors (subject-verb agreement, tense, etc.)
"""

        return f"""Analyze the following English response for grammar errors.
{context_part}
User's response: "{text}"

Respond in JSON format with:
{{
  "has_errors": boolean,
  "errors": [
    {{
      "type": "grammar|word_choice|expression|spelling|punctuation",
      "original": "incorrect text",
      "corrected": "correct text",
      "explanation": "brief explanation",
      "position": {{"start": int, "end": int}}
    }}
  ],
  "corrected_sentence": "fully corrected sentence",
  "overall_quality": float (0.0 to 1.0)
}}

If there are no errors, return has_errors: false and an empty errors array.
Keep explanations concise and helpful."""

    def parse_grammar_response(self, response: str) -> GrammarAnalysis:
        """
        LLM 응답 파싱

        Args:
            response: LLM 응답

        Returns:
            문법 분석 결과
        """
        try:
            # JSON 추출 (마크다운 코드 블록 제거)
            if "```json" in response:
                response = response.split("```json")[1].split("```")[0].strip()
            elif "```" in response:
                response = response.split("```")[1].split("```")[0].strip()

            data = json.loads(response)

            return GrammarAnalysis(
                has_errors=data.get("has_errors", False),
                errors=[error for error in data.get("errors", [])],
                corrected_sentence=data.get("corrected_sentence", ""),
                overall_quality=data.get("overall_quality", 1.0),
            )
        except (json.JSONDecodeError, KeyError):
            # 파싱 실패 시 에러 없음으로 처리
            return GrammarAnalysis(
                has_errors=False, errors=[], corrected_sentence="", overall_quality=1.0
            )
