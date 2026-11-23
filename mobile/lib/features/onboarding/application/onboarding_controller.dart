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

  Future<void> complete(
    LearningLanguageContext languageContext,
    String appLocale,
  ) async {
    await Future.wait(<Future<void>>[
      _storage.writePendingLanguageContext(languageContext),
      _storage.writePendingAppLocale(appLocale),
    ]);
    await _storage.markCompleted();
    state = const AsyncData<bool>(true);
    await ref.read(authControllerProvider.notifier).continueAsGuest();
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
