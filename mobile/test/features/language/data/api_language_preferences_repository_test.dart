import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('updates language preferences through the backend API', () async {
    final ApiClient client = ApiClient.create(
      tokenProvider: const _StaticSessionProvider('supabase-access-token'),
      sessionRefreshProvider: const _StaticSessionProvider(
        'supabase-access-token',
      ),
      baseUrl: 'https://example.com/api/',
    );
    final _LanguageHttpClientAdapter adapter = _LanguageHttpClientAdapter();
    client.dio.httpClientAdapter = adapter;
    addTearDown(client.close);
    final ApiLanguagePreferencesRepository repository =
        ApiLanguagePreferencesRepository(client);

    final LearningLanguageContext updated = await repository
        .updateLanguagePreferences(
          const LearningLanguageContext(
            nativeLanguage: LearningLanguageCode.zh,
            targetLanguage: LearningLanguageCode.ko,
            feedbackLanguage: LearningLanguageCode.zh,
          ),
        );

    expect(updated.targetLanguage, LearningLanguageCode.ko);
    expect(adapter.requests.single.method, 'PUT');
    expect(
      adapter.requests.single.uri.path,
      '/api/auth/me/language-preferences',
    );
    expect(adapter.lastBody, contains('"native_language":"zh"'));
  });
}

class _LanguageHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];
  String? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final List<int> bodyBytes = await requestStream.expand((bytes) {
        return bytes;
      }).toList();
      lastBody = utf8.decode(bodyBytes);
    }
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'native_language': 'zh',
          'target_language': 'ko',
          'feedback_language': 'zh',
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

class _StaticSessionProvider
    implements AccessTokenProvider, SessionRefreshProvider {
  const _StaticSessionProvider(this.accessToken);

  final String? accessToken;

  @override
  Future<void> expireSession() async {}

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> refreshAccessToken({
    required String? previousAccessToken,
  }) async => accessToken;
}
