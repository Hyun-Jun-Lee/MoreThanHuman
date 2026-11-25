import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/onboarding/data/onboarding_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingController extends AsyncNotifier<bool> {
  late OnboardingStorage _storage;

  @override
  Future<bool> build() async {
    _storage = ref.watch(onboardingStorageProvider);
    return _storage.isCompleted();
  }

  Future<bool> recordChoice(
    LearningLanguageContext languageContext,
    String appLocale,
    AIConsentStatus notice, {
    required bool acceptAI,
  }) async {
    await Future.wait(<Future<void>>[
      _storage.writePendingLanguageContext(languageContext),
      _storage.writePendingAppLocale(appLocale),
    ]);
    if (ref.read(authControllerProvider).value?.isAuthenticated != true) {
      await ref.read(authControllerProvider.notifier).continueAsGuest();
    } else {
      await ref.read(authControllerProvider.notifier).restoreSession();
    }
    final session = ref.read(authControllerProvider).requireValue;
    if (!session.isAuthenticated) {
      throw StateError('Guest initialization failed.');
    }
    final userId = session.user!.id;
    final result = await ref
        .read(aiConsentControllerProvider.notifier)
        .recordChoice(notice, acceptAI: acceptAI);
    if (ref.read(authControllerProvider).value?.user?.id != userId) {
      throw StateError('The account changed before consent was saved.');
    }
    ref.read(handledAINoticeProvider.notifier).mark(userId);
    return result.accepted;
  }

  Future<void> complete() async {
    await _storage.markCompleted();
    state = const AsyncData<bool>(true);
  }
}

final AsyncNotifierProvider<OnboardingController, bool>
onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);

class OnboardingAppLocaleController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final OnboardingStorage storage = ref.watch(onboardingStorageProvider);
    return storage.readPendingAppLocale();
  }

  void select(String appLocale) {
    if (appLocale != 'ko' && appLocale != 'en') {
      throw ArgumentError.value(appLocale, 'appLocale', 'Must be ko or en.');
    }
    if (state.value == appLocale) {
      return;
    }
    state = AsyncData<String?>(appLocale);
  }
}

final AsyncNotifierProvider<OnboardingAppLocaleController, String?>
onboardingAppLocaleControllerProvider =
    AsyncNotifierProvider<OnboardingAppLocaleController, String?>(
      OnboardingAppLocaleController.new,
    );
