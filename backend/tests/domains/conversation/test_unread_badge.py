from uuid import uuid4

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from database import Base
from domains.auth.models import ProfileModel
from domains.conversation.enums import MessageRole
from domains.conversation.models import ConversationModel, MessageModel
from domains.conversation.repository import ConversationRepository, ConversationLocked
from shared.exceptions import NotFoundException


@pytest.fixture
def records():
    engine = create_engine('sqlite://')
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        owner = ProfileModel(id=str(uuid4()), name='owner', is_guest=False)
        other = ProfileModel(id=str(uuid4()), name='other', is_guest=False)
        db.add_all([owner, other])
        db.flush()
        conversation = ConversationModel(id=str(uuid4()), user_id=owner.id, slot_active=True)
        foreign = ConversationModel(id=str(uuid4()), user_id=other.id)
        db.add_all([conversation, foreign])
        db.flush()
        messages = [MessageModel(id=str(uuid4()), conversation_id=c.id, role=role, content='reply')
                    for c, role in [(conversation, MessageRole.ASSISTANT),
                                    (conversation, MessageRole.USER), (foreign, MessageRole.ASSISTANT)]]
        db.add_all(messages)
        db.commit()
        yield ConversationRepository(db), owner, conversation, messages
    engine.dispose()


def test_only_explicit_owned_assistant_ids_are_read_and_repeat_is_idempotent(records):
    repo, owner, conversation, (reply, user, foreign) = records
    assert reply.read_at is None
    assert repo.has_unread_replies(owner.id)
    repo.mark_replies_read(conversation.id, owner.id, [reply.id, user.id, foreign.id])
    repo.db.refresh(reply)
    first_read = reply.read_at
    assert first_read is not None
    assert not repo.has_unread_replies(owner.id)
    assert user.read_at is None and foreign.read_at is None
    new_reply = MessageModel(id=str(uuid4()), conversation_id=conversation.id, role=MessageRole.ASSISTANT, content='new')
    repo.save_message(new_reply)
    repo.mark_replies_read(conversation.id, owner.id, [reply.id])
    repo.db.refresh(reply)
    assert reply.read_at == first_read
    assert repo.has_unread_replies(owner.id)
    with pytest.raises(NotFoundException):
        repo.mark_replies_read(conversation.id, 'other-account', [reply.id])


def test_guest_exclusion_conversion_and_member_slot_independence(records):
    repo, owner, conversation, (reply, _, _) = records
    owner.is_guest = True
    repo.db.commit()
    assert not repo.has_unread_replies(owner.id)
    repo.mark_replies_read(conversation.id, owner.id, [reply.id])
    repo.db.refresh(reply)
    assert reply.read_at is not None
    new_reply = MessageModel(id=str(uuid4()), conversation_id=conversation.id, role=MessageRole.ASSISTANT, content='new')
    repo.save_message(new_reply)
    conversation.slot_active = False
    repo.db.commit()
    with pytest.raises(ConversationLocked):
        repo.mark_replies_read(conversation.id, owner.id, [new_reply.id])
    owner.is_guest = False
    repo.db.commit()
    assert repo.has_unread_replies(owner.id)
    repo.mark_replies_read(conversation.id, owner.id, [new_reply.id])
    assert not repo.has_unread_replies(owner.id)


def test_api_requires_auth_validates_ids_and_preserves_ownership(records):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from domains.auth.dependencies import get_current_user
    from domains.conversation.router import router, get_conversation_service
    from domains.conversation.service import ConversationService

    repo, owner, conversation, (reply, _, foreign) = records
    # 라우터의 sync dependency가 실행되는 스레드에서도 같은 DB 연결을 사용해요.
    from sqlalchemy.pool import StaticPool
    engine = create_engine('sqlite://', poolclass=StaticPool, connect_args={'check_same_thread': False})
    Base.metadata.create_all(engine)
    with Session(engine) as db:
        db.add(ProfileModel(id=owner.id, name='member', is_guest=False))
        db.flush()
        db.add(ConversationModel(id=conversation.id, user_id=owner.id))
        db.flush()
        db.add(MessageModel(id=reply.id, conversation_id=conversation.id, role=MessageRole.ASSISTANT, content='reply'))
        db.commit()
        app = FastAPI()
        app.include_router(router)
        app.dependency_overrides[get_conversation_service] = lambda: ConversationService(ConversationRepository(db))
        with TestClient(app) as client:
            assert client.get('/api/conversations/unread/').status_code in (401, 403)
            app.dependency_overrides[get_current_user] = lambda: owner
            assert client.get('/api/conversations/unread/').json()['data'] == {'has_unread': True}
            path = f'/api/conversations/{conversation.id}/read/'
            assert client.post(path, json={'message_ids': []}).status_code == 422
            assert client.post(path, json={'message_ids': ['invalid']}).status_code == 422
            assert client.post(path, json={'message_ids': [reply.id] * 101}).status_code == 422
            assert client.post(path, json={'message_ids': [foreign.id]}).json()['data']['has_unread']
            assert not client.post(path, json={'message_ids': [reply.id]}).json()['data']['has_unread']
    engine.dispose()


def test_conversation_list_marks_only_owned_unread_replies(records):
    from domains.conversation.service import ConversationService

    repo, owner, conversation, (reply, _, foreign) = records
    service = ConversationService(repo)
    result = service.get_conversations(owner.id)
    assert len(result.results) == 1
    assert result.results[0].has_unread_reply is True
    repo.mark_replies_read(conversation.id, owner.id, [reply.id])
    assert service.get_conversations(owner.id).results[0].has_unread_reply is False
    repo.save_message(MessageModel(id=str(uuid4()), conversation_id=conversation.id,
                                  role=MessageRole.ASSISTANT, content='next'))
    owner.is_guest = True
    repo.db.commit()
    assert service.get_conversations(owner.id).results[0].has_unread_reply is False
    assert foreign.read_at is None
