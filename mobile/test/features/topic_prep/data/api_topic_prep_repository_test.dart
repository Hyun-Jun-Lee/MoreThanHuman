import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository posts a topic and parses the response', () async {
    final ApiClient client = ApiClient.create(
      tokenStorage: _MemoryTokenStorage('access-token'),
      baseUrl: 'https://example.com/api/',
    );
    final _TopicPrepHttpClientAdapter adapter = _TopicPrepHttpClientAdapter();
    client.dio.httpClientAdapter = adapter;
    addTearDown(client.close);
    final ApiTopicPrepRepository repository = ApiTopicPrepRepository(client);

    final TopicPrepResult result = await repository.prepareTopic(
      '최근 롯데 자이언츠 경기',
    );

    expect(result.ready, isTrue);
    expect(
      result.card?.directions.first.firstQuestionTranslations.first,
      '무엇이 눈에 띄었나요?',
    );
    expect(adapter.lastRequest?.uri.path, '/api/search/topic-prep/');
    expect(adapter.lastRequest?.data, <String, String>{
      'topic': '최근 롯데 자이언츠 경기',
    });
    expect(
      adapter.lastRequest?.headers['Authorization'],
      'Bearer access-token',
    );
  });

  test('stream repository yields summary before the complete card', () async {
    final ApiClient client = ApiClient.create(
      tokenStorage: _MemoryTokenStorage('access-token'),
      baseUrl: 'https://example.com/api/',
    );
    final _TopicPrepHttpClientAdapter adapter = _TopicPrepHttpClientAdapter();
    client.dio.httpClientAdapter = adapter;
    addTearDown(client.close);

    final List<TopicPrepStreamEvent> events = await ApiTopicPrepRepository(
      client,
    ).prepareTopicStream('퇴사').toList();

    expect(adapter.lastRequest?.uri.path, '/api/search/topic-prep/stream/');
    expect(
      adapter.lastRequest?.headers['Authorization'],
      'Bearer access-token',
    );
    expect(events.map((event) => event.summary), <String?>['퇴사에 관한 요약', null]);
    expect(events.last.result?.ready, isTrue);
  });
}

class _TopicPrepHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    final String body = jsonEncode(<String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'ready': true,
        'language': <String, String>{
          'native_language': 'ko',
          'target_language': 'en',
          'feedback_language': 'ko',
        },
        'card': <String, dynamic>{
          'topic': '최근 롯데 자이언츠 경기',
          'summary': 'Lotte won 8-3 after ending a losing streak.',
          'directions': <Map<String, dynamic>>[
            _direction('CASUAL_CHAT', 'Casual Chat'),
            _direction('DEBATE', 'Debate'),
            _direction('EXPLANATION_PRACTICE', 'Explain'),
          ],
          'sources': <Map<String, dynamic>>[
            <String, dynamic>{
              'title': 'Lotte game recap',
              'url': 'https://example.com/sports/lotte',
              'snippet': 'Lotte beat KIA 8-3.',
            },
          ],
          'quality': _quality(),
          'timestamp': '2026-07-02T00:00:00Z',
        },
        'quality': _quality(),
        'retry_guidance': null,
        'example_topics': <String>[],
      },
    });
    if (options.path.endsWith('/stream/')) {
      final Object? data = (jsonDecode(body) as Map<String, dynamic>)['data'];
      return ResponseBody.fromString(
        '${jsonEncode(<String, Object?>{'event': 'summary_ready', 'data': '퇴사에 관한 요약'})}\n'
        '${jsonEncode(<String, Object?>{'event': 'card_ready', 'data': data})}\n',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[
            'application/x-ndjson; charset=utf-8',
          ],
        },
      );
    }
    return ResponseBody.fromString(
      body,
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
  const _MemoryTokenStorage(this.accessToken);

  final String? accessToken;

  @override
  Future<void> clearTokens() async {}

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readDeviceId() async => 'installation-id';

  @override
  Future<AuthTokens?> readTokens() async => null;

  @override
  Future<void> writeDeviceId(String deviceId) async {}

  @override
  Future<void> writeTokens(AuthTokens tokens) async {}
}

Map<String, dynamic> _direction(String direction, String title) {
  return <String, dynamic>{
    'direction': direction,
    'title': title,
    'description': 'Practice with a $title tone.',
    'first_questions': <String>[
      'What stood out to you?',
      'Which detail would you explain first?',
      'What would you ask a friend about it?',
    ],
    'first_question_translations': <String>[
      '무엇이 눈에 띄었나요?',
      '어떤 부분을 먼저 설명하겠어요?',
      '친구에게 무엇을 물어보겠어요?',
    ],
  };
}

Map<String, dynamic> _quality() {
  return <String, dynamic>{
    'is_sufficient': true,
    'source_count': 3,
    'has_enough_sources': true,
    'relevance': true,
    'freshness': true,
    'specificity': true,
    'reason': null,
    'retry_suggestion': null,
  };
}
