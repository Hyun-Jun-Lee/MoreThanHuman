import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'core providers create the API client with Supabase session providers',
    () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          supabaseAuthServiceProvider.overrideWithValue(
            _FakeSessionProvider(accessToken: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final ApiClient client = container.read(apiClientProvider);

      expect(client.dio.options.baseUrl, 'http://localhost:8010/api/');
      expect(client.dio.interceptors, contains(isA<AuthTokenInterceptor>()));
      expect(client.dio.interceptors, contains(isA<TokenRefreshInterceptor>()));
    },
  );

  test('ApiClient adds a Supabase Bearer token and parses data', () async {
    final ApiClient client = ApiClient.create(
      tokenProvider: _FakeSessionProvider(accessToken: 'supabase-access-token'),
      sessionRefreshProvider: _FakeSessionProvider(
        accessToken: 'supabase-access-token',
      ),
      baseUrl: 'https://example.com/api',
    );
    final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter(
      response: <String, dynamic>{
        'success': true,
        'message': 'loaded',
        'data': <String, dynamic>{'name': 'Curitalk'},
      },
    );
    client.dio.httpClientAdapter = adapter;
    addTearDown(client.close);

    final ApiResponse<String> response = await client.get<String>(
      '/auth/me',
      decodeData: (Object? json) {
        return (json! as Map<String, dynamic>)['name']! as String;
      },
    );

    expect(response.data, 'Curitalk');
    expect(response.message, 'loaded');
    expect(
      adapter.lastRequest?.uri.toString(),
      'https://example.com/api/auth/me',
    );
    expect(
      adapter.lastRequest?.headers['Authorization'],
      'Bearer supabase-access-token',
    );
  });

  test('ApiClient can explicitly skip authentication', () async {
    final ApiClient client = ApiClient.create(
      tokenProvider: _FakeSessionProvider(accessToken: 'supabase-access-token'),
      sessionRefreshProvider: _FakeSessionProvider(
        accessToken: 'supabase-access-token',
      ),
      baseUrl: 'https://example.com/api/',
    );
    final _FakeHttpClientAdapter adapter = _FakeHttpClientAdapter(
      response: <String, dynamic>{'success': true, 'data': true},
    );
    client.dio.httpClientAdapter = adapter;
    addTearDown(client.close);

    await client.get<bool>(
      'health',
      requiresAuth: false,
      decodeData: (Object? json) => json! as bool,
    );

    expect(adapter.lastRequest?.headers.containsKey('Authorization'), isFalse);
  });

  test('ApiClient maps FastAPI authentication errors', () async {
    final ApiClient client = ApiClient.create(
      tokenProvider: _FakeSessionProvider(accessToken: null),
      sessionRefreshProvider: _FakeSessionProvider(accessToken: null),
      baseUrl: 'https://example.com/api/',
    );
    client.dio.httpClientAdapter = _FakeHttpClientAdapter(
      statusCode: 401,
      response: <String, dynamic>{'detail': 'Invalid credentials'},
    );
    addTearDown(client.close);

    await expectLater(
      client.get<void>('auth/me', decodeData: (_) {}),
      throwsA(
        isA<ApiException>()
            .having(
              (ApiException error) => error.kind,
              'kind',
              ApiErrorKind.unauthorized,
            )
            .having((ApiException error) => error.statusCode, 'statusCode', 401)
            .having(
              (ApiException error) => error.message,
              'message',
              'Invalid credentials',
            ),
      ),
    );
  });

  test('ApiClient maps connection failures', () async {
    final ApiClient client = ApiClient.create(
      tokenProvider: _FakeSessionProvider(accessToken: null),
      sessionRefreshProvider: _FakeSessionProvider(accessToken: null),
      baseUrl: 'https://example.com/api/',
    );
    client.dio.httpClientAdapter = _FakeHttpClientAdapter(
      response: <String, dynamic>{},
      connectionFails: true,
    );
    addTearDown(client.close);

    await expectLater(
      client.get<void>('health', decodeData: (_) {}),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.kind,
          'kind',
          ApiErrorKind.network,
        ),
      ),
    );
  });

  test(
    '401 refreshes Supabase session and retries once with the new token',
    () async {
      final _FakeSessionProvider sessionProvider = _FakeSessionProvider(
        accessToken: 'expired-access',
        refreshedAccessToken: 'new-access',
      );
      final ApiClient client = ApiClient.create(
        tokenProvider: sessionProvider,
        sessionRefreshProvider: sessionProvider,
        baseUrl: 'https://example.com/api/',
      );
      final List<String?> authorizationHeaders = <String?>[];
      client.dio.httpClientAdapter = _CallbackHttpClientAdapter((
        RequestOptions request,
      ) {
        final String? authorization =
            request.headers['Authorization'] as String?;
        authorizationHeaders.add(authorization);
        if (authorization == 'Bearer expired-access') {
          return _jsonResponse(<String, dynamic>{
            'detail': 'Expired token',
          }, statusCode: 401);
        }
        return _jsonResponse(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'name': 'Curitalk'},
        });
      });
      addTearDown(client.close);

      final ApiResponse<String> response = await client.get<String>(
        'auth/me',
        decodeData: (Object? json) =>
            (json! as Map<String, dynamic>)['name']! as String,
      );

      expect(response.data, 'Curitalk');
      expect(sessionProvider.refreshCount, 1);
      expect(authorizationHeaders, <String?>[
        'Bearer expired-access',
        'Bearer new-access',
      ]);
    },
  );

  test(
    'concurrent 401 responses share one Supabase refresh operation',
    () async {
      final _FakeSessionProvider sessionProvider = _FakeSessionProvider(
        accessToken: 'expired-access',
        refreshedAccessToken: 'new-access',
        refreshDelay: const Duration(milliseconds: 20),
      );
      final ApiClient client = ApiClient.create(
        tokenProvider: sessionProvider,
        sessionRefreshProvider: sessionProvider,
        baseUrl: 'https://example.com/api/',
      );
      client.dio.httpClientAdapter = _CallbackHttpClientAdapter((
        RequestOptions request,
      ) {
        if (request.headers['Authorization'] == 'Bearer expired-access') {
          return _jsonResponse(<String, dynamic>{
            'detail': 'Expired token',
          }, statusCode: 401);
        }
        return _jsonResponse(<String, dynamic>{'success': true, 'data': true});
      });
      addTearDown(client.close);

      final List<ApiResponse<bool>>
      responses = await Future.wait(<Future<ApiResponse<bool>>>[
        client.get<bool>('conversations', decodeData: (json) => json! as bool),
        client.get<bool>('grammar/stats', decodeData: (json) => json! as bool),
      ]);

      expect(responses.map((response) => response.data), everyElement(isTrue));
      expect(sessionProvider.refreshCount, 1);
    },
  );

  test('failed Supabase refresh expires the session', () async {
    final _FakeSessionProvider sessionProvider = _FakeSessionProvider(
      accessToken: 'expired-access',
    );
    int expirationCount = 0;
    final AuthSessionCoordinator sessionCoordinator = AuthSessionCoordinator()
      ..addExpirationListener(() => expirationCount += 1);
    final ApiClient client = ApiClient.create(
      tokenProvider: sessionProvider,
      sessionRefreshProvider: sessionProvider,
      baseUrl: 'https://example.com/api/',
      sessionCoordinator: sessionCoordinator,
    );
    client.dio.httpClientAdapter = _FakeHttpClientAdapter(
      statusCode: 401,
      response: <String, dynamic>{'detail': 'Expired token'},
    );
    addTearDown(client.close);

    await expectLater(
      client.get<void>('auth/me', decodeData: (_) {}),
      throwsA(isA<ApiException>()),
    );

    expect(sessionProvider.expireCount, 1);
    expect(expirationCount, 1);
  });
}

