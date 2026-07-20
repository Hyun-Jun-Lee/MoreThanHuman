import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class OnboardingStorage {
  Future<bool> isCompleted();

  Future<LearningLanguageContext?> readPendingLanguageContext();

  Future<void> writePendingLanguageContext(LearningLanguageContext context);

  Future<void> clearPendingLanguageContext();

  Future<void> markCompleted();
}

class SecureOnboardingStorage implements OnboardingStorage {
  const SecureOnboardingStorage(this.backend);

  static const String _completedKey = 'curitalk.onboarding_completed';
  static const String _pendingLanguageKey =
      'curitalk.onboarding_pending_language_context';

  final SecureStorageBackend backend;

  @override
  Future<bool> isCompleted() async {
    return await backend.read(_completedKey) == 'true';
  }

  @override
  Future<LearningLanguageContext?> readPendingLanguageContext() async {
    final String? value = await backend.read(_pendingLanguageKey);
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    try {
      return LearningLanguageContext.fromStorageValue(value);
    } on FormatException {
      await clearPendingLanguageContext();
      return null;
    }
  }

  @override
  Future<void> writePendingLanguageContext(LearningLanguageContext context) {
    return backend.write(_pendingLanguageKey, context.toStorageValue());
  }

  @override
  Future<void> clearPendingLanguageContext() {
    return backend.delete(_pendingLanguageKey);
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
