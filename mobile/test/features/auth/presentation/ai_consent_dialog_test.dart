import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI consent selects the privacy URL for the app language', () {
    final status = AIConsentStatus.fromJson(const <String, Object>{
      'accepted': false,
      'privacy_policy_url': 'https://www.curitalk.app/privacy',
      'privacy_policy_url_en': 'https://www.curitalk.app/en/privacy',
    });

    expect(
      status.privacyPolicyUrlFor(isKorean: true),
      'https://www.curitalk.app/privacy',
    );
    expect(
      status.privacyPolicyUrlFor(isKorean: false),
      'https://www.curitalk.app/en/privacy',
    );
  });

  testWidgets('AI consent is mandatory and acceptance is persisted', (
    tester,
  ) async {
    final repository = _ConsentRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: _ConsentHarness()),
      ),
    );

    await tester.tap(find.text('Open AI'));
    await tester.pumpAndSettle();

    expect(find.text('Consent for AI conversations'), findsOneWidget);
    expect(find.text('Privacy policy'), findsOneWidget);
    await tester.tap(find.text('Decide later'));
    await tester.pumpAndSettle();
    expect(find.text('result:false'), findsOneWidget);
    expect(repository.acceptCalls, 0);
    expect(repository.choices, [false]);

    await tester.tap(find.text('Open AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();

    expect(find.text('result:true'), findsOneWidget);
    expect(repository.acceptCalls, 1);
  });
  testWidgets(
    'save failure keeps the notice open and retries without granting access',
    (tester) async {
      final repository = _ConsentRepository()..failSave = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: _ConsentHarness()),
        ),
      );
      await tester.tap(find.text('Open AI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(find.text('result:null'), findsOneWidget);
      expect(repository.accepted, isFalse);
      expect(find.text('Retry'), findsOneWidget);
      repository.failSave = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(find.text('result:true'), findsOneWidget);
      expect(repository.acceptCalls, 1);
    },
  );

  testWidgets('valid existing consent opens AI without another prompt', (
    tester,
  ) async {
    final repository = _ConsentRepository()..accepted = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: _ConsentHarness()),
      ),
    );
    await tester.tap(find.text('Open AI'));
    await tester.pumpAndSettle();
    expect(find.text('result:true'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.choices, isEmpty);
  });
  testWidgets('privacy-only version change does not ask for AI consent again', (
    tester,
  ) async {
    final repository = _ConsentRepository()..accepted = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Notice'),
                onPressed: () => showAIConsentNotice(
                  context,
                  load: repository.getAIConsentStatus,
                  onChoice: (notice, acceptAI) async =>
                      (await repository.recordAIConsentChoice(
                        notice,
                        acceptAI: acceptAI,
                      )).accepted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Notice'));
    await tester.pumpAndSettle();
    expect(find.text('Agree and continue'), findsNothing);
    expect(find.text('Decide later'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.choices, [false]);
    expect(repository.acceptCalls, 0);
    expect(repository.accepted, isTrue);
  });
}

class _ConsentHarness extends ConsumerStatefulWidget {
  const _ConsentHarness();

  @override
  ConsumerState<_ConsentHarness> createState() => _ConsentHarnessState();
}

class _ConsentHarnessState extends ConsumerState<_ConsentHarness> {
  bool? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilledButton(
            onPressed: () async {
              final accepted = await ensureAIConsent(context, ref);
              if (mounted) setState(() => result = accepted);
            },
            child: const Text('Open AI'),
          ),
          Text('result:$result'),
        ],
      ),
    );
  }
}

class _ConsentRepository implements AuthRepository, AIConsentRepository {
  int acceptCalls = 0;
  final List<bool> choices = [];
  bool failSave = false;
  bool accepted = false;

  @override
  Future<AIConsentStatus> getAINotice() async => _status(false);

  @override
  Future<AIConsentStatus> getAIConsentStatus() async => _status(accepted);

  @override
  Future<AIConsentStatus> recordAIConsentChoice(
    AIConsentStatus notice, {
    required bool acceptAI,
  }) async {
    if (failSave) throw StateError("offline");
    choices.add(acceptAI);
    if (acceptAI) {
      acceptCalls += 1;
      accepted = true;
    }
    return _status(accepted);
  }

  @override
  Future<UserProfile> bootstrap(
    LearningLanguageContext? pendingLanguage,
    String? pendingAppLocale,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<UserProfile> getCurrentUser() {
    throw UnimplementedError();
  }

  AIConsentStatus _status(bool accepted) => AIConsentStatus(
    accepted: accepted,
    noticeAcknowledged: accepted,
    requiredVersions: const {
      'privacy_policy': '2026-11-23',
      'ai_data_processing': '2026-11-23',
    },
    acceptedVersions: accepted
        ? const {
            'privacy_policy': '2026-11-23',
            'ai_data_processing': '2026-11-23',
          }
        : const {},
    missing: accepted
        ? const []
        : const ['privacy_policy', 'ai_data_processing'],
    privacyPolicyUrl: 'https://tomatalk.app/privacy',
    privacyPolicyUrlEn: 'https://tomatalk.app/en/privacy',
  );
}
