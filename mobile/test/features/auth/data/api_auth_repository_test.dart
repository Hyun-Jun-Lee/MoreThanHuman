import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auth repository follows the mobile authentication contract', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage();
    final ApiClient client = ApiClient.create(
      tokenStorage: storage,
      baseUrl: 'https://example.com/api/',
    );
    final _AuthHttpClientAdapter adapter = _AuthHttpClientAdapter();
    client.dio.httpClientAdapter = adapter;
    addTearDown(client.close);
    final ApiAuthRepository repository = ApiAuthRepository(client);

    final AuthTokens tokens = await repository.signInWithGoogleIdToken(
      idToken: 'google-id-token',
      deviceId: 'installation-id',
    );
    await storage.writeTokens(tokens);
    final UserProfile user = await repository.getCurrentUser();
    await repository.logout(
      refreshToken: tokens.refreshToken,
      deviceId: 'installation-id',
    );

    expect(tokens.refreshToken, 'refresh-token');
    expect(user.email, 'learner@example.com');
    expect(adapter.requests[0].data, <String, String>{
      'id_token': 'google-id-token',
      'device_id': 'installation-id',
    });
    expect(adapter.requests[0].headers.containsKey('Authorization'), isFalse);
    expect(adapter.requests[1].headers['Authorization'], 'Bearer access-token');
    expect(adapter.requests[2].headers.containsKey('Authorization'), isFalse);
  });
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
    final String path = options.uri.path;
    if (path.endsWith('/auth/google/mobile')) {
      return _response(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'access_token': 'access-token',
          'refresh_token': 'refresh-token',
          'token_type': 'bearer',
        },
      });
    }
    if (path.endsWith('/auth/me')) {
      return _response(<String, dynamic>{
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
      });
    }
    return _response(<String, dynamic>{
      'success': true,
      'data': <String, dynamic>{'ok': true},
    });
  }

  ResponseBody _response(Object body) {
    return ResponseBody.fromString(
      jsonEncode(body),
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
  AuthTokens? tokens;

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }

  @override
  Future<String?> readAccessToken() async => tokens?.accessToken;

  @override
  Future<String?> readDeviceId() async => 'installation-id';

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<void> writeDeviceId(String deviceId) async {}

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}
