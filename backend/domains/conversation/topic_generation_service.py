"""수동 발행 CLI가 호출하는 주간 대화 주제 생성 서비스."""

import json
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

import httpx

from config import get_model_for_provider
from domains.conversation.models import WeeklyTopicBatchModel
from domains.conversation.topic_repository import WeeklyTopicRepository
from domains.llm.factory import LLMProviderFactory
from domains.llm.schemas import LLMMessage, LLMRequest


PAIR_NAMES = {("ko", "en"): ("Korean", "English"), ("en", "ko"): ("English", "Korean")}


def weekly_slot(now: datetime | None = None) -> str:
    local = (now or datetime.now(ZoneInfo("Asia/Seoul"))).astimezone(ZoneInfo("Asia/Seoul"))
    start = (local - timedelta(days=local.weekday())).replace(hour=5, minute=0, second=0, microsecond=0)
    if local < start:
        start -= timedelta(days=7)
    return start.date().isoformat()


def validate_topics(value: object, native: str, target: str) -> list[tuple[str, str]]:
    """LLM의 성공 주장 대신 주제와 첫 질문의 실제 문구를 검사해요."""
    if not isinstance(value, dict) or not isinstance(value.get("topics"), list):
        raise ValueError("topics must be a JSON array")
    accepted: list[tuple[str, str]] = []
    seen: set[str] = set()
    for candidate in value["topics"]:
        if not isinstance(candidate, dict):
            continue
        raw_text = candidate.get("text")
        raw_question = candidate.get("first_question")
        if not isinstance(raw_text, str) or not isinstance(raw_question, str):
            continue
        text = " ".join(raw_text.split())
        question = " ".join(raw_question.split())
        key = text.casefold()
        if not 8 <= len(text) <= 90 or key in seen:
            continue
        min_question_length = 8 if target == "ko" else 12
        if not min_question_length <= len(question) <= 180 or question.count("?") + question.count("？") != 1:
            continue
        if not question.endswith(("?", "？")):
            continue
        if any(token in phrase for phrase in (key, question.casefold()) for token in ("http://", "https://", "@", "#")):
            continue
        if native == "ko" and not any("가" <= char <= "힣" for char in text):
            continue
        if native == "en" and not any("a" <= char.lower() <= "z" for char in text):
            continue
        if target == "ko" and not any("가" <= char <= "힣" for char in question):
            continue
        if target == "en" and (not any("a" <= char.lower() <= "z" for char in question)
                               or any("가" <= char <= "힣" for char in question)):
            continue
        seen.add(key)
        accepted.append((text, question))
    if len(accepted) < 6:
        raise ValueError("at least six distinct valid topics are required")
    return accepted[:8]


def parse_json_content(content: str) -> object:
    raw = content.strip()
    if raw.startswith("```"):
        raw = raw.strip("`").removeprefix("json").strip()
    return json.loads(raw)


def approved_topics(topics: list[tuple[str, str]], review: object) -> list[tuple[str, str]]:
    if not isinstance(review, dict) or not isinstance(review.get("approved_indices"), list):
        raise ValueError("safety review is invalid")
    indices = review["approved_indices"]
    if any(type(index) is not int or not 0 <= index < len(topics) for index in indices):
        raise ValueError("safety review indexes are invalid")
    safe = [topics[index] for index in dict.fromkeys(indices)]
    if len(safe) < 6:
        raise ValueError("not enough safe topics")
    return safe


class WeeklyTopicGenerator:
    def __init__(self, repository: WeeklyTopicRepository, http_client: httpx.AsyncClient):
        self.repository = repository
        self.http_client = http_client

    async def generate(self, native: str, target: str, *, week_start: str | None = None, republish: bool = False) -> dict:
        if (native, target) not in PAIR_NAMES:
            raise ValueError("unsupported language pair")
        slot = week_start or weekly_slot()
        week = date.fromisoformat(slot)
        if week.weekday() != 0:
            raise ValueError("week_start must be Monday")
        if week > date.fromisoformat(weekly_slot()):
            raise ValueError("future week_start cannot be published")
        existing = self.repository.db.query(WeeklyTopicBatchModel).filter_by(
            native_language=native, target_language=target,
            week_start=week,
        ).one_or_none()
        if existing is not None and not republish:
            return {"status": "existing", "count": len(existing.topics), "week_start": slot}
        native_name, target_name = PAIR_NAMES[(native, target)]
        _, previous_topics = self.repository.latest(native, target)
        previous_texts = [topic.text for topic in previous_topics]
        active_count = len([topic for topic in existing.topics if topic.archived_at is None]) if existing else 0
        provider = LLMProviderFactory.create_provider(http_client=self.http_client)
        request = LLMRequest(
            model=get_model_for_provider(), max_tokens=1200, temperature=0.8,
            messages=[
                LLMMessage(role="system", content=(
                    "Generate exactly eight safe, distinct, everyday conversation starter topics and opening questions for language learners. "
                    "Use familiar personal experiences, hobbies, food, travel or daily routines. "
                    "Avoid news, politics, medical or legal advice, personal data, violence and sexual content. "
                    "Return only JSON: {\"topics\":[{\"text\":\"...\",\"first_question\":\"... ?\"}]}."
                )),
                LLMMessage(role="user", content=(
                    f"Write eight short topics in {native_name} for learners practicing {target_name}. "
                    f"For each topic, write one short open-ended first question in {target_name}. "
                    "Questions should invite personal experience, not ask for current facts or answer for the learner. "
                    f"Do not repeat these previous topics: {json.dumps(previous_texts, ensure_ascii=False)}"
                )),
            ],
        )
        response = await provider.chat_completion(request)
        try:
            topics = validate_topics(parse_json_content(response.content), native, target)
            previous_keys = {" ".join(text.split()).casefold() for text in previous_texts}
            topics = [item for item in topics if item[0].casefold() not in previous_keys]
            if len(topics) < 6:
                raise ValueError("not enough fresh topics")
            safety_request = LLMRequest(
                model=get_model_for_provider(), max_tokens=350, temperature=0,
                messages=[
                    LLMMessage(role="system", content=(
                        "Review each topic and its opening question for a language learning app. "
                        "Reject sensitive, sexual, violent, discriminatory, political, news-dependent, "
                        "medical or legal advice topics. Return only JSON: {\"approved_indices\":[0,1,...]}. "
                        "Include only safe topic indices; do not rewrite them."
                    )),
                    LLMMessage(role="user", content=json.dumps(
                        [{"text": text, "first_question": question} for text, question in topics], ensure_ascii=False
                    )),
                ],
            )
            review = await provider.chat_completion(safety_request)
            topics = approved_topics(topics, parse_json_content(review.content))
            if existing is not None and len(topics) < active_count:
                raise ValueError("not enough safe topics to preserve existing topic IDs")
        except (ValueError, json.JSONDecodeError) as error:
            raise ValueError("generated topics failed publication checks") from error
        published = self.repository.publish(native, target, slot, topics, republish=republish)
        return {"status": "republished" if existing else "published", "count": len(published), "week_start": slot}
