import 'package:curitalk/core/network/auth_session_coordinator.dart';
import 'package:curitalk/core/network/auth_token_interceptor.dart';
import 'package:curitalk/features/auth/data/supabase_auth_service.dart';
import 'package:dio/dio.dart';

class TokenRefreshInterceptor extends Interceptor {
  TokenRefreshInterceptor({
    required this.requestDio,
    required this.sessionRefreshProvider,
    required this.sessionCoordinator,
  });

  static const String retryAttemptedKey = 'tokenRefreshRetryAttempted';
  static const String sessionRevisionKey = 'authSessionRevision';

  final Dio requestDio;
  final SessionRefreshProvider sessionRefreshProvider;
  final AuthSessionCoordinator sessionCoordinator;

  Future<String?>? _refreshOperation;

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

    final String? previousAccessToken = _authorizationToken(request);
    String? accessToken;
    try {
      accessToken = await _refreshAccessToken(previousAccessToken);
    } on DioException catch (refreshError) {
      handler.next(refreshError);
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
    if (accessToken == null || accessToken.isEmpty) {
      await _expireSession();
      handler.next(err);
      return;
    }

    request.extra[retryAttemptedKey] = true;
    request.extra[sessionRevisionKey] = sessionCoordinator.captureRevision();
    request.headers['Authorization'] = 'Bearer $accessToken';

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

  Future<String?> _refreshAccessToken(String? previousAccessToken) {
    if (!sessionCoordinator.refreshAllowed) {
      return Future<String?>.value();
    }
    final Future<String?>? activeOperation = _refreshOperation;
    if (activeOperation != null) {
      return activeOperation;
    }

    final Future<String?> operation = sessionRefreshProvider.refreshAccessToken(
      previousAccessToken: previousAccessToken,
    );
    _refreshOperation = operation;
    return operation.whenComplete(() {
      if (identical(_refreshOperation, operation)) {
        _refreshOperation = null;
      }
    });
  }

  Future<void> _expireSession() async {
    sessionCoordinator.expireSession();
    try {
      await sessionRefreshProvider.expireSession();
    } on Object {
      return;
    }
  }

  String? _authorizationToken(RequestOptions request) {
    final Object? authorization = request.headers['Authorization'];
    if (authorization is! String || authorization.isEmpty) {
      return null;
    }
    final List<String> parts = authorization.split(' ');
    return parts.isEmpty ? null : parts.last;
  }
}
