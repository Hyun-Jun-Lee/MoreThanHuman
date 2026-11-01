import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiAuthRepository
    implements
        AuthRepository,
        AppLocaleRepository,
        NicknameRepository,
        AccountDeletionRepository {
  const ApiAuthRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<UserProfile> bootstrap(
    LearningLanguageContext? pendingLanguage,
  ) async {
    final ApiResponse<UserProfile> response = await apiClient
        .request<UserProfile>(
          'auth/bootstrap',
          method: 'POST',
          data: <String, dynamic>{
            if (pendingLanguage != null) 'language': pendingLanguage.toJson(),
          },
          decodeData: UserProfile.fromJson,
        );
    return response.data;
  }

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

  @override
  Future<UserProfile> updateNickname(String nickname) async {
    final ApiResponse<UserProfile> response = await apiClient
        .request<UserProfile>(
          'auth/me/nickname',
          method: 'PUT',
          data: <String, String>{'nickname': nickname},
          decodeData: UserProfile.fromJson,
        );
    return response.data;
  }

  @override
  Future<AccountDeletionResult> deleteAccount({
    String? appleIdentityToken,
    String? appleAuthorizationCode,
  }) async {
    final data = <String, dynamic>{};
    if (appleIdentityToken != null) {
      data['apple_identity_token'] = appleIdentityToken;
    }
    if (appleAuthorizationCode != null) {
      data['apple_authorization_code'] = appleAuthorizationCode;
    }
    final response = await apiClient.request<AccountDeletionResult>(
      'auth/me',
      method: 'DELETE',
      data: data,
      decodeData: AccountDeletionResult.fromJson,
    );
    return response.data;
  }

  @override
  Future<String> deletionStatus(String receipt) async {
    final response = await apiClient.get<String>(
      'auth/deletion-status/${Uri.encodeComponent(receipt)}',
      requiresAuth: false,
      decodeData: (value) {
        if (value is! Map<String, dynamic> ||
            !AccountDeletionResult.validStatus(value['status'])) {
          throw const FormatException('Invalid account deletion status.');
        }
        return value['status'] as String;
      },
    );
    return response.data;
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return ApiAuthRepository(ref.watch(apiClientProvider));
    });
