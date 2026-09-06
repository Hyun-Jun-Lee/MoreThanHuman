import 'package:curitalk/features/home/home.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a backend conversation summary', () {
    final ConversationSummary conversation =
        ConversationSummary.fromJson(<String, dynamic>{
          'id': 'conversation-id',
          'title': 'Osaka food trip',
          'conversation_type': 'FREE_CHAT',
          'role_character': null,
          'message_count': 8,
          'status': 'ACTIVE',
          'created_at': '2026-06-23T10:00:00Z',
          'updated_at': '2026-06-24T10:00:00Z',
        });

    expect(conversation.title, 'Osaka food trip');
    expect(conversation.category, 'Free chat');
    expect(conversation.preview, '8 messages · Continue speaking');
  });

  test('uses role character when a roleplay title is absent', () {
    final ConversationSummary conversation =
        ConversationSummary.fromJson(<String, dynamic>{
          'id': 'conversation-id',
          'title': null,
          'conversation_type': 'ROLE_PLAYING',
          'role_character': 'Cafe barista',
          'message_count': 1,
          'status': 'COMPLETED',
          'updated_at': '2026-06-24T10:00:00Z',
        });

    expect(conversation.title, 'Cafe barista');
    expect(conversation.category, 'Roleplay');
    expect(conversation.preview, '1 message · Completed');
  });

  test('rejects unknown conversation enum values', () {
    expect(
      () => ConversationSummary.fromJson(<String, dynamic>{
        'id': 'conversation-id',
        'title': 'Unknown',
        'conversation_type': 'UNKNOWN',
        'message_count': 0,
        'status': 'ACTIVE',
        'updated_at': '2026-06-24T10:00:00Z',
      }),
      throwsFormatException,
    );
  });
}
