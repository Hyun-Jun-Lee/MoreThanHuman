import 'dart:async';

import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/data/onboarding_storage.dart';
import 'package:curitalk/features/roleplay_setup/roleplay_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows preset scenarios and starts disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Choose a situation'), findsOneWidget);
    expect(find.text('Cafe order'), findsOneWidget);
    expect(find.text('Hotel check-in'), findsOneWidget);
    expect(_startButton(tester).enabled, isFalse);
  });

  testWidgets('shows Korean-practice scenarios for Korean target', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(targetLanguage: LearningLanguageCode.ko));

    expect(find.text('Polite cafe order'), findsOneWidget);
    expect(find.text('Front desk help'), findsOneWidget);
    expect(
      find.text('Order, ask for options, and close politely in Korean.'),
      findsOneWidget,
    );
  });

  testWidgets('uses authenticated target language for scenarios', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _authApp(
        language: const LearningLanguageContext(
          nativeLanguage: LearningLanguageCode.en,
          targetLanguage: LearningLanguageCode.ko,
          feedbackLanguage: LearningLanguageCode.en,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Polite cafe order'), findsOneWidget);
    expect(find.text('Cafe order'), findsNothing);
  });

  testWidgets('selecting a preset enables start', (WidgetTester tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Cafe order'));
    await tester.pumpAndSettle();

    expect(_startButton(tester).enabled, isTrue);
    expect(
      find.bySemanticsLabel('Roleplay scenario: Cafe order'),
      findsOneWidget,
    );
  });

  testWidgets('changing difficulty updates selected chip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('CHALLENGE'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Unexpected follow-ups that invite longer, more precise answers.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('difficulty selector stays above scenarios in one row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('CHOOSE DIFFICULTY'), findsOneWidget);
    final double difficultyTop = tester
        .getTopLeft(find.text('CHOOSE DIFFICULTY'))
        .dy;
    final double firstScenarioTop = tester
        .getTopLeft(find.text('Cafe order'))
        .dy;

    expect(difficultyTop, lessThan(firstScenarioTop));
    expect(
      tester.getCenter(find.text('EASY')).dy,
      closeTo(tester.getCenter(find.text('NORMAL')).dy, 0.1),
    );
    expect(
      tester.getCenter(find.text('NORMAL')).dy,
      closeTo(tester.getCenter(find.text('CHALLENGE')).dy, 0.1),
    );
  });

  testWidgets('custom input validates minimum length and enables start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'CUSTOM ROLEPLAY'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final Finder customButton = find.widgetWithText(
      OutlinedButton,
      'CUSTOM ROLEPLAY',
    );
    await Scrollable.ensureVisible(
      tester.element(customButton),
      alignment: 0.2,
    );
    await tester.pumpAndSettle();
    await tester.tap(customButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.bySemanticsLabel('Custom roleplay situation or your role'),
      'A',
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
    expect(_startButton(tester).enabled, isFalse);

    await tester.enterText(
      find.bySemanticsLabel('Custom roleplay situation or your role'),
      'I am checking in at a hotel front desk.',
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter at least 2 characters.'), findsNothing);
    expect(_startButton(tester).enabled, isTrue);
  });
}

FilledButton _startButton(WidgetTester tester) {
  return tester.widget<FilledButton>(find.byType(FilledButton));
}

Widget _app({LearningLanguageCode targetLanguage = LearningLanguageCode.en}) {
  return ProviderScope(
    overrides: [
      roleplayTargetLanguageProvider.overrideWithValue(targetLanguage),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const RoleplaySetupScreen(),
    ),
  );
}

Widget _authApp({required LearningLanguageContext language}) {
  return ProviderScope(
    overrides: [
      authSessionCoordinatorProvider.overrideWithValue(
        AuthSessionCoordinator(),
      ),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(language)),
      onboardingStorageProvider.overrideWithValue(_FakeOnboardingStorage()),
      languagePreferencesRepositoryProvider.overrideWithValue(
        _FakeLanguagePreferencesRepository(),
      ),
      supabaseAuthServiceProvider.overrideWithValue(
        _FakeSupabaseAuthService(hasSession: true),
      ),
      googleIdentityServiceProvider.overrideWithValue(
        _FakeGoogleIdentityService(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const RoleplaySetupScreen(),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.language);

  final LearningLanguageContext language;

  @override
  Future<UserProfile> getCurrentUser() async {
    return UserProfile(
      id: 'user-id',
      email: 'learner@example.com',
      name: 'Learner',
      isActive: true,
      oauthProvider: 'google',
      language: language,
      createdAt: DateTime.utc(2026, 7, 21),
      updatedAt: DateTime.utc(2026, 7, 21),
    );
  }
}

class _FakeOnboardingStorage implements OnboardingStorage {
  @override
  Future<void> clearPendingLanguageContext() async {}

  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> markCompleted() async {}

  @override
  Future<LearningLanguageContext?> readPendingLanguageContext() async => null;

  @override
  Future<void> writePendingLanguageContext(
    LearningLanguageContext context,
  ) async {}
}

class _FakeLanguagePreferencesRepository
    implements LanguagePreferencesRepository {
  @override
  Future<LearningLanguageContext> getLanguagePreferences() async {
    return LearningLanguageContext.defaultContext;
  }

  @override
  Future<LearningLanguageContext> updateLanguagePreferences(
    LearningLanguageContext context,
  ) async {
    return context;
  }
}

class _FakeSupabaseAuthService implements SupabaseAuthService {
  _FakeSupabaseAuthService({required this.hasSession});

  final bool hasSession;
  final StreamController<SupabaseSessionChange> _controller =
      StreamController<SupabaseSessionChange>.broadcast();

  @override
  Stream<SupabaseSessionChange> get authStateChanges => _controller.stream;

  @override
  Future<void> expireSession() async {}

  @override
  Future<bool> hasCurrentSession() async => hasSession;

  @override
  Future<String?> readAccessToken() async =>
      hasSession ? 'supabase-access-token' : null;

  @override
  Future<String?> refreshAccessToken({
    required String? previousAccessToken,
  }) async {
    return hasSession ? 'supabase-refreshed-token' : null;
  }

  @override
  Future<void> signInWithGoogleTokens({
    required String idToken,
    required String accessToken,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  @override
  Future<GoogleIdentityTokens?> signIn() async {
    return const GoogleIdentityTokens(
      idToken: 'google-id-token',
      accessToken: 'google-access-token',
    );
  }

  @override
  Future<void> signOut() async {}
}
