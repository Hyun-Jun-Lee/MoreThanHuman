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
          'roleplay_difficulty': null,
          'response': 'That sounds interesting. Tell me more.',
          'grammar_feedback': null,
        });

    expect(response.conversationId, 'conversation-id');
    expect(response.messageId, 'message-id');
    expect(response.conversationType, ConversationType.freeChat);
    expect(response.roleplayDifficulty, isNull);
    expect(response.response, contains('interesting'));
  });

  test('parses roleplay difficulty from conversation start response', () {
    final ConversationResponse response =
        ConversationResponse.fromJson(<String, dynamic>{
          'conversation_id': 'conversation-id',
          'message_id': 'message-id',
          'conversation_type': 'ROLE_PLAYING',
          'role_character': 'a cafe barista',
          'roleplay_difficulty': 'CHALLENGE',
          'response': 'Welcome in.',
          'grammar_feedback': null,
        });

    expect(response.conversationType, ConversationType.rolePlaying);
    expect(response.roleCharacter, 'a cafe barista');
    expect(response.roleplayDifficulty, 'CHALLENGE');
  });

  test('parses multimodal text message response', () {
    final MultimodalMessageResponse response =
        MultimodalMessageResponse.fromJson(<String, dynamic>{
          'message_id': 'message-id',
          'response': 'Sure. What size would you like?',
          'grammar_feedback': null,
          'turn_count': 2,
          'input_mode': 'text',
          'transcript': 'I want to order a latte.',
          'audio': null,
          'audio_error': null,
        });

    expect(response.inputMode, ConversationInputMode.text);
    expect(response.transcript, 'I want to order a latte.');
    expect(response.audio, isNull);
    expect(response.audioError, isNull);
  });

  test('parses multimodal audio message response with audio metadata', () {
    final MultimodalMessageResponse response =
        MultimodalMessageResponse.fromJson(<String, dynamic>{
          'message_id': 'message-id',
          'response': 'Sure. What size would you like?',
          'grammar_feedback': null,
          'turn_count': 2,
          'input_mode': 'audio',
          'transcript': 'I want to order a latte.',
          'audio': <String, dynamic>{
            'content_type': 'audio/mpeg',
            'base64': 'AAA=',
            'format': 'mp3',
          },
          'audio_error': null,
        });

    expect(response.inputMode, ConversationInputMode.audio);
    expect(response.audio?.contentType, 'audio/mpeg');
    expect(response.audio?.base64, 'AAA=');
    expect(response.audio?.format, 'mp3');
  });

  test('parses multimodal conversation response with audio error', () {
    final MultimodalConversationResponse response =
        MultimodalConversationResponse.fromJson(<String, dynamic>{
          'conversation_id': 'conversation-id',
          'message_id': 'message-id',
          'conversation_type': 'FREE_CHAT',
          'role_character': null,
          'roleplay_difficulty': null,
          'response': 'That sounds interesting.',
          'grammar_feedback': null,
          'input_mode': 'audio',
          'transcript': 'I watched the game.',
          'audio': null,
          'audio_error': <String, dynamic>{
            'message': 'TTS unavailable.',
            'provider': 'openai',
          },
        });

    expect(response.inputMode, ConversationInputMode.audio);
    expect(response.transcript, 'I watched the game.');
    expect(response.audioError?.message, 'TTS unavailable.');
    expect(response.audioError?.provider, 'openai');
  });

  test('rejects unknown multimodal input mode', () {
    expect(
      () => MultimodalMessageResponse.fromJson(<String, dynamic>{
        'message_id': 'message-id',
        'response': 'AI response',
        'grammar_feedback': null,
        'turn_count': 2,
        'input_mode': 'video',
      }),
      throwsFormatException,
    );
  });

  test('rejects malformed voice audio metadata', () {
    expect(
      () => MultimodalMessageResponse.fromJson(<String, dynamic>{
        'message_id': 'message-id',
        'response': 'AI response',
        'grammar_feedback': null,
        'turn_count': 2,
        'input_mode': 'audio',
        'audio': <String, dynamic>{
          'content_type': 'audio/mpeg',
          'format': 'mp3',
        },
      }),
      throwsFormatException,
    );
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
