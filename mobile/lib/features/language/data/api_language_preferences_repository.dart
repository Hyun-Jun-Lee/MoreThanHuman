import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/language/domain/language_preferences_repository.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiLanguagePreferencesRepository
    implements LanguagePreferencesRepository {
  const ApiLanguagePreferencesRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<LearningLanguageContext> getLanguagePreferences() async {
    final ApiResponse<LearningLanguageContext> response = await apiClient
        .get<LearningLanguageContext>(
          'auth/me/language-preferences',
          decodeData: LearningLanguageContext.fromJson,
        );
    return response.data;
  }

  @override
  Future<LearningLanguageContext> updateLanguagePreferences(
    LearningLanguageContext context,
  ) async {
    final ApiResponse<LearningLanguageContext> response = await apiClient
        .request<LearningLanguageContext>(
          'auth/me/language-preferences',
          method: 'PUT',
          data: context.toJson(),
          decodeData: LearningLanguageContext.fromJson,
        );
    return response.data;
  }
}

final Provider<LanguagePreferencesRepository>
languagePreferencesRepositoryProvider = Provider<LanguagePreferencesRepository>(
  (Ref ref) {
    return ApiLanguagePreferencesRepository(ref.watch(apiClientProvider));
  },
);
