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
        validate_topics({"topics": ["오늘의 점심 이야기"] * 8}, "ko")


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
                    return LLMResponse(content=json.dumps({"topics": [f"오늘의 취미 이야기 {i}" for i in range(8)]}))
                return LLMResponse(content=json.dumps({"approved_indices": list(range(8))}))

        monkeypatch.setattr("domains.conversation.topic_generation_service.LLMProviderFactory.create_provider", lambda **_: FakeProvider())
        first = await generator.generate("ko", "en", week_start="2026-09-28")
        again = await generator.generate("ko", "en", week_start="2026-09-28")
        assert first["status"] == "published"
        assert again["status"] == "existing"
        assert len(repository.latest("ko", "en")[1]) == 8

        class InvalidProvider:
            async def chat_completion(self, _request):
                return LLMResponse(content=json.dumps({
                    "topics": [f"오늘의 취미 이야기 {i}" for i in range(3)] +
                    [f"새로운 주말 활동 이야기 {i}" for i in range(5)]
                }))

        monkeypatch.setattr("domains.conversation.topic_generation_service.LLMProviderFactory.create_provider", lambda **_: InvalidProvider())
        monkeypatch.setattr("domains.conversation.topic_generation_service.weekly_slot", lambda: "2026-10-05")
        with pytest.raises(ValueError):
            await generator.generate("ko", "en", week_start="2026-10-05")
        assert repository.latest("ko", "en")[0].isoformat() == "2026-09-28"
    engine.dispose()
