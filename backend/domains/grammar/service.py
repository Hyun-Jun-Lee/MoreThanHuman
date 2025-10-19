"""
Grammar Service Layer
"""
import json
from uuid import UUID, uuid4

import httpx

from backend.config import get_settings
from backend.domains.grammar.models import GrammarAnalysis, GrammarFeedback, GrammarFeedbackModel, GrammarStats
from backend.domains.grammar.repository import GrammarRepository
from backend.shared.exceptions import ExternalAPIException

settings = get_settings()


class GrammarService:
    """문법 서비스"""

    def __init__(self, repository: GrammarRepository):
        self.repository = repository

    async def check_grammar(self, text: str) -> GrammarFeedback:
        """
        문법 체크

        Args:
            text: 체크할 텍스트

        Returns:
            문법 피드백
        """
        # LLM을 통한 문법 분석
        analysis = await self.analyze_grammar(text)

        return GrammarFeedback(
            id=uuid4(),
            message_id=uuid4(),  # 임시 ID, 실제로는 메시지 저장 시 설정
            original_text=text,
            corrected_text=analysis.corrected_sentence,
            has_errors=analysis.has_errors,
            errors=analysis.errors,
        )

    async def save_feedback(self, message_id: UUID, feedback: GrammarFeedback) -> UUID:
        """
        피드백 저장

        Args:
            message_id: 메시지 ID
            feedback: 문법 피드백

        Returns:
            저장된 피드백 ID
        """
        feedback_model = GrammarFeedbackModel(
            id=uuid4(),
            message_id=message_id,
            original_text=feedback.original_text,
            corrected_text=feedback.corrected_text,
            has_errors=feedback.has_errors,
            errors=[error.model_dump() for error in feedback.errors],
        )

        saved = self.repository.save(feedback_model)
        return saved.id

    def get_feedback(self, message_id: UUID) -> GrammarFeedback:
        """
        메시지 ID로 피드백 조회

        Args:
            message_id: 메시지 ID

        Returns:
            문법 피드백
        """
        feedback = self.repository.find_by_message_id(message_id)
        return GrammarFeedback.model_validate(feedback)

    def get_stats(self, time_range: str | None = None) -> GrammarStats:
        """
        문법 통계 조회

        Args:
            time_range: 시간 범위

        Returns:
            문법 통계
        """
        stats = self.repository.get_stats(time_range)

        return GrammarStats(
            total_messages=stats["total_messages"],
            messages_with_errors=stats["messages_with_errors"],
            error_rate=stats["error_rate"],
            common_errors=[],  # TODO: 구현
            improvement_trend=[],  # TODO: 구현
        )

    async def analyze_grammar(self, text: str) -> GrammarAnalysis:
        """
        LLM을 사용한 문법 분석

        Args:
            text: 분석할 텍스트

        Returns:
            문법 분석 결과

        Raises:
            ExternalAPIException: LLM API 호출 실패
        """
        prompt = self.build_grammar_prompt(text)

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    "https://openrouter.ai/api/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {settings.openrouter_api_key}",
                        "HTTP-Referer": "https://github.com/MoreThanHuman",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": settings.llm_model,
                        "messages": [{"role": "user", "content": prompt}],
                        "max_tokens": 1000,
                        "temperature": 0.3,
                    },
                    timeout=30.0,
                )
                response.raise_for_status()
                data = response.json()
                llm_response = data["choices"][0]["message"]["content"]

                return self.parse_grammar_response(llm_response)
            except httpx.HTTPError as e:
                raise ExternalAPIException(f"Grammar check API call failed: {str(e)}")

    def build_grammar_prompt(self, text: str) -> str:
        """
        문법 체크용 프롬프트 생성

        Args:
            text: 체크할 텍스트

        Returns:
            프롬프트
        """
        return f"""Analyze the following English sentence for grammar errors.

Sentence: "{text}"

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
        except (json.JSONDecodeError, KeyError) as e:
            # 파싱 실패 시 에러 없음으로 처리
            return GrammarAnalysis(
                has_errors=False, errors=[], corrected_sentence="", overall_quality=1.0
            )
