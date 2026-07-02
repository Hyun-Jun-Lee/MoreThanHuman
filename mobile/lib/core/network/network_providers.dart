import 'package:curitalk/core/network/api_client.dart';
import 'package:curitalk/core/network/auth_session_coordinator.dart';
import 'package:curitalk/core/storage/storage_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<AuthSessionCoordinator> authSessionCoordinatorProvider =
    Provider<AuthSessionCoordinator>((Ref ref) {
      return AuthSessionCoordinator();
    });

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  final ApiClient client = ApiClient.create(
    tokenStorage: ref.watch(tokenStorageProvider),
    sessionCoordinator: ref.watch(authSessionCoordinatorProvider),
  );
  ref.onDispose(client.close);
  return client;
});
