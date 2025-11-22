"""
Grammar Service Layer
"""
import json
from uuid import uuid4

from config import get_grammar_model_config, get_settings
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
        # Get grammar-specific model configuration
        grammar_provider, grammar_model = get_grammar_model_config()

        # Create provider with grammar-specific settings
        provider = LLMProviderFactory.create_provider(grammar_provider)

        # Build prompt
        prompt = self.build_grammar_prompt(text, previous_ai_message)

        # Create request with grammar-specific model (최적화: 토큰 절반, 온도 낮춤)
        request = LLMRequest(
            messages=[LLMMessage(role="user", content=prompt)],
            model=grammar_model,
            max_tokens=500,  # 1000 → 500 (더 빠른 응답)
            temperature=0.1,  # 0.3 → 0.1 (더 일관되고 빠른 응답)
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

NATURAL CONVERSATIONAL RESPONSES (Do NOT mark as errors):
- Short responses like "Went to the park" are natural replies to questions like "What did you do?"
- Elliptical answers that omit subjects/verbs when context is clear
- Casual expressions like "gonna", "wanna", "yeah", "nope" in informal conversation

MUST CHECK FOR THESE ERRORS:
1. Basic Grammar Errors:
   - Subject-verb agreement (e.g., "I likes" → "I like")
   - Question formation: Must have proper word order
     * Questions need: Wh-word (if any) + Auxiliary (do/does/did/can/will) + Subject + Main verb
     * Examples: "what you think?" → "What do you think?"
     * Examples: "other groups you know?" → "What other groups do you know?" or "Do you know other groups?"
   - Spelling mistakes
   - Punctuation errors
   - Word order problems
   - Missing words (articles, auxiliary verbs, prepositions, question words)

2. Contextual Appropriateness:
   - Tense consistency: If AI asks about past, user should use past tense, not future/present
   - Question-answer match: "Where" questions need location answers
   - Formality level: Match the conversation style (formal vs casual)

3. Examples of contextual errors:
   - AI: "What did you do yesterday?" → User: "I will go shopping" ❌ (should be "I went shopping")
   - AI: "Where did you go?" → User: "I enjoyed it" ❌ (doesn't answer the location question)
"""

        return f"""Analyze the following English response for grammar errors.
{context_part}
User's response: "{text}"

CRITICAL CORRECTION RULES:
1. The corrected sentence MUST make logical sense and be grammatically complete
2. If a word seems out of place or makes no sense, consider it might be:
   - A typo (e.g., "know" might be "now")
   - Should be removed entirely
   - Part of a different intended phrase
3. Fix ALL errors to create a natural, meaningful sentence
4. Examples:
   - "hi know i want seat of mine" → "Hi, I want my seat." (remove nonsensical "know")
   - "what you think where is best?" → "What do you think is the best?" (fix question structure)
   - "other groups you know?" → "What other groups do you know?" (add missing question word)

Respond in JSON format:
{{
  "has_errors": true/false,
  "corrected_sentence": "fully corrected, meaningful sentence",
  "errors": [
    {{
      "original": "incorrect part",
      "corrected": "correct part",
      "explanation": "brief explanation"
    }}
  ]
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
            )
        except (json.JSONDecodeError, KeyError):
            # 파싱 실패 시 에러 없음으로 처리
            return GrammarAnalysis(
                has_errors=False, errors=[], corrected_sentence=""
            )
