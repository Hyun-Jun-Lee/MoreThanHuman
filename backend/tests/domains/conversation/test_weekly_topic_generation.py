import json
from datetime import datetime
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.conversation.topic_generation_service import WeeklyTopicGenerator, validate_topics, weekly_slot
from domains.conversation.topic_repository import WeeklyTopicRepository
from domains.llm.schemas import LLMResponse


def test_weekly_slot_switches_at_seoul_monday_five():
    zone = ZoneInfo("Asia/Seoul")
    assert weekly_slot(datetime(2026, 10, 5, 4, 59, tzinfo=zone)) == "2026-09-28"
    assert weekly_slot(datetime(2026, 10, 5, 5, 0, tzinfo=zone)) == "2026-10-05"


def test_generation_rejects_short_or_duplicate_batch():
    with pytest.raises(ValueError):
        validate_topics({"topics": [
            {"text": "오늘의 점심 이야기", "first_question": "What did you enjoy for lunch?"}
        ] * 8}, "ko", "en")
    with pytest.raises(ValueError):
        validate_topics({"topics": [
            {"text": f"오늘의 취미 이야기 {i}", "first_question": "한국어 질문인가요?"}
            for i in range(8)
        ]}, "ko", "en")


def test_generation_accepts_korean_first_questions_for_english_topics():
    pairs = validate_topics({"topics": [
        {"text": f"A favorite weekend activity {i}", "first_question": f"이번 주말에는 어떤 활동을 하고 싶어요 {i}?"}
        for i in range(8)
    ]}, "en", "ko")
    assert len(pairs) == 8
    assert pairs[0][1].endswith("?")


@pytest.mark.asyncio
async def test_generation_publishes_once_and_keeps_last_batch_on_failure(monkeypatch):
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as db:
        repository = WeeklyTopicRepository(db)
        generator = WeeklyTopicGenerator(repository, http_client=object())

        class FakeProvider:
            calls = 0

            async def chat_completion(self, _request):
                self.calls += 1
                if self.calls == 1:
                    return LLMResponse(content=json.dumps({"topics": [
                        {"text": f"오늘의 취미 이야기 {i}", "first_question": f"What hobby do you enjoy most, number {i}?"}
                        for i in range(8)
                    ]}))
                return LLMResponse(content=json.dumps({"approved_indices": list(range(8))}))

        monkeypatch.setattr("domains.conversation.topic_generation_service.LLMProviderFactory.create_provider", lambda **_: FakeProvider())
        first = await generator.generate("ko", "en", week_start="2026-09-28")
        again = await generator.generate("ko", "en", week_start="2026-09-28")
        assert first["status"] == "published"
        assert again["status"] == "existing"
        assert len(repository.latest("ko", "en")[1]) == 8
        assert repository.latest("ko", "en")[1][0].first_question.startswith("What hobby")

        class InvalidProvider:
            async def chat_completion(self, _request):
                return LLMResponse(content=json.dumps({
                    "topics": [
                        {"text": f"오늘의 취미 이야기 {i}", "first_question": "What do you enjoy?"}
                        for i in range(3)
                    ] + [
                        {"text": f"새로운 주말 활동 이야기 {i}", "first_question": "What would you try?"}
                        for i in range(5)
                    ]
                }))

        monkeypatch.setattr("domains.conversation.topic_generation_service.LLMProviderFactory.create_provider", lambda **_: InvalidProvider())
        monkeypatch.setattr("domains.conversation.topic_generation_service.weekly_slot", lambda: "2026-10-05")
        with pytest.raises(ValueError):
            await generator.generate("ko", "en", week_start="2026-10-05")
        assert repository.latest("ko", "en")[0].isoformat() == "2026-09-28"
    engine.dispose()


@pytest.mark.asyncio
async def test_republish_replaces_validated_pairs_without_changing_ids(monkeypatch):
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as db:
        repository = WeeklyTopicRepository(db)
        original = repository.publish("ko", "en", "2026-09-28", [
            (f"이전 취미 이야기 {i}", f"What did you enjoy about hobby {i}?") for i in range(8)
        ])
        original_ids = [topic.id for topic in original]

        class FakeProvider:
            calls = 0

            async def chat_completion(self, _request):
                self.calls += 1
                if self.calls == 1:
                    return LLMResponse(content=json.dumps({"topics": [
                        {"text": f"새로운 음식 이야기 {i}", "first_question": f"What food would you share with a friend {i}?"}
                        for i in range(8)
                    ]}))
                return LLMResponse(content=json.dumps({"approved_indices": list(range(8))}))

        monkeypatch.setattr("domains.conversation.topic_generation_service.LLMProviderFactory.create_provider", lambda **_: FakeProvider())
        result = await WeeklyTopicGenerator(repository, object()).generate(
            "ko", "en", week_start="2026-09-28", republish=True
        )
        assert result["status"] == "republished"
        refreshed = repository.latest("ko", "en")[1]
        assert [topic.id for topic in refreshed] == original_ids
        assert refreshed[0].text == "새로운 음식 이야기 0"
        assert refreshed[0].first_question == "What food would you share with a friend 0?"

        class UnsafeProvider:
            calls = 0

            async def chat_completion(self, _request):
                self.calls += 1
                if self.calls == 1:
                    return LLMResponse(content=json.dumps({"topics": [
                        {"text": f"다른 여행 이야기 {i}", "first_question": f"Where would you travel with a friend {i}?"}
                        for i in range(8)
                    ]}))
                return LLMResponse(content=json.dumps({"approved_indices": list(range(7))}))

        monkeypatch.setattr("domains.conversation.topic_generation_service.LLMProviderFactory.create_provider", lambda **_: UnsafeProvider())
        with pytest.raises(ValueError, match="publication checks"):
            await WeeklyTopicGenerator(repository, object()).generate(
                "ko", "en", week_start="2026-09-28", republish=True
            )
        assert [topic.id for topic in repository.latest("ko", "en")[1]] == original_ids
        assert repository.latest("ko", "en")[1][0].text == "새로운 음식 이야기 0"
    engine.dispose()
