import 'package:curitalk/features/auth/data/api_auth_repository.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AIConsentController extends AsyncNotifier<AIConsentStatus?> {
  @override
  Future<AIConsentStatus?> build() async => null;

  Future<AIConsentStatus> load() async {
    final repository = ref.read(authRepositoryProvider);
    if (repository is! AIConsentRepository) return _acceptedForTestDouble;
    final status = await (repository as AIConsentRepository)
        .getAIConsentStatus();
    if (ref.mounted) state = AsyncData(status);
    return status;
  }

  Future<AIConsentStatus> recordChoice(
    AIConsentStatus notice, {
    required bool acceptAI,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    if (repository is! AIConsentRepository) return _acceptedForTestDouble;
    final status = await (repository as AIConsentRepository)
        .recordAIConsentChoice(notice, acceptAI: acceptAI);
    if (ref.mounted) state = AsyncData(status);
    return status;
  }
}

const _acceptedForTestDouble = AIConsentStatus(
  accepted: true,
  noticeAcknowledged: true,
  requiredVersions: {},
  acceptedVersions: {},
  missing: [],
  privacyPolicyUrl: '',
  privacyPolicyUrlEn: '',
);

final aiConsentControllerProvider =
    AsyncNotifierProvider<AIConsentController, AIConsentStatus?>(
      AIConsentController.new,
    );

/// 온보딩에서 이미 선택한 안내를 같은 홈 진입에 다시 표시하지 않아요.
class HandledAINotice extends Notifier<String?> {
  @override
  String? build() => null;
  void mark(String userId) => state = userId;
}

final handledAINoticeProvider = NotifierProvider<HandledAINotice, String?>(
  HandledAINotice.new,
);
