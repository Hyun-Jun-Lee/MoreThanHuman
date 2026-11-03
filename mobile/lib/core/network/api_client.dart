import 'package:curitalk/core/config/app_config.dart';
import 'package:curitalk/core/diagnostics/latency_trace.dart';
import 'package:curitalk/core/network/api_exception.dart';
import 'package:curitalk/core/network/api_response.dart';
import 'package:curitalk/core/network/auth_session_coordinator.dart';
import 'package:curitalk/core/network/auth_token_interceptor.dart';
import 'package:curitalk/core/network/token_refresh_interceptor.dart';
import 'package:curitalk/features/auth/data/supabase_auth_service.dart';
import 'package:curitalk/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

class ApiClient {
  ApiClient(this.dio, [this._refreshDio]);

  factory ApiClient.create({
    AccessTokenProvider? tokenProvider,
    SessionRefreshProvider? sessionRefreshProvider,
    TokenStorage? tokenStorage,
    String baseUrl = AppConfig.apiBaseUrl,
    AuthSessionCoordinator? sessionCoordinator,
  }) {
    final AccessTokenProvider effectiveTokenProvider =
        tokenProvider ?? _TokenStorageSessionProvider.required(tokenStorage);
    final SessionRefreshProvider effectiveRefreshProvider =
        sessionRefreshProvider ??
        _TokenStorageSessionProvider.required(tokenStorage);
    final String normalizedBaseUrl = _normalizeBaseUrl(baseUrl);
    final Dio dio = Dio(_baseOptions(normalizedBaseUrl));
    final AuthSessionCoordinator authSessionCoordinator =
        sessionCoordinator ?? AuthSessionCoordinator();
    dio.interceptors.add(AuthTokenInterceptor(effectiveTokenProvider));
    dio.interceptors.add(
      TokenRefreshInterceptor(
        requestDio: dio,
        sessionRefreshProvider: effectiveRefreshProvider,
        sessionCoordinator: authSessionCoordinator,
      ),
    );
    return ApiClient(dio);
  }

  final Dio dio;
  final Dio? _refreshDio;

  Future<ApiResponse<T>> get<T>(
    String path, {
    required ApiDataDecoder<T> decodeData,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    String? diagnosticSource,
  }) {
    return request<T>(
      path,
      method: 'GET',
      decodeData: decodeData,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      diagnosticSource: diagnosticSource,
    );
  }

  Future<ApiResponse<T>> post<T>(
    String path, {
    required ApiDataDecoder<T> decodeData,
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? contentType,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    LatencyTrace? latencyTrace,
  }) {
    return request<T>(
      path,
      method: 'POST',
      decodeData: decodeData,
      data: data,
      queryParameters: queryParameters,
      contentType: contentType,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
      latencyTrace: latencyTrace,
    );
  }

