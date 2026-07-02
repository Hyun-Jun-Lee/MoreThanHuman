import 'package:curitalk/core/network/api_exception.dart';
import 'package:curitalk/core/network/api_response.dart';
import 'package:curitalk/core/network/auth_session_coordinator.dart';
import 'package:curitalk/core/network/auth_token_interceptor.dart';
import 'package:curitalk/core/storage/auth_tokens.dart';
import 'package:curitalk/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

class TokenRefreshInterceptor extends Interceptor {
  TokenRefreshInterceptor({
    required this.requestDio,
    required this.refreshDio,
    required this.tokenStorage,
    required this.sessionCoordinator,
  });

  static const String retryAttemptedKey = 'tokenRefreshRetryAttempted';
  static const String sessionRevisionKey = 'authSessionRevision';

  final Dio requestDio;
  final Dio refreshDio;
  final TokenStorage tokenStorage;
  final AuthSessionCoordinator sessionCoordinator;

  Future<AuthTokens?>? _refreshOperation;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions request = err.requestOptions;
    final bool requiresAuth =
        request.extra[AuthTokenInterceptor.requiresAuthKey] != false;
    final bool isUnauthorized = err.response?.statusCode == 401;
    if (!requiresAuth || !isUnauthorized) {
      handler.next(err);
      return;
    }

    if (request.extra[retryAttemptedKey] == true) {
      final Object? revision = request.extra[sessionRevisionKey];
      if (revision is int && sessionCoordinator.isCurrent(revision)) {
        await _expireSession();
      }
      handler.next(err);
      return;
    }

    AuthTokens? storedTokens;
    try {
      storedTokens = await tokenStorage.readTokens();
    } on Object {
      await _expireSession();
      handler.next(err);
      return;
    }
    if (!sessionCoordinator.refreshAllowed) {
      handler.next(err);
      return;
    }
    AuthTokens? tokens;
    try {
      tokens =
          storedTokens != null &&
              !_requestUsedToken(request, storedTokens.accessToken)
          ? storedTokens
          : await _refreshTokens();
    } on DioException catch (refreshError) {
      handler.next(refreshError);
      return;
    } on ApiException catch (refreshError) {
      handler.next(
        DioException(
          requestOptions: request,
          type: DioExceptionType.unknown,
          error: refreshError,
          message: refreshError.message,
        ),
      );
      return;
    } on Object catch (refreshError) {
      handler.next(
        DioException(
          requestOptions: request,
          type: DioExceptionType.unknown,
          error: refreshError,
          message: 'The authentication session could not be refreshed.',
        ),
      );
      return;
    }
    if (tokens == null) {
      handler.next(err);
      return;
    }

    request.extra[retryAttemptedKey] = true;
    request.extra[sessionRevisionKey] = sessionCoordinator.captureRevision();
    request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';

    try {
      handler.resolve(await requestDio.fetch<Object?>(request));
    } on DioException catch (retryError) {
      if (retryError.response?.statusCode == 401) {
        final Object? revision = request.extra[sessionRevisionKey];
        if (revision is int && sessionCoordinator.isCurrent(revision)) {
          await _expireSession();
        }
      }
      handler.next(retryError);
    }
  }

  Future<AuthTokens?> _refreshTokens() {
    if (!sessionCoordinator.refreshAllowed) {
      return Future<AuthTokens?>.value();
    }
    final Future<AuthTokens?>? activeOperation = _refreshOperation;
    if (activeOperation != null) {
      return activeOperation;
    }

    final Future<AuthTokens?> operation = _performRefresh();
    _refreshOperation = operation;
    return operation.whenComplete(() {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
    });
  }

  Future<AuthTokens?> _performRefresh() async {
    final int sessionRevision = sessionCoordinator.captureRevision();
    try {
      final AuthTokens? currentTokens = await tokenStorage.readTokens();
      final String? deviceId = await tokenStorage.readDeviceId();
      if (!sessionCoordinator.refreshAllowed ||
          !sessionCoordinator.isCurrent(sessionRevision)) {
        return null;
      }
      if (currentTokens == null || deviceId == null || deviceId.isEmpty) {
        await _expireSession();
        return null;
      }

      final Response<Object?> response = await refreshDio.post<Object?>(
        'auth/refresh',
        data: <String, String>{
          'refresh_token': currentTokens.refreshToken,
          'device_id': deviceId,
        },
      );
      final AuthTokens refreshedTokens = ApiResponse<AuthTokens>.fromJson(
        response.data,
        AuthTokens.fromJson,
      ).data;
      if (!sessionCoordinator.refreshAllowed ||
          !sessionCoordinator.isCurrent(sessionRevision)) {
        return null;
      }
      await tokenStorage.writeTokens(refreshedTokens);
      return refreshedTokens;
    } on DioException catch (error) {
      final int? statusCode = error.response?.statusCode;
      if (statusCode == 400 ||
          statusCode == 401 ||
          statusCode == 403 ||
          statusCode == 422) {
        if (sessionCoordinator.refreshAllowed &&
            sessionCoordinator.isCurrent(sessionRevision)) {
          await _expireSession();
        }
        return null;
      }
      rethrow;
    }
  }

  Future<void> _expireSession() async {
    sessionCoordinator.expireSession();
    try {
      await tokenStorage.clearTokens();
    } on Object {
      return;
    }
  }

  bool _requestUsedToken(RequestOptions request, String accessToken) {
    final Object? authorization = request.headers['Authorization'];
    return authorization is String &&
        authorization.split(' ').last == accessToken;
  }
}