ResponseBody _jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

typedef _RequestHandler =
    FutureOr<ResponseBody> Function(RequestOptions request);

class _CallbackHttpClientAdapter implements HttpClientAdapter {
  _CallbackHttpClientAdapter(this.handler);

  final _RequestHandler handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({
    required this.response,
    this.statusCode = 200,
    this.connectionFails = false,
  });

  final Object response;
  final int statusCode;
  final bool connectionFails;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (connectionFails) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return _jsonResponse(response, statusCode: statusCode);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeSessionProvider implements SupabaseAuthService {
  _FakeSessionProvider({
    required this.accessToken,
    this.refreshedAccessToken,
    this.refreshDelay = Duration.zero,
  });

  String? accessToken;
  final String? refreshedAccessToken;
  final Duration refreshDelay;
  int refreshCount = 0;
  int expireCount = 0;

  @override
  Stream<SupabaseSessionChange> get authStateChanges =>
      const Stream<SupabaseSessionChange>.empty();

  @override
  Future<void> expireSession() async {
    expireCount += 1;
    accessToken = null;
  }

  @override
  Future<bool> hasCurrentSession() async => accessToken != null;

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> refreshAccessToken({
    required String? previousAccessToken,
  }) async {
    refreshCount += 1;
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    accessToken = refreshedAccessToken;
    return accessToken;
  }

  @override
  Future<void> signInWithGoogleTokens({
    required String idToken,
    required String accessToken,
  }) async {
    this.accessToken = accessToken;
  }

  @override
  Future<void> signOut() => expireSession();
}
