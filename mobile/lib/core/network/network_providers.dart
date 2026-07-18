import 'package:curitalk/core/network/api_client.dart';
import 'package:curitalk/core/network/auth_session_coordinator.dart';
import 'package:curitalk/features/auth/data/supabase_auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<AuthSessionCoordinator> authSessionCoordinatorProvider =
    Provider<AuthSessionCoordinator>((Ref ref) {
      return AuthSessionCoordinator();
    });

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  final ApiClient client = ApiClient.create(
    tokenProvider: ref.watch(accessTokenProvider),
    sessionRefreshProvider: ref.watch(sessionRefreshProvider),
    sessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
  ref.onDispose(client.close);
  return client;
});
