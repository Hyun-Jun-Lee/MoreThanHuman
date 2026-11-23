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

  Future<void> complete(LearningLanguageContext languageContext) async {
    await _storage.writePendingLanguageContext(languageContext);
    await _storage.markCompleted();
    state = const AsyncData<bool>(true);
    await ref.read(authControllerProvider.notifier).continueAsGuest();
  }
}

final AsyncNotifierProvider<OnboardingController, bool>
onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);
