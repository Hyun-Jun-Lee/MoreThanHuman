import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';

abstract interface class AuthRepository {
  Future<UserProfile> bootstrap(
    LearningLanguageContext? pendingLanguage,
    String? pendingAppLocale,
  );
  Future<UserProfile> getCurrentUser();
}

abstract interface class NicknameRepository {
  Future<UserProfile> updateNickname(String nickname);
}

class AIConsentStatus {
  const AIConsentStatus({
    required this.accepted,
    required this.requiredVersions,
    required this.acceptedVersions,
    required this.missing,
    required this.privacyPolicyUrl,
    required this.privacyPolicyUrlEn,
    this.noticeAcknowledged = false,
  });

  factory AIConsentStatus.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['accepted'] is! bool ||
        value['privacy_policy_url'] is! String ||
        (value['privacy_policy_url_en'] != null &&
            value['privacy_policy_url_en'] is! String)) {
      throw const FormatException('Invalid AI consent status.');
    }
    Map<String, String> strings(Object? raw) => raw is Map
        ? raw.map((key, item) => MapEntry(key.toString(), item.toString()))
        : const <String, String>{};
    return AIConsentStatus(
      accepted: value['accepted'] as bool,
      requiredVersions: strings(value['required_versions']),
      acceptedVersions: strings(value['accepted_versions']),
      missing: (value['missing'] as List? ?? const <Object>[])
          .map((item) => item.toString())
          .toList(growable: false),
      privacyPolicyUrl: value['privacy_policy_url'] as String,
      privacyPolicyUrlEn:
          value['privacy_policy_url_en'] as String? ??
          value['privacy_policy_url'] as String,
      noticeAcknowledged: value['notice_acknowledged'] == true,
    );
  }

  final bool accepted;
  final Map<String, String> requiredVersions;
  final Map<String, String> acceptedVersions;
  final List<String> missing;
  final String privacyPolicyUrl;
  final String privacyPolicyUrlEn;
  final bool noticeAcknowledged;

  String privacyPolicyUrlFor({required bool isKorean}) =>
      isKorean ? privacyPolicyUrl : privacyPolicyUrlEn;
}

abstract interface class AIConsentRepository {
  Future<AIConsentStatus> getAINotice();
  Future<AIConsentStatus> getAIConsentStatus();
  Future<AIConsentStatus> recordAIConsentChoice(
    AIConsentStatus notice, {
    required bool acceptAI,
  });
}

class GuestTransferReceipt {
  const GuestTransferReceipt({required this.receipt, required this.expiresAt});

  final String receipt;
  final DateTime expiresAt;
}

class GuestTransferClaimResult {
  const GuestTransferClaimResult({
    required this.profile,
    required this.guestUserId,
  });

  final UserProfile profile;
  final String guestUserId;
}

abstract interface class GuestTransferRepository {
  Future<GuestTransferReceipt> issueGuestTransferReceipt();
  Future<GuestTransferClaimResult> claimGuestTransferReceipt(String receipt);
}

class AccountDeletionResult {
  const AccountDeletionResult({
    required this.status,
    required this.receipt,
    required this.appleDisconnectRequired,
    this.localCleanupFailed = false,
  });

  final String status;
  final String receipt;
  final bool appleDisconnectRequired;
  final bool localCleanupFailed;

  static bool validStatus(Object? value) =>
      value == 'completed' || value == 'processing';

  factory AccountDeletionResult.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        !validStatus(value['status']) ||
        value['receipt'] is! String ||
        value['apple_disconnect_required'] is! bool) {
      throw const FormatException('Invalid account deletion response.');
    }
    return AccountDeletionResult(
      status: value['status'] as String,
      receipt: value['receipt'] as String,
      appleDisconnectRequired: value['apple_disconnect_required'] as bool,
    );
  }
}

abstract interface class AccountDeletionRepository {
  Future<AccountDeletionResult> deleteAccount({
    String? appleIdentityToken,
    String? appleAuthorizationCode,
  });
  Future<String> deletionStatus(String receipt);
}
