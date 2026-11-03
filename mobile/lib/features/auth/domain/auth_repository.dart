import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';

abstract interface class AuthRepository {
  Future<UserProfile> bootstrap(LearningLanguageContext? pendingLanguage);
  Future<UserProfile> getCurrentUser();
}

abstract interface class AppLocaleRepository {
  Future<UserProfile> updateAppLocale(String appLocale);
}

abstract interface class NicknameRepository {
  Future<UserProfile> updateNickname(String nickname);
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
