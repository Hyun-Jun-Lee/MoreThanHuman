import 'package:curitalk/features/language/domain/learning_language.dart';

abstract interface class LanguagePreferencesRepository {
  Future<LearningLanguageContext> getLanguagePreferences();

  Future<LearningLanguageContext> updateLanguagePreferences(
    LearningLanguageContext context,
  );
}
