import 'package:curitalk/features/auth/data/supabase_auth_service.dart';
import 'package:dio/dio.dart';

class AuthTokenInterceptor extends Interceptor {
  AuthTokenInterceptor(this.tokenProvider);

  static const String requiresAuthKey = 'requiresAuth';

  final AccessTokenProvider tokenProvider;

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

    final String? accessToken = await tokenProvider.readAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }
}
