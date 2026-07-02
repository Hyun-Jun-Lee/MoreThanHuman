import 'package:curitalk/features/conversation/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses conversation start response', () {
    final ConversationResponse response =
        ConversationResponse.fromJson(<String, dynamic>{
          'conversation_id': 'conversation-id',
          'message_id': 'message-id',
          'conversation_type': 'FREE_CHAT',
          'role_character': null,
          'response': 'That sounds interesting. Tell me more.',
          'grammar_feedback': null,
        });

    expect(response.conversationId, 'conversation-id');
    expect(response.messageId, 'message-id');
    expect(response.conversationType, ConversationType.freeChat);
    expect(response.response, contains('interesting'));
  });

  test('parses message list with nested grammar feedback', () {
    final PaginatedMessages page = PaginatedMessages.fromJson(<String, dynamic>{
      'results': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'message-id',
          'conversation_id': 'conversation-id',
          'role': 'user',
          'content': 'I was surprise.',
          'created_at': '2026-07-02T00:00:00Z',
          'grammar_feedback': _feedback(hasErrors: true),
        },
      ],
      'pagination': <String, dynamic>{
        'limit': 50,
        'offset': 0,
        'total_count': 1,
        'has_more': false,
        'next_offset': null,
      },
    });

    expect(page.results.single.role, ConversationMessageRole.user);
    expect(
      page.results.single.grammarFeedback?.correctedText,
      'I was surprised.',
    );
    expect(page.pagination.totalCount, 1);
  });

  test('rejects unknown message role', () {
    expect(
      () => ConversationMessage.fromJson(<String, dynamic>{
        'id': 'message-id',
        'conversation_id': 'conversation-id',
        'role': 'alien',
        'content': 'Hello',
        'created_at': '2026-07-02T00:00:00Z',
        'grammar_feedback': null,
      }),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _feedback({required bool hasErrors}) {
  return <String, dynamic>{
    'id': 'feedback-id',
    'message_id': 'message-id',
    'original_text': 'I was surprise.',
    'corrected_text': 'I was surprised.',
    'has_errors': hasErrors,
    'errors': hasErrors
        ? <Map<String, dynamic>>[
            <String, dynamic>{
              'original': 'surprise',
              'corrected': 'surprised',
              'explanation': 'Use the past participle after was.',
            },
          ]
        : <Map<String, dynamic>>[],
    'created_at': '2026-07-02T00:00:01Z',
  };
}
