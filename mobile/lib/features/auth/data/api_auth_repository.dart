import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ApiAuthRepository
    implements
        AuthRepository,
        NicknameRepository,
        AIConsentRepository,
        GuestTransferRepository,
        AccountDeletionRepository {
  const ApiAuthRepository(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<UserProfile> bootstrap(
    LearningLanguageContext? pendingLanguage,
    String? pendingAppLocale,
  ) async {
    final ApiResponse<UserProfile> response = await apiClient
        .request<UserProfile>(
          'auth/bootstrap',
          method: 'POST',
          data: <String, dynamic>{
            'language': ?pendingLanguage?.toJson(),
            'app_locale': ?pendingAppLocale,
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

  @override
  Future<AIConsentStatus> getAIConsentStatus() async {
    final response = await apiClient.get<AIConsentStatus>(
      'auth/me/ai-consent',
      decodeData: AIConsentStatus.fromJson,
    );
    return response.data;
  }

  @override
  Future<AIConsentStatus> getAINotice() async {
    final response = await apiClient.get<AIConsentStatus>(
      'auth/ai-notice',
      requiresAuth: false,
      decodeData: AIConsentStatus.fromJson,
    );
    return response.data;
  }

  @override
  Future<AIConsentStatus> recordAIConsentChoice(
    AIConsentStatus notice, {
    required bool acceptAI,
  }) async {
    final response = await apiClient.request<AIConsentStatus>(
      'auth/me/ai-consent',
      method: 'POST',
      data: {
        'privacy_policy_version': notice.requiredVersions['privacy_policy'],
        'ai_data_processing_version':
            notice.requiredVersions['ai_data_processing'],
        'accept_ai': acceptAI,
      },
      decodeData: AIConsentStatus.fromJson,
    );
    return response.data;
  }

  @override
  Future<GuestTransferReceipt> issueGuestTransferReceipt() async {
    final response = await apiClient.request<GuestTransferReceipt>(
      'auth/guest-transfer/receipt',
      method: 'POST',
      decodeData: (value) {
        if (value is! Map<String, dynamic> ||
            value['receipt'] is! String ||
            value['expires_at'] is! String) {
          throw const FormatException('Invalid guest transfer receipt.');
        }
        return GuestTransferReceipt(
          receipt: value['receipt'] as String,
          expiresAt: DateTime.parse(value['expires_at'] as String),
        );
      },
    );
    return response.data;
  }

  @override
  Future<GuestTransferClaimResult> claimGuestTransferReceipt(
    String receipt,
  ) async {
    final response = await apiClient.request<GuestTransferClaimResult>(
      'auth/guest-transfer/claim',
      method: 'POST',
      data: <String, String>{'receipt': receipt},
      decodeData: (value) {
        if (value is! Map<String, dynamic> ||
            value['guest_user_id'] is! String) {
          throw const FormatException('Invalid guest transfer claim.');
        }
        return GuestTransferClaimResult(
          profile: UserProfile.fromJson(value['profile']),
          guestUserId: value['guest_user_id'] as String,
        );
      },
    );
    return response.data;
  }
}

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
      return ApiAuthRepository(ref.watch(apiClientProvider));
    });
