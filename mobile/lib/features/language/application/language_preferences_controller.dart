import 'package:curitalk/features/language/data/api_language_preferences_repository.dart';
import 'package:curitalk/features/language/domain/language_preferences_repository.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LanguagePreferencesController
    extends AsyncNotifier<LearningLanguageContext> {
  late LanguagePreferencesRepository _repository;

  @override
  Future<LearningLanguageContext> build() async {
    _repository = ref.watch(languagePreferencesRepositoryProvider);
    return _repository.getLanguagePreferences();
  }

  Future<void> saveLanguagePreferences(LearningLanguageContext context) async {
    state = const AsyncLoading<LearningLanguageContext>();
    state = await AsyncValue.guard(() {
      return _repository.updateLanguagePreferences(context);
    });
  }
}

final AsyncNotifierProvider<
  LanguagePreferencesController,
  LearningLanguageContext
>
languagePreferencesControllerProvider =
    AsyncNotifierProvider<
      LanguagePreferencesController,
      LearningLanguageContext
    >(LanguagePreferencesController.new);
