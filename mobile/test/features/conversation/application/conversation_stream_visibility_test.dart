import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/api_client.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audio failure reveals the buffered answer', () async {
    final adapter = _TurnStreamAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'));
    dio.httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _StreamingRepository(ApiClient(dio)),
        ),
        conversationAudioPlayerProvider.overrideWithValue(_RecordingPlayer()),
      ],
    );
    addTearDown(container.dispose);
    final provider = conversationControllerProvider('conversation-id');
    await container.read(provider.future);
    final sending = container.read(provider.notifier).send('Question');
    await adapter.requested.future;
    adapter.event('turn_started', 0);
    adapter.event('text_delta', 1, <String, Object?>{'delta': 'Hello. More.'});
    adapter.event('audio_error', 2, <String, Object?>{
      'segment_index': 0,
      'code': 'TTS_FAILED',
    });
    adapter.event('turn_completed', 3, <String, Object?>{
      'conversation_id': 'conversation-id',
      'assistant_message_id': 'assistant-id',
      'text': 'Hello. More.',
      'audio_status': 'failed',
    });
    await adapter.closeEvents();
    await sending;
    final state = container.read(provider).requireValue;
    expect(state.messages.last.content, 'Hello. More.');
    expect(state.assistantAudioStatus, AssistantAudioStatus.unavailable);
  });

  test(
    'existing conversation reveals a sentence only when its audio starts',
    () async {
      final adapter = _TurnStreamAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.com/api/'));
      dio.httpClientAdapter = adapter;
      final player = _RecordingPlayer();
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _StreamingRepository(ApiClient(dio)),
          ),
          conversationAudioPlayerProvider.overrideWithValue(player),
        ],
      );
      addTearDown(container.dispose);
      final provider = conversationControllerProvider('conversation-id');
      await container.read(provider.future);
      final controller = container.read(provider.notifier);
      final sending = controller.send('How are you?');
      await adapter.requested.future;
      expect(adapter.traceId, matches(RegExp(r'^[a-f0-9]{32}$')));

      adapter.event('turn_started', 0);
      adapter.event('user_message_committed', 1, <String, Object?>{
        'conversation_id': 'conversation-id',
        'user_message_id': 'user-id',
        'text': 'How are you?',
      });
      adapter.event('text_delta', 2, <String, Object?>{'delta': 'Hello. '});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(provider).requireValue.messages.last.role,
        ConversationMessageRole.user,
      );
      expect(container.read(provider).requireValue.isSending, isTrue);
      expect(player.playCount, 0);

      adapter.event('audio_segment', 3, <String, Object?>{
        'segment_index': 0,
        'text': 'Hello.',
        'content_type': 'audio/mpeg',
        'format': 'mp3',
        'base64': 'AQID',
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(player.playCount, 0);
      expect(
        container.read(provider).requireValue.messages.last.content,
        'Hello.',
      );
      controller.onAssistantTextFrameReady(
        container.read(provider).requireValue.messages.last.id,
        1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(player.playCount, 1);
      expect(container.read(provider).requireValue.isSending, isTrue);

      adapter.event('text_delta', 4, <String, Object?>{
        'delta': 'How are you?',
      });
      adapter.event('audio_segment', 5, <String, Object?>{
        'segment_index': 1,
        'text': 'How are you?',
        'content_type': 'audio/mpeg',
        'format': 'mp3',
        'base64': 'AQID',
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(provider).requireValue.messages.last.content,
        'Hello.',
      );
      adapter.event('turn_completed', 6, <String, Object?>{
        'conversation_id': 'conversation-id',
        'assistant_message_id': 'assistant-id',
        'text': 'Hello. How are you?',
        'audio_status': 'completed',
      });
      await adapter.closeEvents();
      await sending;
      expect(container.read(provider).requireValue.isSending, isFalse);
      expect(
        container.read(provider).requireValue.messages.last.content,
        'Hello.',
      );
      player.finishFirst();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        container.read(provider).requireValue.messages.last.content,
        'Hello. How are you?',
      );
      expect(player.playCount, 1);
      controller.onAssistantTextFrameReady('assistant-id', 'Hello. '.length);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(player.playCount, 1);
      controller.onAssistantTextFrameReady('assistant-id', 'Hello. H'.length);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(player.playCount, 2);
    },
  );
}

class _StreamingRepository extends ApiConversationRepository {
  _StreamingRepository(super.apiClient);

  @override
  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async => PaginatedMessages(
    results: const <ConversationMessage>[],
    pagination: Pagination(
      limit: limit,
      offset: offset,
      totalCount: 0,
      hasMore: false,
    ),
  );
}

class _TurnStreamAdapter implements HttpClientAdapter {
  final requested = Completer<void>();
  final _events = StreamController<Uint8List>();
  String? traceId;

  void event(String name, int seq, [Map<String, Object?> fields = const {}]) {
    _events.add(
      Uint8List.fromList(
        utf8.encode(
          '${jsonEncode(<String, Object?>{'event': name, 'seq': seq, 'turn_id': 'turn-id', 'attempt_id': 'attempt-id', ...fields})}\n',
        ),
      ),
    );
  }

  Future<void> closeEvents() => _events.close();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode(<String, Object?>{'success': true, 'data': <Object>[]}),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    }
    traceId = options.headers['X-Request-ID'] as String?;
    if (!requested.isCompleted) requested.complete();
    return ResponseBody(
      _events.stream,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/x-ndjson'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingPlayer implements ConversationAudioPlayer {
  int playCount = 0;
  final Completer<void> _firstFinished = Completer<void>();

  void finishFirst() => _firstFinished.complete();

  @override
  Future<void> play(VoiceAudioResponse audio) async {
    playCount++;
    if (playCount == 1) await _firstFinished.future;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
