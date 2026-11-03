from copy import deepcopy

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import Base
from domains.conversation.models import ConversationModel  # noqa
from domains.grammar.models import GrammarFeedbackModel  # noqa
from domains.language_snacks.repository import LanguageSnackRepository

SAMPLE = {
    "content_type": "regional_variant",
    "content_language": "en",
    "explanation_language": "ko",
    "knowledge_summary": "British crisps and American chips are potato snacks.",
    "identity": {
        "relation": "regional_equivalent",
        "entries": [
            {
                "language": "en",
                "expression": "crisps",
                "sense": "potato_snack",
                "variety": "GB",
            },
            {
                "language": "en",
                "expression": "chips",
                "sense": "potato_snack",
                "variety": "US",
            },
        ],
    },
    "payload": {
        "meaning": "감자 과자",
        "items": [
            {"label": "영국", "expression": "crisps"},
            {"label": "미국", "expression": "chips"},
        ],
    },
}


@pytest.fixture
def sample():
    return deepcopy(SAMPLE)


@pytest.fixture
def repository():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(engine)
    with sessionmaker(bind=engine)() as db:
        yield LanguageSnackRepository(db)
    engine.dispose()
