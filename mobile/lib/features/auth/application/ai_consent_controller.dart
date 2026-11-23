import 'package:curitalk/features/auth/data/api_auth_repository.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AIConsentController extends AsyncNotifier<AIConsentStatus?> {
  @override
  Future<AIConsentStatus?> build() async => null;

  Future<AIConsentStatus> load() async {
    final repository = ref.read(authRepositoryProvider);
    if (repository is! AIConsentRepository) return _acceptedForTestDouble;
    final consentRepository = repository as AIConsentRepository;
    state = const AsyncLoading<AIConsentStatus?>();
    final status = await consentRepository.getAIConsentStatus();
    state = AsyncData<AIConsentStatus?>(status);
    return status;
  }

  Future<AIConsentStatus> accept() async {
    final repository = ref.read(authRepositoryProvider);
    if (repository is! AIConsentRepository) return _acceptedForTestDouble;
    final consentRepository = repository as AIConsentRepository;
    state = const AsyncLoading<AIConsentStatus?>();
    final status = await consentRepository.acceptAIConsent();
    state = AsyncData<AIConsentStatus?>(status);
    return status;
  }
}

const AIConsentStatus _acceptedForTestDouble = AIConsentStatus(
  accepted: true,
  requiredVersions: <String, String>{},
  acceptedVersions: <String, String>{},
  missing: <String>[],
  privacyPolicyUrl: '',
  privacyPolicyUrlEn: '',
);

final aiConsentControllerProvider =
    AsyncNotifierProvider<AIConsentController, AIConsentStatus?>(
      AIConsentController.new,
    );