  Future<ApiResponse<T>> request<T>(
    String path, {
    required String method,
    required ApiDataDecoder<T> decodeData,
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? contentType,
    bool requiresAuth = true,
    CancelToken? cancelToken,
    LatencyTrace? latencyTrace,
    String? diagnosticSource,
  }) async {
    final bool isConversationTurn =
        method == 'POST' &&
        RegExp(
          r'^conversations/(?:start/(?:free-chat|roleplay)|[^/]+/(?:turn|message))/?$',
        ).hasMatch(_normalizePath(path));
    final LatencyTrace? trace = isConversationTurn
        ? (latencyTrace ?? LatencyTrace()).claimRequest()
        : method == 'GET'
        ? LatencyTrace()
        : null;
    final int started = trace?.elapsedMicroseconds ?? 0;
    String latencyStatus = 'error';
    bool authRetried = false;
    int? httpStatus;
    final String operation = _diagnosticOperation(method, path);
    final String source = _diagnosticSource(diagnosticSource);
    try {
      final Response<Object?> response = await dio.request<Object?>(
        _normalizePath(path),
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          contentType: contentType,
          headers: trace == null
              ? null
              : <String, Object>{'X-Request-ID': trace.id},
          extra: <String, Object?>{
            AuthTokenInterceptor.requiresAuthKey: requiresAuth,
          },
        ),
      );
      authRetried =
          response.requestOptions.extra[TokenRefreshInterceptor
              .retryAttemptedKey] ==
          true;
      httpStatus = response.statusCode;
      trace?.mark(
        'http_response',
        startedAtMicroseconds: started,
        fields: <String, Object?>{
          'operation': operation,
          'request_source': source,
          'status_code': httpStatus,
        },
      );
      final ApiResponse<T> parsed = trace == null
          ? ApiResponse<T>.fromJson(response.data, decodeData)
          : trace.duringDecode(
              () => ApiResponse<T>.fromJson(response.data, decodeData),
            );
      latencyStatus = 'ok';
      return parsed;
    } on DioException catch (error) {
      authRetried =
          error.requestOptions.extra[TokenRefreshInterceptor
              .retryAttemptedKey] ==
          true;
      httpStatus = error.response?.statusCode;
      throw ApiException.fromDio(error);
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      throw ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'The server response could not be parsed.',
        cause: error,
      );
    } finally {
      trace?.mark(
        'http_total',
        status: latencyStatus,
        startedAtMicroseconds: started,
        fields: <String, Object?>{
          'operation': operation,
          'request_source': source,
          'status_code': httpStatus,
          'auth_retry': authRetried,
        },
      );
    }
  }

  void close({bool force = false}) {
    dio.close(force: force);
    if (!identical(dio, _refreshDio)) {
      _refreshDio?.close(force: force);
    }
  }

  static BaseOptions _baseOptions(String baseUrl) {
    return BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
  }

  static String _normalizeBaseUrl(String value) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'baseUrl', 'Must not be empty.');
    }
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  static String _normalizePath(String value) {
    return value.startsWith('/') ? value.substring(1) : value;
  }

  static String _diagnosticOperation(String method, String path) {
    if (method != 'GET') return 'conversation_turn';
    final parts = _normalizePath(path).split('/')
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) return 'other_get';
    if (parts.first == 'auth') return 'auth_profile';
    if (parts.first == 'grammar') return 'grammar_feedback';
    if (parts.first == 'conversation-topics') return 'weekly_topics';
    if (parts.first != 'conversations') return 'other_get';
    if (parts.length == 1) return 'conversation_list';
    if (parts.length == 2 && parts[1] == 'access') return 'access_summary';
    if (parts.length == 3 && parts[2] == 'access') return 'turn_access';
    if (parts.length == 3 && parts[2] == 'messages') return 'message_list';
    if (parts.length == 3 && parts[2] == 'turns') return 'turn_list';
    if (parts.length >= 2 && parts[1] == 'turns') return 'turn_status';
    return 'other_get';
  }

  static String _diagnosticSource(String? source) {
    const allowed = <String>{
      'home_recent',
      'history_list',
      'conversation_messages',
      'conversation_access',
      'conversation_turn_access',
      'turn_recovery',
    };
    return source != null && allowed.contains(source) ? source : 'unspecified';
  }
}

class _TokenStorageSessionProvider
    implements AccessTokenProvider, SessionRefreshProvider {
  _TokenStorageSessionProvider(this._tokenStorage);

  factory _TokenStorageSessionProvider.required(TokenStorage? tokenStorage) {
    if (tokenStorage == null) {
      throw ArgumentError(
        'ApiClient.create requires Supabase token providers or a test tokenStorage.',
      );
    }
    return _TokenStorageSessionProvider(tokenStorage);
  }

  final TokenStorage _tokenStorage;

  @override
  Future<String?> readAccessToken() => _tokenStorage.readAccessToken();

  @override
  Future<String?> refreshAccessToken({
    required String? previousAccessToken,
  }) async {
    final String? accessToken = await _tokenStorage.readAccessToken();
    return accessToken != previousAccessToken ? accessToken : null;
  }

  @override
  Future<void> expireSession() => _tokenStorage.clearTokens();
}
