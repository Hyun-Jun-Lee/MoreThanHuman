from domains.conversation.stream_audio import SentenceBuffer, completed_sentences


def test_first_sentence_is_ready_before_the_last_delta() -> None:
    buffer = SentenceBuffer()

    assert buffer.feed('"Hello."') == []
    assert buffer.feed(' How are you?') == ['"Hello."']
    assert buffer.finish() == ['How are you?']


def test_abbreviations_and_decimals_are_not_sentence_boundaries() -> None:
    text = 'Dr. Smith lives in the U.S. He paid 3.14 dollars. Next question?'
    buffer = SentenceBuffer()

    assert buffer.feed(text) == [
        'Dr. Smith lives in the U.S. He paid 3.14 dollars.'
    ]
    assert buffer.finish() == ['Next question?']
    assert completed_sentences(text) == [
        'Dr. Smith lives in the U.S. He paid 3.14 dollars.',
        'Next question?',
    ]


def test_korean_sentence_with_closing_quote_is_ready_early() -> None:
    buffer = SentenceBuffer()

    assert buffer.feed('「안녕하세요。」') == []
    assert buffer.feed(' 다음 질문이에요?') == ['「안녕하세요。」']
    assert buffer.finish() == ['다음 질문이에요?']
