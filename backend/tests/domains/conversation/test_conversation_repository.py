from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.enums import ConversationType
from domains.conversation.models import ConversationModel
from domains.conversation.repository import ConversationRepository
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
