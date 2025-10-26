"""
OpenRouter LLM Provider
"""
import httpx

from config import get_settings
from domains.llm.models import LLMRequest, LLMResponse
from domains.llm.provider import LLMProvider
from shared.exceptions import ExternalAPIException, RateLimitException

settings = get_settings()


class OpenRouterProvider(LLMProvider):
    """OpenRouter API Provider"""

    def __init__(self):
        self.api_key = settings.openrouter_api_key
        self.base_url = "https://openrouter.ai/api/v1/chat/completions"

    async def chat_completion(self, request: LLMRequest) -> LLMResponse:
        """
        OpenRouter API 호출

        Args:
            request: LLM 요청

        Returns:
            LLM 응답

        Raises:
            RateLimitException: Rate limit 도달
            ExternalAPIException: API 호출 실패
        """
        # Convert LLMMessage to dict format
        messages = [{"role": msg.role, "content": msg.content} for msg in request.messages]

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    self.base_url,
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "HTTP-Referer": "https://github.com/MoreThanHuman",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": request.model,
                        "messages": messages,
                        "max_tokens": request.max_tokens,
                        "temperature": request.temperature,
                        **(request.extra_params or {}),
                    },
                    timeout=30.0,
                )
                response.raise_for_status()
                data = response.json()

                return LLMResponse(
                    content=data["choices"][0]["message"]["content"],
                    model=data.get("model"),
                    usage=data.get("usage"),
                )
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 429:
                    raise RateLimitException(
                        "무료 모델의 사용 한도에 도달했습니다. 잠시 후 다시 시도해주세요.",
                        details={"retry_after": "1-2 minutes"},
                    )
                raise ExternalAPIException(f"OpenRouter API call failed: {str(e)}")
            except httpx.HTTPError as e:
                raise ExternalAPIException(f"OpenRouter API call failed: {str(e)}")

    def validate_config(self) -> bool:
        """OpenRouter 설정 검증"""
        return bool(self.api_key)

    def get_provider_name(self) -> str:
        """Provider 이름 반환"""
        return "openrouter"
