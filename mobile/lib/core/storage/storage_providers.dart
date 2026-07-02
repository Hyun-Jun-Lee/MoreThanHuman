import 'package:curitalk/core/storage/installation_id_service.dart';
import 'package:curitalk/core/storage/token_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<SecureStorageBackend> secureStorageBackendProvider =
    Provider<SecureStorageBackend>((Ref ref) {
      return const FlutterSecureStorageBackend();
    });

final Provider<TokenStorage> tokenStorageProvider = Provider<TokenStorage>((
  Ref ref,
) {
  return SecureTokenStorage(ref.watch(secureStorageBackendProvider));
});

final Provider<InstallationIdService> installationIdServiceProvider =
    Provider<InstallationIdService>((Ref ref) {
      return InstallationIdService(ref.watch(tokenStorageProvider));
    });
