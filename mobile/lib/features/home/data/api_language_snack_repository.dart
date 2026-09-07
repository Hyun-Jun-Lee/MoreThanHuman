import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/domain/language_snack_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiLanguageSnackRepository implements LanguageSnackRepository {
  const ApiLanguageSnackRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<List<LanguageSnack>> listPublished() async {
    final ApiResponse<List<LanguageSnack>> response = await apiClient
        .get<List<LanguageSnack>>(
          'language-snacks/',
          decodeData: (Object? json) {
            if (json is! List) {
              throw const FormatException('Language snack list is invalid.');
            }
            return json
                .cast<Object?>()
                .map(LanguageSnack.fromJson)
                .toList(growable: false);
          },
        );
    return response.data;
  }
}

final Provider<LanguageSnackRepository> languageSnackRepositoryProvider =
    Provider<LanguageSnackRepository>((Ref ref) {
      return ApiLanguageSnackRepository(ref.watch(apiClientProvider));
    });
