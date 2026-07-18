import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'auth repository fetches the backend profile with Supabase bearer token',
    () async {
      final ApiClient client = ApiClient.create(
        tokenProvider: const _StaticSessionProvider('supabase-access-token'),
        sessionRefreshProvider: const _StaticSessionProvider(
          'supabase-access-token',
        ),
        baseUrl: 'https://example.com/api/',
      );
      final _AuthHttpClientAdapter adapter = _AuthHttpClientAdapter();
      client.dio.httpClientAdapter = adapter;
      addTearDown(client.close);
      final ApiAuthRepository repository = ApiAuthRepository(client);

      final UserProfile user = await repository.getCurrentUser();

      expect(user.email, 'learner@example.com');
      expect(adapter.requests.single.uri.path, '/api/auth/me');
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer supabase-access-token',
      );
    },
  );
}

class _AuthHttpClientAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'user-id',
          'email': 'learner@example.com',
          'name': 'Learner',
          'is_active': true,
          'oauth_provider': 'google',
          'created_at': '2026-06-23T00:00:00Z',
          'updated_at': '2026-06-23T00:00:00Z',
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
