import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/home/data/api_language_snack_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

void main() {
  test(
    'repository requests published snacks through the authenticated API client',
    () async {
      final ApiClient client = ApiClient.create(
        tokenStorage: const _MemoryTokenStorage('access-token'),
        baseUrl: 'https://example.com/api/',
      );
      final _LanguageSnackHttpClientAdapter adapter =
          _LanguageSnackHttpClientAdapter();
      client.dio.httpClientAdapter = adapter;
      addTearDown(client.close);
      final ApiLanguageSnackRepository repository = ApiLanguageSnackRepository(
        client,
      );

      final snacks = await repository.listPublished();

      expect(snacks.single.leftWord, 'crisps');
      expect(adapter.lastRequest?.uri.path, '/api/language-snacks/');
      expect(
        adapter.lastRequest?.headers['Authorization'],
        'Bearer access-token',
      );
      expect(
        adapter.lastRequest?.headers.containsKey('X-Operations-Key'),
        isFalse,
      );
    },
  );

  test('repository rejects a non-list snack payload', () async {
    final ApiClient client = ApiClient.create(
      tokenStorage: const _MemoryTokenStorage('access-token'),
      baseUrl: 'https://example.com/api/',
    );
    client.dio.httpClientAdapter = _LanguageSnackHttpClientAdapter(
      data: <String, dynamic>{},
    );
    addTearDown(client.close);
    final ApiLanguageSnackRepository repository = ApiLanguageSnackRepository(
      client,
    );

    await expectLater(repository.listPublished(), throwsA(isA<ApiException>()));
  });
}

class _LanguageSnackHttpClientAdapter implements HttpClientAdapter {
  _LanguageSnackHttpClientAdapter({Object? data})
    : _data = data ?? <Object?>[_snackJson()];

  final Object? _data;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'success': true, 'data': _data}),
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

Map<String, dynamic> _snackJson() => <String, dynamic>{
  'id': '550e8400-e29b-41d4-a716-446655440000',
  'category': 'Vocabulary',
  'left_label': 'British English',
  'left_word': 'crisps',
  'right_label': 'American English',
  'right_word': 'chips',
  'meaning': '둘 다 감자칩을 뜻해요.',
  'example': 'Would you like a bag of crisps?',
  'published_at': '2026-09-06T12:00:00Z',
  'created_at': '2026-09-06T12:00:00Z',
  'updated_at': '2026-09-06T12:00:00Z',
};
