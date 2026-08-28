import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiAuthRepository implements AuthRepository, AppLocaleRepository {
  const ApiAuthRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<UserProfile> getCurrentUser() async {
    final ApiResponse<UserProfile> response = await apiClient.get<UserProfile>(
      'auth/me',
      decodeData: UserProfile.fromJson,
    );
    return response.data;
  }

  @override
  Future<UserProfile> updateAppLocale(String appLocale) async {
    final ApiResponse<UserProfile> response = await apiClient
        .request<UserProfile>(
          'auth/me/app-locale',
          method: 'PUT',
          data: <String, String>{'app_locale': appLocale},
          decodeData: UserProfile.fromJson,
        );
    return response.data;
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return ApiAuthRepository(ref.watch(apiClientProvider));
    });
