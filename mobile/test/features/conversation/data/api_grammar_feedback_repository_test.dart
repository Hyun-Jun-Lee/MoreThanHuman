import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns completed feedback on 200', () async {
    final ApiGrammarFeedbackRepository repository = _repository(
      _GrammarHttpClientAdapter(statusCode: 200),
    );

    final GrammarFeedbackLookupResult result = await repository.fetchFeedback(
      'message-id',
    );

    expect(result, isA<GrammarFeedbackFound>());
    expect(
      (result as GrammarFeedbackFound).feedback.correctedText,
      'I was surprised.',
    );
  });

  test('returns pending on 404', () async {
    final ApiGrammarFeedbackRepository repository = _repository(
      _GrammarHttpClientAdapter(statusCode: 404),
    );

    final GrammarFeedbackLookupResult result = await repository.fetchFeedback(
      'message-id',
    );

    expect(result, isA<GrammarFeedbackPending>());
  });
}

ApiGrammarFeedbackRepository _repository(_GrammarHttpClientAdapter adapter) {
  final ApiClient client = ApiClient.create(
    tokenStorage: const _MemoryTokenStorage(),
    baseUrl: 'https://example.com/api/',
  );
  client.dio.httpClientAdapter = adapter;
  return ApiGrammarFeedbackRepository(client);
}

class _GrammarHttpClientAdapter implements HttpClientAdapter {
  const _GrammarHttpClientAdapter({required this.statusCode});

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (statusCode == 404) {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'detail': 'Not found'}),
        404,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'feedback-id',
          'message_id': 'message-id',
          'original_text': 'I was surprise.',
          'corrected_text': 'I was surprised.',
          'has_errors': true,
          'errors': <Map<String, dynamic>>[
            <String, dynamic>{
              'original': 'surprise',
              'corrected': 'surprised',
              'explanation': 'Use the past participle after was.',
            },
          ],
          'created_at': '2026-07-02T00:00:00Z',
        },
      }),
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
