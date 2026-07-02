import 'package:curitalk/core/storage/token_storage.dart';
import 'package:dio/dio.dart';

class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor(this.tokenStorage);

  static const String requiresAuthKey = 'requiresAuth';

  final TokenStorage tokenStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final bool requiresAuth = options.extra[requiresAuthKey] != false;
    final bool hasAuthorization = options.headers.keys.any(
      (String key) => key.toLowerCase() == 'authorization',
    );
    if (!requiresAuth || hasAuthorization) {
      handler.next(options);
      return;
    }

    final String? accessToken = await tokenStorage.readAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }
}
