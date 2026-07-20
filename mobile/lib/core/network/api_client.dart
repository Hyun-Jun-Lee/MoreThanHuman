import 'package:curitalk/core/config/app_config.dart';
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
  }) {
    return request<T>(
      path,
      method: 'GET',
      decodeData: decodeData,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      cancelToken: cancelToken,
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
  }) async {
    try {
      final Response<Object?> response = await dio.request<Object?>(
        _normalizePath(path),
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: Options(
          method: method,
          contentType: contentType,
          extra: <String, Object?>{
            AuthTokenInterceptor.requiresAuthKey: requiresAuth,
          },
        ),
      );
      return ApiResponse<T>.fromJson(response.data, decodeData);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on ApiException {
      rethrow;
    } on Object catch (error) {
      throw ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'The server response could not be parsed.',
        cause: error,
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
