"""이력 포함 프롬프트, 실행 예산, 예약 재개를 가진 생성 서비스."""

import asyncio
import time
from collections import Counter

from pydantic import ValidationError

from config import get_model_for_provider, get_settings
from domains.language_snacks import prompts
from domains.language_snacks.generation_schemas import (
    CandidateBatch,
    DedupeResult,
    QualityResult,
)
from domains.language_snacks.identity import knowledge_key, stable_json
from domains.language_snacks.lock import SnackError
from domains.language_snacks.models import utcnow
from domains.language_snacks.schemas import (
    PAYLOAD_MODELS,
    LanguageSnackCreate,
)
from domains.language_snacks.service import LanguageSnackService
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest
from shared.exceptions import ExternalAPIException, RateLimitException


class SnackGenerator:
    def __init__(self, repository, provider=None, settings=None):
        self.repository = repository
        self.settings = settings or get_settings()
        self.provider = provider or LLMProviderFactory.create_provider(
            self.settings.language_snacks_provider
        )
        self.model = self.settings.language_snacks_model or get_model_for_provider(
            self.settings.language_snacks_provider
        )
        self.run = None
        self.metrics = {}
        self.deadline = time.monotonic() + self.settings.language_snacks_run_seconds

    def metadata(self):
        return {
            "provider": self.provider.get_provider_name(),
            "model": self.model,
            "prompt_version": prompts.PROMPT_VERSION,
        }

    def record(self, **values):
        self.metrics = {**self.metrics, **values}
        if self.run:
            self.run.metrics = dict(self.metrics)
            self.repository.save(self.run)

    async def ask(self, instruction, data, schema):
        content = stable_json(
            {"data": data, "response_schema": schema.model_json_schema()}
        )
        messages = [
            LLMMessage(role="system", content=prompts.BASE + instruction),
            LLMMessage(role="user", content=content),
        ]
        # UTF-8 바이트 수는 입력 토큰의 보수적인 상한으로 사용해요.
        charge = len((prompts.BASE + instruction + content).encode("utf-8")) + 4000
        for attempt in range(2):
            calls = self.metrics.get("calls", 0)
            tokens = self.metrics.get("charged_tokens", 0)
            remaining = self.deadline - time.monotonic()
            if (
                calls >= self.settings.language_snacks_max_calls
                or tokens + charge > self.settings.language_snacks_max_tokens
                or remaining <= 0
            ):
                raise SnackError("generation_budget_exceeded")
            self.record(calls=calls + 1, charged_tokens=tokens + charge)
            try:
                response = await asyncio.wait_for(
                    self.provider.chat_completion(
                        LLMRequest(
                            messages=messages,
                            model=self.model,
                            max_tokens=4000,
                            temperature=0.3,
                        )
                    ),
                    timeout=min(remaining, 65),
                )
                if self.repository.guard:
                    self.repository.guard.check()
                actual = (response.usage or {}).get("total_tokens", 0)
                self.record(
                    reported_tokens=self.metrics.get("reported_tokens", 0)
                    + (actual if isinstance(actual, int) else 0)
                )
                return schema.model_validate_json(response.content)
            except (TimeoutError, ExternalAPIException, RateLimitException):
                if attempt:
                    raise SnackError("llm_unavailable") from None
            except ValidationError:
                raise SnackError("invalid_llm_response") from None

    def history(self, language):
        history = self.repository.history(language)
        if (
            len(stable_json(history).encode("utf-8"))
            > self.settings.language_snacks_history_bytes
        ):
            raise SnackError("history_budget_exceeded")
        return history

    async def ensure_new(self, candidate):
        history = self.history(candidate.content_language)
        key = knowledge_key(candidate.identity.model_dump(exclude_none=True))
        if any(knowledge_key(item["identity"]) == key for item in history):
            raise SnackError("duplicate_knowledge", 409)
        if not history:
            return
        result = await self.ask(
            prompts.DEDUPE,
            {"candidate": candidate.model_dump(), "history": history},
            DedupeResult,
        )
        if result.decision == "duplicate":
            if result.existing_id not in {item["id"] for item in history}:
                raise SnackError("invalid_duplicate_reference")
            raise SnackError("duplicate_knowledge", 409)
        if result.decision != "new" or result.existing_id is not None:
            raise SnackError("uncertain_knowledge", 422)

    async def verify(self, request):
        result = await self.ask(prompts.VERIFY, request.model_dump(), QualityResult)
        if not result.valid:
            raise SnackError("content_validation_failed", 422)

    async def finish_reservation(self, row):
        attempts = row.generation_metadata.get("attempts", 0)
        while attempts < 2:
            attempts += 1
            row.generation_metadata = {**self.metadata(), "attempts": attempts}
            self.repository.save(row)
            try:
                payload = await self.ask(
                    prompts.AUTHOR,
                    {
                        "identity": row.identity,
                        "content_type": row.content_type,
                        "content_language": row.content_language,
                        "explanation_language": row.explanation_language,
                    },
                    PAYLOAD_MODELS[row.content_type],
                )
                request = LanguageSnackCreate(
                    content_type=row.content_type,
                    content_language=row.content_language,
                    explanation_language=row.explanation_language,
                    identity=row.identity,
                    knowledge_summary=row.knowledge_summary,
                    payload=payload.model_dump(exclude_none=True),
                )
                await self.verify(request)
                LanguageSnackService(self.repository).publish(
                    row, request, {**self.metadata(), "attempts": attempts}
                )
                return
            except (SnackError, ValidationError) as error:
                code = (
                    error.code if isinstance(error, SnackError) else "invalid_payload"
                )
                row.generation_metadata = {**row.generation_metadata, "error": code}
                # 예산 종료는 나머지 재시도 기회를 소비하지 않아요.
                if code in (
                    "generation_budget_exceeded",
                    "lock_connection_lost",
                    "history_budget_exceeded",
                ):
                    row.generation_metadata["attempts"] = attempts - 1
                    self.repository.save(row)
                    raise
                self.repository.save(row)
        row.status = "archived"
        self.repository.save(row)

    async def generate(self, run_key, language, target=3, dry_run=False):
        if language not in ("en", "ko") or not 1 <= target <= 6 or len(run_key) > 150:
            raise SnackError("invalid_run_parameters", 422)
        self.run = None
        self.metrics = {}
        with self.repository.locked():
            self.deadline = time.monotonic() + self.settings.language_snacks_run_seconds
            if dry_run:
                batch = await self.ask(
                    prompts.CANDIDATES,
                    {
                        "content_language": language,
                        "count": target * 2,
                        "history": self.history(language),
                    },
                    CandidateBatch,
                )
                return {
                    "status": "dry_run",
                    "candidates": [
                        x.model_dump()
                        for x in batch.candidates
                        if x.content_language == language
                    ],
                }
            self.run = self.repository.run(run_key, language, target)
            self.metrics = dict(self.run.metrics)
            if self.run.status == "succeeded":
                return {
                    "run_id": self.run.id,
                    "status": "succeeded",
                    "metrics": self.metrics,
                }
            self.run.status = "running"
            self.run.finished_at = None
            self.metrics.pop("error", None)
            self.run.metrics = dict(self.metrics)
            self.repository.save(self.run)
            try:
                self.history(language)
                for row in self.repository.run_snacks(self.run.id):
                    if row.status == "reserved":
                        await self.finish_reservation(row)
                while self.metrics.get("rounds", 0) < 3:
                    rows = self.repository.run_snacks(self.run.id)
                    counts = Counter(
                        row.content_type for row in rows if row.published_at is not None
                    )
                    missing = {
                        kind: target - counts[kind]
                        for kind in PAYLOAD_MODELS
                        if counts[kind] < target
                    }
                    if not missing:
                        break
                    self.record(rounds=self.metrics.get("rounds", 0) + 1)
                    batch = await self.ask(
                        prompts.CANDIDATES,
                        {
                            "content_language": language,
                            "missing_by_type": missing,
                            "count": min(12, sum(missing.values()) * 2),
                            "history": self.history(language),
                        },
                        CandidateBatch,
                    )
                    for candidate in batch.candidates:
                        if (
                            candidate.content_language != language
                            or counts[candidate.content_type] >= target
                        ):
                            continue
                        try:
                            await self.ensure_new(candidate)
                            row = self.repository.reserve(candidate, self.run.id)
                        except SnackError as error:
                            if error.code not in (
                                "duplicate_knowledge",
                                "uncertain_knowledge",
                            ):
                                raise
                            self.record(
                                **{error.code: self.metrics.get(error.code, 0) + 1}
                            )
                            continue
                        await self.finish_reservation(row)
                        if row.published_at:
                            counts[row.content_type] += 1
                rows = self.repository.run_snacks(self.run.id)
                counts = Counter(
                    row.content_type for row in rows if row.published_at is not None
                )
                self.record(published_by_type=dict(counts))
                self.run.status = (
                    "succeeded"
                    if all(counts[k] >= target for k in PAYLOAD_MODELS)
                    else "partial"
                )
            except SnackError as error:
                if error.code == "lock_connection_lost":
                    raise
                counts = Counter(
                    row.content_type
                    for row in self.repository.run_snacks(self.run.id)
                    if row.published_at is not None
                )
                self.record(error=error.code, published_by_type=dict(counts))
                self.run.status = "partial" if counts else "failed"
            self.run.finished_at = utcnow()
            self.repository.save(self.run)
            return {
                "run_id": self.run.id,
                "status": self.run.status,
                "metrics": self.metrics,
            }
