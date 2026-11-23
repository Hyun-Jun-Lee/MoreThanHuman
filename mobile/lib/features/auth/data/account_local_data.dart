import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/language/domain/learning_language.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AccountLocalData {
  const AccountLocalData(this.backend);

  static const _receiptKey = 'curitalk.account_deletion.receipt';
  static const _guestCreationSuppressedKey =
      'curitalk.guest_creation_suppressed';
  static const _guestTransferReceiptKey = 'curitalk.guest_transfer.receipt';
  final SecureStorageBackend backend;

  Future<bool> clearLearningData(String userId) async {
    final keys = <String>{
      'curitalk.device_id',
      'curitalk.onboarding_pending_language_context',
      'curitalk.language_snacks',
      'curitalk.language_snacks.v2.en.ko',
      'curitalk.language_snacks.v2.ko.en',
      for (final language in const ['en', 'ko', 'zh'])
        'curitalk.snack_basket.v1.${Uri.encodeComponent(userId)}.$language',
      for (final pair in LearningLanguageContext.supportedContexts)
        'curitalk.weekly_topics.v1.$userId.'
            '${pair.nativeLanguage.code}-${pair.targetLanguage.code}',
    };
    var succeeded = true;
    for (final key in keys) {
      try {
        await backend.delete(key);
      } on Object {
        succeeded = false;
      }
    }
    return succeeded;
  }

  Future<bool> clearAccountScopedLearningData(String userId) async {
    final keys = <String>{
      for (final language in const ['en', 'ko', 'zh'])
        'curitalk.snack_basket.v1.${Uri.encodeComponent(userId)}.$language',
      for (final pair in LearningLanguageContext.supportedContexts)
        'curitalk.weekly_topics.v1.$userId.'
            '${pair.nativeLanguage.code}-${pair.targetLanguage.code}',
    };
    var succeeded = true;
    for (final key in keys) {
      try {
        await backend.delete(key);
      } on Object {
        succeeded = false;
      }
    }
    return succeeded;
  }

  Future<void> saveReceipt(String receipt) =>
      backend.write(_receiptKey, receipt);
  Future<String?> readReceipt() => backend.read(_receiptKey);
  Future<void> clearReceipt() => backend.delete(_receiptKey);
  Future<void> suppressGuestCreation() =>
      backend.write(_guestCreationSuppressedKey, 'true');
  Future<bool> isGuestCreationSuppressed() async =>
      await backend.read(_guestCreationSuppressedKey) == 'true';
  Future<void> allowGuestCreation() =>
      backend.delete(_guestCreationSuppressedKey);
  Future<void> saveGuestTransferReceipt(String receipt) =>
      backend.write(_guestTransferReceiptKey, receipt);
  Future<String?> readGuestTransferReceipt() =>
      backend.read(_guestTransferReceiptKey);
  Future<void> clearGuestTransferReceipt() =>
      backend.delete(_guestTransferReceiptKey);
}

final accountLocalDataProvider = Provider<AccountLocalData>(
  (ref) => AccountLocalData(ref.watch(secureStorageBackendProvider)),
);
