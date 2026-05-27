from domains.conversation.service import ConversationService


def test_free_chat_prompt_includes_topic_prep_handoff_context():
    service = ConversationService(repository=None, grammar_repository=None)

    prompt = service.build_free_chat_prompt(
        search_context="The Dodgers won with a late home run.",
        topic="recent Dodgers game result",
        conversation_direction="DEBATE",
        selected_question="Was the manager's late-game decision right?",
    )

    assert "Topic Prep Handoff" in prompt
    assert "recent Dodgers game result" in prompt
    assert "DEBATE" in prompt
    assert "Was the manager's late-game decision right?" in prompt
    assert "counterarguments" in prompt


def test_free_chat_prompt_without_topic_prep_keeps_existing_shape():
    service = ConversationService(repository=None, grammar_repository=None)

    prompt = service.build_free_chat_prompt(search_context=None)

    assert "Topic Prep Handoff" not in prompt
    assert "friendly and helpful English conversation learning assistant" in prompt
