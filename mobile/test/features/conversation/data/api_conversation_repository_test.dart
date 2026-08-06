import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('posts free-chat start metadata', () async {
    final _ConversationHttpClientAdapter adapter =
        _ConversationHttpClientAdapter();
    final ApiConversationRepository repository = _repository(adapter);

    final ConversationResponse response = await repository.startFreeChat(
      firstMessage: 'I liked the game.',
      searchContext: 'Lotte won 8-3.',
      topic: '롯데 자이언츠 최근 경기',
      conversationDirection: 'CASUAL_CHAT',
      selectedQuestion: 'What stood out?',
    );

    expect(response.conversationId, 'conversation-id');
    expect(
      adapter.lastRequest?.uri.path,
      '/api/conversations/start/free-chat/',
    );
    expect(adapter.lastRequest?.data, <String, Object?>{
      'first_message': 'I liked the game.',
      'search_context': 'Lotte won 8-3.',
      'topic': '롯데 자이언츠 최근 경기',
      'conversation_direction': 'CASUAL_CHAT',
      'selected_question': 'What stood out?',
    });
  });

  test('loads messages and sends a text conversation turn', () async {
    final _ConversationHttpClientAdapter adapter =
        _ConversationHttpClientAdapter();
    final ApiConversationRepository repository = _repository(adapter);

    final PaginatedMessages page = await repository.listMessages(
      'conversation-id',
    );
    final MultimodalMessageResponse response = await repository.sendTextTurn(
      conversationId: 'conversation-id',
      text: 'Hello again',
    );

    expect(page.results.single.content, 'Hello!');
    expect(response.response, 'AI response');
    expect(response.inputMode, ConversationInputMode.text);
    expect(response.transcript, 'Hello again');
    expect(
      adapter.requests.last.uri.path,
      '/api/conversations/conversation-id/turn/',
    );
    expect(adapter.requests.last.data, <String, Object?>{
      'text': 'Hello again',
      'include_audio_response': false,
    });
  });

  test('sends an audio conversation turn as multipart form data', () async {
    final _ConversationHttpClientAdapter adapter =
        _ConversationHttpClientAdapter();
    final ApiConversationRepository repository = _repository(adapter);

    final MultimodalMessageResponse response = await repository.sendAudioTurn(
      conversationId: 'conversation-id',
      audioFile: const ConversationAudioFile(
        bytes: <int>[1, 2, 3],
        filename: 'recording.webm',
        contentType: 'audio/webm',
      ),
    );

    final RequestOptions request = adapter.lastRequest!;
    final FormData formData = request.data as FormData;
    expect(response.inputMode, ConversationInputMode.audio);
    expect(response.transcript, 'I want to order a latte.');
    expect(request.uri.path, '/api/conversations/conversation-id/turn/');
    expect(
      request.contentType,
      startsWith(Headers.multipartFormDataContentType),
    );
    expect(formData.fields.single.key, 'include_audio_response');
    expect(formData.fields.single.value, 'false');
    expect(formData.files.single.key, 'audio_file');
    expect(formData.files.single.value.filename, 'recording.webm');
    expect(formData.files.single.value.contentType.toString(), 'audio/webm');
  });

  test('starts free-chat with audio as multipart form data', () async {
    final _ConversationHttpClientAdapter adapter =
        _ConversationHttpClientAdapter();
    final ApiConversationRepository repository = _repository(adapter);

    final MultimodalConversationResponse response = await repository
        .startFreeChatWithAudio(
          audioFile: const ConversationAudioFile(
            bytes: <int>[1, 2, 3],
            filename: 'answer.m4a',
            contentType: 'audio/m4a',
          ),
          searchContext: 'Lotte won 8-3.',
          topic: '롯데 자이언츠 최근 경기',
          conversationDirection: 'CASUAL_CHAT',
          selectedQuestion: 'What stood out?',
        );

    final RequestOptions request = adapter.lastRequest!;
    final FormData formData = request.data as FormData;
    expect(response.inputMode, ConversationInputMode.audio);
    expect(response.transcript, 'I want to talk about the game.');
    expect(request.uri.path, '/api/conversations/start/free-chat/');
    expect(
      request.contentType,
      startsWith(Headers.multipartFormDataContentType),
    );
    expect(_fieldValue(formData, 'search_context'), 'Lotte won 8-3.');
    expect(_fieldValue(formData, 'topic'), '롯데 자이언츠 최근 경기');
    expect(_fieldValue(formData, 'conversation_direction'), 'CASUAL_CHAT');
    expect(_fieldValue(formData, 'selected_question'), 'What stood out?');
    expect(_fieldValue(formData, 'include_audio_response'), 'false');
    expect(formData.files.single.key, 'audio_file');
    expect(formData.files.single.value.filename, 'answer.m4a');
    expect(formData.files.single.value.contentType.toString(), 'audio/m4a');
  });
}

String? _fieldValue(FormData formData, String key) {
  for (final MapEntry<String, String> field in formData.fields) {
    if (field.key == key) {
      return field.value;
    }
  }
  return null;
}

ApiConversationRepository _repository(_ConversationHttpClientAdapter adapter) {
  final ApiClient client = ApiClient.create(
    tokenStorage: const _MemoryTokenStorage(),
    baseUrl: 'https://example.com/api/',
  );
  client.dio.httpClientAdapter = adapter;
  return ApiConversationRepository(client);
}

class _ConversationHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  RequestOptions? get lastRequest => requests.isEmpty ? null : requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final String path = options.uri.path;
    final Map<String, dynamic> data = switch (path) {
      '/api/conversations/conversation-id/messages/' => <String, dynamic>{
        'results': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'message-id',
            'conversation_id': 'conversation-id',
            'role': 'assistant',
            'content': 'Hello!',
            'created_at': '2026-07-02T00:00:00Z',
            'grammar_feedback': null,
          },
        ],
        'pagination': <String, dynamic>{
          'limit': 50,
          'offset': 0,
          'total_count': 1,
          'has_more': false,
          'next_offset': null,
        },
      },
      '/api/conversations/conversation-id/message/' => <String, dynamic>{
        'message_id': 'user-id',
        'response': 'AI response',
        'grammar_feedback': null,
        'turn_count': 2,
      },
      '/api/conversations/conversation-id/turn/' => <String, dynamic>{
        'message_id': 'user-id',
        'response': 'AI response',
        'grammar_feedback': null,
        'turn_count': 2,
        'input_mode': options.data is FormData ? 'audio' : 'text',
        'transcript': options.data is FormData
            ? 'I want to order a latte.'
            : 'Hello again',
        'audio': null,
        'audio_error': null,
      },
      _ => <String, dynamic>{
        'conversation_id': 'conversation-id',
        'message_id': 'message-id',
        'conversation_type': 'FREE_CHAT',
        'role_character': null,
        'response': 'Hello!',
        'grammar_feedback': null,
        'input_mode': options.data is FormData ? 'audio' : 'text',
        'transcript': options.data is FormData
            ? 'I want to talk about the game.'
            : 'I liked the game.',
        'audio': null,
        'audio_error': null,
      },
    };
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'success': true, 'data': data}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements TokenStorage {
  const _MemoryTokenStorage();

  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> readAccessToken() async => 'access-token';

  @override
  Future<String?> readDeviceId() async => 'installation-id';

  @override
  Future<AuthTokens?> readTokens() async => null;

  @override
  Future<void> writeDeviceId(String deviceId) async {}

  @override
  Future<void> writeTokens(AuthTokens tokens) async {}
}
