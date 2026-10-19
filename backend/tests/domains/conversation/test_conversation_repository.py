from uuid import uuid4

import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.enums import ConversationType, MessageRole
from domains.conversation.models import ConversationModel, MessageModel
from domains.conversation.repository import ConversationRepository
from domains.conversation.service import ConversationService
from shared.exceptions import NotFoundException


def _repository():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    session = sessionmaker(bind=engine)()
    return ConversationRepository(session)


def test_find_all_filters_conversations_by_profile_id():
    repository = _repository()
    owner_id = str(uuid4())
    other_id = str(uuid4())
    repository.db.add_all(
        [
            ProfileModel(id=owner_id, email="owner@example.com", name="Owner"),
            ProfileModel(id=other_id, email="other@example.com", name="Other"),
            ConversationModel(
                id=str(uuid4()),
                user_id=owner_id,
                title="Owner conversation",
                conversation_type=ConversationType.FREE_CHAT,
            ),
            ConversationModel(
                id=str(uuid4()),
                user_id=other_id,
                title="Other conversation",
                conversation_type=ConversationType.FREE_CHAT,
            ),
        ]
    )
    repository.db.commit()

    conversations = repository.find_all(owner_id)

    assert [conversation.title for conversation in conversations] == ["Owner conversation"]


def test_find_by_id_hides_conversation_from_other_profile():
    repository = _repository()
    owner_id = str(uuid4())
    other_id = str(uuid4())
    conversation_id = str(uuid4())
    repository.db.add_all(
        [
            ProfileModel(id=owner_id, email="owner@example.com", name="Owner"),
            ProfileModel(id=other_id, email="other@example.com", name="Other"),
            ConversationModel(
                id=conversation_id,
                user_id=owner_id,
                title="Owner conversation",
                conversation_type=ConversationType.FREE_CHAT,
            ),
        ]
    )
    repository.db.commit()

    try:
        repository.find_by_id(conversation_id, other_id)
    except NotFoundException:
        return

    raise AssertionError("conversation should be hidden from non-owner")


def test_message_page_filters_by_owner_without_separate_ownership_query():
    repository = _repository()
    owner_id, other_id = str(uuid4()), str(uuid4())
    owned_id, other_conversation_id = str(uuid4()), str(uuid4())
    repository.db.add_all([
        ProfileModel(id=owner_id, email="owner@example.com", name="Owner"),
        ProfileModel(id=other_id, email="other@example.com", name="Other"),
        ConversationModel(id=owned_id, user_id=owner_id, conversation_type=ConversationType.FREE_CHAT),
        ConversationModel(id=other_conversation_id, user_id=other_id, conversation_type=ConversationType.FREE_CHAT),
    ])
    repository.db.flush()
    repository.db.add_all([
        MessageModel(id=str(uuid4()), conversation_id=owned_id, role=MessageRole.USER, content="first"),
        MessageModel(id=str(uuid4()), conversation_id=owned_id, role=MessageRole.USER, content="second"),
        MessageModel(id=str(uuid4()), conversation_id=other_conversation_id, role=MessageRole.USER, content="private"),
    ])
    repository.db.commit()
    statements = []

    def capture(_connection, _cursor, statement, _parameters, _context, _many):
        statements.append(statement)

    engine = repository.db.get_bind()
    event.listen(engine, "before_cursor_execute", capture)
    try:
        page = ConversationService(repository).get_messages(owned_id, owner_id, limit=1)
    finally:
        event.remove(engine, "before_cursor_execute", capture)

    assert page.pagination.total_count == 2
    assert page.pagination.has_more is True
    assert len(page.results) == 1
    assert page.results[0].content in {"first", "second"}
    assert len(statements) == 2  # 소유자 조건이 있는 개수·페이지 조회
    assert all("user_id" in statement for statement in statements)

    with pytest.raises(NotFoundException):
        ConversationService(repository).get_messages(other_conversation_id, owner_id)
    with pytest.raises(NotFoundException):
        ConversationService(repository).get_messages(str(uuid4()), owner_id)


def test_empty_owned_conversation_returns_empty_page():
    repository = _repository()
    owner_id, conversation_id = str(uuid4()), str(uuid4())
    repository.db.add(ProfileModel(id=owner_id, email="owner@example.com", name="Owner"))
    repository.db.add(ConversationModel(
        id=conversation_id, user_id=owner_id, conversation_type=ConversationType.FREE_CHAT,
    ))
    repository.db.commit()

    page = ConversationService(repository).get_messages(conversation_id, owner_id)

    assert page.results == []
    assert page.pagination.total_count == 0


def test_conversation_model_has_default_language_snapshot():
    repository = _repository()
    owner_id = str(uuid4())
    repository.db.add(ProfileModel(id=owner_id, email="owner@example.com", name="Owner"))
    conversation = ConversationModel(
        id=str(uuid4()),
        user_id=owner_id,
        title="Language snapshot",
        conversation_type=ConversationType.FREE_CHAT,
    )

    saved = repository.save(conversation)

    assert saved.native_language == "ko"
    assert saved.target_language == "en"
    assert saved.feedback_language == "ko"


def test_roleplay_conversation_persists_long_role_without_manual_difficulty():
    repository = _repository()
    owner_id = str(uuid4())
    repository.db.add(ProfileModel(id=owner_id, email="owner@example.com", name="Owner"))
    long_role = "a friendly cafe barista taking an order " + "with practical follow-up questions " * 4
    conversation = ConversationModel(
        id=str(uuid4()),
        user_id=owner_id,
        title="Role: cafe practice",
        conversation_type=ConversationType.ROLE_PLAYING,
        role_character=long_role,
    )

    saved = repository.save(conversation)

    assert len(saved.role_character) > 100
    assert saved.role_character == long_role
    assert not hasattr(saved, "roleplay_difficulty")
