"""
Ollama LLM Provider
"""
import httpx

from config import get_settings
from domains.llm.models import LLMRequest, LLMResponse
from domains.llm.provider import LLMProvider
from shared.exceptions import ExternalAPIException

settings = get_settings()


class OllamaProvider(LLMProvider):
    """Ollama Local LLM Provider"""

    def __init__(self):
        self.base_url = settings.ollama_base_url

    async def chat_completion(self, request: LLMRequest) -> LLMResponse:
        """
        Ollama API 호출

        Args:
            request: LLM 요청

        Returns:
            LLM 응답

        Raises:
            ExternalAPIException: API 호출 실패
        """
        # Convert LLMMessage to dict format
        messages = [{"role": msg.role, "content": msg.content} for msg in request.messages]

        async with httpx.AsyncClient() as client:
            try:
                response = await client.post(
                    f"{self.base_url}/v1/chat/completions",
                    headers={
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": request.model,
                        "messages": messages,
                        "options": {
                            "num_predict": request.max_tokens,
                            "temperature": request.temperature,
                        },
                        **(request.extra_params or {}),
                    },
                    timeout=60.0,  # Ollama may be slower on local hardware
                )
                response.raise_for_status()
                data = response.json()

                return LLMResponse(
                    content=data["choices"][0]["message"]["content"],
                    model=data.get("model"),
                    usage=data.get("usage"),
                )
            except httpx.HTTPStatusError as e:
                raise ExternalAPIException(f"Ollama API call failed: {str(e)}")
            except httpx.HTTPError as e:
                raise ExternalAPIException(f"Ollama API call failed: {str(e)}")

    def validate_config(self) -> bool:
        """Ollama 설정 검증 (URL 존재 여부)"""
        return bool(self.base_url)

    def get_provider_name(self) -> str:
        """Provider 이름 반환"""
        return "ollama"
