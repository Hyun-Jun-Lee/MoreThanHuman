import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/api_client.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('newly completed stream exposes replay before reopening', () async {
    final container = _container(_AudioReplayAdapter(), _ReplayPlayer());
    addTearDown(container.dispose);
    final provider = conversationControllerProvider('conversation-id');
    await container.read(provider.future);

    await container.read(provider.notifier).send('Hi');

    final message = container.read(provider).requireValue.messages.last;
    expect(message.id, 'new-assistant-id');
    expect(message.audioAvailable, isTrue);
    expect(message.audio, isNull);
  });

  test('reopened message replays segments in order', () async {
    final adapter = _AudioReplayAdapter();
    final player = _ReplayPlayer();
    final container = _container(adapter, player);
    addTearDown(container.dispose);
    final provider = conversationControllerProvider('conversation-id');
    final state = await container.read(provider.future);

    expect(state.messages.single.audioAvailable, isTrue);
    expect(state.messages.single.audio, isNull);
    await container.read(provider.notifier).playAssistantAudio('assistant-id');

    expect(adapter.replayRequests, 1);
    expect(player.played, <String>['AAA=', 'BBB=']);
  });

  test('stop cancels replay before the next segment', () async {
    final adapter = _AudioReplayAdapter();
    final gate = Completer<void>();
    final player = _ReplayPlayer(gate: gate);
    final container = _container(adapter, player);
    addTearDown(container.dispose);
    final provider = conversationControllerProvider('conversation-id');
    await container.read(provider.future);

    final replay = container
        .read(provider.notifier)
        .playAssistantAudio('assistant-id');
    while (player.played.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    await container.read(provider.notifier).stopAssistantAudio('assistant-id');
    await replay;

    expect(player.played, <String>['AAA=']);
    expect(player.stopCount, 1);
  });
}

ProviderContainer _container(
  _AudioReplayAdapter adapter,
  _ReplayPlayer player,
) {
  final client = ApiClient(
    Dio(BaseOptions(baseUrl: 'https://example.com/api/')),
  );
  client.dio.httpClientAdapter = adapter;
  return ProviderContainer(
    overrides: [
      conversationRepositoryProvider.overrideWithValue(
        ApiConversationRepository(client),
      ),
      conversationAudioPlayerProvider.overrideWithValue(player),
    ],
  );
}

class _AudioReplayAdapter implements HttpClientAdapter {
  int replayRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/turn/stream/')) {
      final events = <Map<String, Object>>[
        <String, Object>{'seq': 0, 'event': 'turn_started'},
        <String, Object>{
          'seq': 1,
          'event': 'user_message_committed',
          'user_message_id': 'new-user-id',
          'text': 'Hi',
        },
        <String, Object>{'seq': 2, 'event': 'text_delta', 'delta': 'Hello.'},
        <String, Object>{
          'seq': 3,
          'event': 'turn_completed',
          'assistant_message_id': 'new-assistant-id',
          'text': 'Hello.',
          'audio_status': 'completed',
        },
      ];
      return ResponseBody.fromString(
        '${events.map((event) => jsonEncode(<String, Object>{...event, 'turn_id': 'turn-id', 'attempt_id': 'attempt-id'})).join('\n')}\n',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/x-ndjson'],
        },
      );
    }
    if (path.endsWith('/audio/stream/')) {
      replayRequests++;
      final events = <Map<String, Object>>[
        <String, Object>{'seq': 0, 'event': 'audio_started'},
        <String, Object>{
          'seq': 1,
          'event': 'audio_segment',
          'segment_index': 0,
          'content_type': 'audio/mpeg',
          'format': 'mp3',
          'base64': 'AAA=',
        },
        <String, Object>{
          'seq': 2,
          'event': 'audio_segment',
          'segment_index': 1,
          'content_type': 'audio/mpeg',
          'format': 'mp3',
          'base64': 'BBB=',
        },
        <String, Object>{'seq': 3, 'event': 'audio_completed'},
      ];
      return ResponseBody.fromString(
        '${events.map(jsonEncode).join('\n')}\n',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/x-ndjson'],
        },
      );
    }
    final Object data = path.endsWith('/turns/')
        ? <Object>[]
        : <String, Object>{
            'results': <Map<String, Object>>[
              <String, Object>{
                'id': 'assistant-id',
                'conversation_id': 'conversation-id',
                'role': 'assistant',
                'content': 'Hello again.',
                'created_at': '2026-07-02T00:00:00Z',
                'audio_available': true,
              },
            ],
            'pagination': <String, Object?>{
              'limit': 40,
              'offset': 0,
              'total_count': 1,
              'has_more': false,
              'next_offset': null,
            },
          };
    return ResponseBody.fromString(
      jsonEncode(<String, Object>{'success': true, 'data': data}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ReplayPlayer implements ConversationAudioPlayer {
  _ReplayPlayer({this.gate});

  final Completer<void>? gate;
  final List<String> played = <String>[];
  int stopCount = 0;

  @override
  Future<void> play(VoiceAudioResponse audio) async {
    played.add(audio.base64);
    await gate?.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    final pending = gate;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<void> dispose() async {}
}
