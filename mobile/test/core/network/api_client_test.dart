import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core providers create the API client with overridden storage', () {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(_MemoryTokenStorage(null)),
      ],
    );
    addTearDown(container.dispose);

    final ApiClient client = container.read(apiClientProvider);

    expect(client.dio.options.baseUrl, 'http://localhost:8010/api/');
    expect(client.dio.interceptors, contains(isA<AuthTokenInterceptor>()));
    expect(client.dio.interceptors, contains(isA<TokenRefreshInterceptor>()));
  });

  test('ApiClient adds a Bearer token and parses data', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage('access-token');
    final ApiClient client = ApiClient.create(
      tokenStorage: storage,
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
      'Bearer access-token',
    );
  });

  test('ApiClient can explicitly skip authentication', () async {
    final ApiClient client = ApiClient.create(
      tokenStorage: _MemoryTokenStorage('access-token'),
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
      tokenStorage: _MemoryTokenStorage(null),
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
      tokenStorage: _MemoryTokenStorage(null),
      baseUrl: 'https://example.com/api/',
    );
    client.dio.httpClientAdapter = _FakeHttpClientAdapter(
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

  test('ApiClient refreshes rotated tokens and retries a 401 once', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage.withTokens(
      const AuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
      ),
      deviceId: 'installation-id',
    );
    final Dio refreshDio = Dio(
      BaseOptions(baseUrl: 'https://example.com/api/'),
    );
    final _CallbackHttpClientAdapter refreshAdapter =
        _CallbackHttpClientAdapter((RequestOptions request) {
          return _jsonResponse(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'access_token': 'new-access',
              'refresh_token': 'rotated-refresh',
              'token_type': 'bearer',
            },
          });
        });
    refreshDio.httpClientAdapter = refreshAdapter;
    final ApiClient client = ApiClient.create(
      tokenStorage: storage,
      baseUrl: 'https://example.com/api/',
      refreshDio: refreshDio,
    );
    final List<String?> authorizationHeaders = <String?>[];
    client.dio.httpClientAdapter = _CallbackHttpClientAdapter((
      RequestOptions request,
    ) {
      final String? authorization = request.headers['Authorization'] as String?;
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
      decodeData: (Object? json) {
        return (json! as Map<String, dynamic>)['name']! as String;
      },
    );

    expect(response.data, 'Curitalk');
    expect(refreshAdapter.requestCount, 1);
    expect(refreshAdapter.lastRequest?.data, <String, String>{
      'refresh_token': 'refresh-token',
      'device_id': 'installation-id',
    });
    expect(authorizationHeaders, <String?>[
      'Bearer expired-access',
      'Bearer new-access',
    ]);
    expect((await storage.readTokens())?.refreshToken, 'rotated-refresh');
  });

  test('concurrent 401 responses share one refresh request', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage.withTokens(
      const AuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
      ),
      deviceId: 'installation-id',
    );
    final Dio refreshDio = Dio(
      BaseOptions(baseUrl: 'https://example.com/api/'),
    );
    final _CallbackHttpClientAdapter refreshAdapter =
        _CallbackHttpClientAdapter((RequestOptions request) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _jsonResponse(<String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'access_token': 'new-access',
              'refresh_token': 'rotated-refresh',
            },
          });
        });
    refreshDio.httpClientAdapter = refreshAdapter;
    final ApiClient client = ApiClient.create(
      tokenStorage: storage,
      baseUrl: 'https://example.com/api/',
      refreshDio: refreshDio,
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

    final List<ApiResponse<bool>> responses = await Future.wait(
      <Future<ApiResponse<bool>>>[
        client.get<bool>('conversations', decodeData: (json) => json! as bool),
        client.get<bool>('grammar/stats', decodeData: (json) => json! as bool),
      ],
    );

    expect(responses.map((response) => response.data), everyElement(isTrue));
    expect(refreshAdapter.requestCount, 1);
  });

  test('failed refresh clears tokens and expires the session', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage.withTokens(
      const AuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'invalid-refresh',
      ),
      deviceId: 'installation-id',
    );
    final Dio refreshDio = Dio(
      BaseOptions(baseUrl: 'https://example.com/api/'),
    );
    final _CallbackHttpClientAdapter refreshAdapter =
        _CallbackHttpClientAdapter((RequestOptions request) {
          return _jsonResponse(<String, dynamic>{
            'detail': 'Invalid refresh token',
          }, statusCode: 401);
        });
    refreshDio.httpClientAdapter = refreshAdapter;
    int expirationCount = 0;
    final AuthSessionCoordinator sessionCoordinator = AuthSessionCoordinator()
      ..addExpirationListener(() => expirationCount += 1);
    final ApiClient client = ApiClient.create(
      tokenStorage: storage,
      baseUrl: 'https://example.com/api/',
      refreshDio: refreshDio,
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

    expect(await storage.readTokens(), isNull);
    expect(storage.clearCount, 1);
    expect(expirationCount, 1);
    expect(refreshAdapter.requestCount, 1);
  });

  test('temporary refresh failure preserves the local session', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage.withTokens(
      const AuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
      ),
      deviceId: 'installation-id',
    );
    final Dio refreshDio = Dio(
      BaseOptions(baseUrl: 'https://example.com/api/'),
    );
    refreshDio.httpClientAdapter = _CallbackHttpClientAdapter((
      RequestOptions request,
    ) {
      throw DioException.connectionError(
        requestOptions: request,
        reason: 'offline',
      );
    });
    int expirationCount = 0;
    final AuthSessionCoordinator sessionCoordinator = AuthSessionCoordinator()
      ..addExpirationListener(() => expirationCount += 1);
    final ApiClient client = ApiClient.create(
      tokenStorage: storage,
      baseUrl: 'https://example.com/api/',
      refreshDio: refreshDio,
      sessionCoordinator: sessionCoordinator,
    );
    client.dio.httpClientAdapter = _FakeHttpClientAdapter(
      statusCode: 401,
      response: <String, dynamic>{'detail': 'Expired token'},
    );
    addTearDown(client.close);

    await expectLater(
      client.get<void>('auth/me', decodeData: (_) {}),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.kind,
          'kind',
          ApiErrorKind.network,
        ),
      ),
    );

    expect(await storage.readTokens(), isNotNull);
    expect(storage.clearCount, 0);
    expect(expirationCount, 0);
  });

  test('stale refresh cannot restore tokens after logout', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage.withTokens(
      const AuthTokens(
        accessToken: 'expired-access',
        refreshToken: 'refresh-token',
      ),
      deviceId: 'installation-id',
    );
    final AuthSessionCoordinator sessionCoordinator = AuthSessionCoordinator();
    final Completer<void> refreshStarted = Completer<void>();
    final Completer<void> finishRefresh = Completer<void>();
    final Dio refreshDio = Dio(
      BaseOptions(baseUrl: 'https://example.com/api/'),
    );
    refreshDio.httpClientAdapter = _CallbackHttpClientAdapter((
      RequestOptions request,
    ) async {
      refreshStarted.complete();
      await finishRefresh.future;
      return _jsonResponse(<String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'access_token': 'stale-access',
          'refresh_token': 'stale-refresh',
        },
      });
    });
    final ApiClient client = ApiClient.create(
      tokenStorage: storage,
      baseUrl: 'https://example.com/api/',
      refreshDio: refreshDio,
      sessionCoordinator: sessionCoordinator,
    );
    client.dio.httpClientAdapter = _FakeHttpClientAdapter(
      statusCode: 401,
      response: <String, dynamic>{'detail': 'Expired token'},
    );
    addTearDown(client.close);

    final Future<ApiResponse<void>> request = client.get<void>(
      'auth/me',
      decodeData: (_) {},
    );
    await refreshStarted.future;
    sessionCoordinator.deactivateSession();
    await storage.clearTokens();
    finishRefresh.complete();

    await expectLater(request, throwsA(isA<ApiException>()));
    expect(await storage.readTokens(), isNull);
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
  int requestCount = 0;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount += 1;
    lastRequest = options;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({
    this.response = const <String, dynamic>{},
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
    return ResponseBody.fromString(
      jsonEncode(response),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage(String? accessToken)
    : tokens = accessToken == null
          ? null
          : AuthTokens(accessToken: accessToken, refreshToken: 'refresh-token');

  _MemoryTokenStorage.withTokens(this.tokens, {this.deviceId});

  AuthTokens? tokens;
  String? deviceId;
  int clearCount = 0;

  @override
  Future<void> clearTokens() async {
    clearCount += 1;
    tokens = null;
  }

  @override
  Future<String?> readAccessToken() async => tokens?.accessToken;

  @override
  Future<String?> readDeviceId() async => deviceId;

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<void> writeDeviceId(String deviceId) async {
    this.deviceId = deviceId;
  }

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}
