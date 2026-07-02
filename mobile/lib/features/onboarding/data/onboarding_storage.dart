import 'package:curitalk/core/storage/storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class OnboardingStorage {
  Future<bool> isCompleted();

  Future<void> markCompleted();
}

class SecureOnboardingStorage implements OnboardingStorage {
  const SecureOnboardingStorage(this.backend);

  static const String _completedKey = 'curitalk.onboarding_completed';

  final SecureStorageBackend backend;

  @override
  Future<bool> isCompleted() async {
    return await backend.read(_completedKey) == 'true';
  }

  @override
  Future<void> markCompleted() {
    return backend.write(_completedKey, 'true');
  }
}

final Provider<OnboardingStorage> onboardingStorageProvider =
    Provider<OnboardingStorage>((Ref ref) {
      return SecureOnboardingStorage(ref.watch(secureStorageBackendProvider));
    });
