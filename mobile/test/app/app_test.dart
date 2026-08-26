import 'dart:async';

import 'package:curitalk/app/app.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'first launch flows through onboarding and Google login to Home',
    (WidgetTester tester) async {
      final _MemoryTokenStorage tokenStorage = _MemoryTokenStorage();
      final _MemoryOnboardingStorage onboardingStorage =
          _MemoryOnboardingStorage(false);
      final _FakeAuthRepository authRepository = _FakeAuthRepository();
      final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService();

      await tester.pumpWidget(
        _appScope(
          tokenStorage: tokenStorage,
          onboardingStorage: onboardingStorage,
          authRepository: authRepository,
          supabaseAuth: supabaseAuth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('What do you want\nto practice?'), findsOneWidget);

      await tester.tap(find.text('SKIP'));
      await tester.pumpAndSettle();

      expect(
        find.text('Practice conversation with your own topics.'),
        findsOneWidget,
      );

      await tester.tap(find.text('CONTINUE WITH GOOGLE'));
      await tester.pumpAndSettle();

      expect(find.text('Hi, Learner'), findsOneWidget);
      expect(find.text('Welcome to Curitalk'), findsOneWidget);
      expect(onboardingStorage.completed, isTrue);
      expect(supabaseAuth.hasSession, isTrue);
      expect(supabaseAuth.lastIdToken, 'google-id-token');

      await tester.tap(find.text('START CONVERSATION').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Free Chat'));
      await tester.pumpAndSettle();

      expect(
        find.text('What topic do you want to talk about?'),
        findsOneWidget,
      );
    },
  );

  testWidgets('onboarding copy follows Korean system locale', (
    WidgetTester tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[
      Locale('ko'),
    ];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(
      _appScope(
        tokenStorage: _MemoryTokenStorage(),
        onboardingStorage: _MemoryOnboardingStorage(false),
        authRepository: _FakeAuthRepository(),
        supabaseAuth: _FakeSupabaseAuthService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('무엇을 연습할까요?'), findsOneWidget);
    expect(find.text('건너뛰기'), findsOneWidget);
    expect(find.text('계속'), findsOneWidget);
    expect(find.text('你想练习什么？'), findsNothing);
  });

  testWidgets('returning authenticated user moves from Splash to Home', (
    WidgetTester tester,
  ) async {
    final _MemoryTokenStorage tokenStorage = _MemoryTokenStorage(
      tokens: _tokens,
      deviceId: _deviceId,
    );

    await tester.pumpWidget(
      _appScope(
        tokenStorage: tokenStorage,
        onboardingStorage: _MemoryOnboardingStorage(true),
        authRepository: _FakeAuthRepository(),
        supabaseAuth: _FakeSupabaseAuthService(hasSession: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hi, Learner'), findsOneWidget);
    expect(
      find.text('Practice conversation with your own topics.'),
      findsNothing,
    );
  });

  testWidgets('authenticated user can open Roleplay Setup from Home', (
    WidgetTester tester,
  ) async {
    final _MemoryTokenStorage tokenStorage = _MemoryTokenStorage(
      tokens: _tokens,
      deviceId: _deviceId,
    );

    await tester.pumpWidget(
      _appScope(
        tokenStorage: tokenStorage,
        onboardingStorage: _MemoryOnboardingStorage(true),
        authRepository: _FakeAuthRepository(),
        supabaseAuth: _FakeSupabaseAuthService(hasSession: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('START CONVERSATION').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roleplay'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a situation'), findsOneWidget);
    expect(find.text('Cafe order'), findsOneWidget);
  });

  testWidgets('authenticated user can open History from bottom navigation', (
    WidgetTester tester,
  ) async {
    final _MemoryTokenStorage tokenStorage = _MemoryTokenStorage(
      tokens: _tokens,
      deviceId: _deviceId,
    );

    await tester.pumpWidget(
      _appScope(
        tokenStorage: tokenStorage,
        onboardingStorage: _MemoryOnboardingStorage(true),
        authRepository: _FakeAuthRepository(),
        supabaseAuth: _FakeSupabaseAuthService(hasSession: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('No conversations yet.'), findsOneWidget);
  });

  testWidgets('authenticated user can log out from Profile tab', (
    WidgetTester tester,
  ) async {
    final _MemoryTokenStorage tokenStorage = _MemoryTokenStorage(
      tokens: _tokens,
      deviceId: _deviceId,
    );
    final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService(
      hasSession: true,
    );

    await tester.pumpWidget(
      _appScope(
        tokenStorage: tokenStorage,
        onboardingStorage: _MemoryOnboardingStorage(true),
        authRepository: _FakeAuthRepository(),
        supabaseAuth: supabaseAuth,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    expect(supabaseAuth.hasSession, isFalse);
    expect(
      find.text('Practice conversation with your own topics.'),
      findsOneWidget,
    );
  });
}

const String _deviceId = '550e8400-e29b-41d4-a716-446655440000';
const AuthTokens _tokens = AuthTokens(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
);
final UserProfile _user = UserProfile(
  id: 'user-id',
  email: 'learner@example.com',
  name: 'Learner Kim',
  isActive: true,
  oauthProvider: 'google',
  createdAt: DateTime.utc(2026, 6, 24),
  updatedAt: DateTime.utc(2026, 6, 24),
);

ProviderScope _appScope({
  required _MemoryTokenStorage tokenStorage,
  required _MemoryOnboardingStorage onboardingStorage,
  required _FakeAuthRepository authRepository,
  _FakeSupabaseAuthService? supabaseAuth,
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(tokenStorage),
      installationIdServiceProvider.overrideWithValue(
        InstallationIdService(tokenStorage, generateId: () => _deviceId),
      ),
      onboardingStorageProvider.overrideWithValue(onboardingStorage),
      googleIdentityServiceProvider.overrideWithValue(
        const _FakeGoogleIdentityService(),
      ),
      authRepositoryProvider.overrideWithValue(authRepository),
      languagePreferencesRepositoryProvider.overrideWithValue(
        _FakeLanguagePreferencesRepository(),
      ),
      supabaseAuthServiceProvider.overrideWithValue(
        supabaseAuth ?? _FakeSupabaseAuthService(),
      ),
      homeRepositoryProvider.overrideWithValue(const _FakeHomeRepository()),
      topicPrepRepositoryProvider.overrideWithValue(
        const _FakeTopicPrepRepository(),
      ),
    ],
    child: const CuritalkApp(),
  );
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  const _FakeGoogleIdentityService();

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

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<UserProfile> getCurrentUser() async => _user;
}

class _FakeSupabaseAuthService implements SupabaseAuthService {
  _FakeSupabaseAuthService({this.hasSession = false});

  bool hasSession;
  String? lastIdToken;

  @override
  Stream<SupabaseSessionChange> get authStateChanges =>
      const Stream<SupabaseSessionChange>.empty();

  @override
  Future<void> expireSession() => signOut();

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
  }) async {
    lastIdToken = idToken;
    hasSession = true;
  }

  @override
  Future<void> signOut() async {
    hasSession = false;
  }
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository();

  @override
  Future<List<ConversationSummary>> listRecentConversations({
    int limit = 5,
  }) async {
    return const <ConversationSummary>[];
  }
}

class _FakeTopicPrepRepository implements TopicPrepRepository {
  const _FakeTopicPrepRepository();

  @override
  Future<TopicPrepResult> prepareTopic(String topic) {
    throw UnimplementedError('Topic prep is not exercised in app flow tests.');
  }
}

class _MemoryOnboardingStorage implements OnboardingStorage {
  _MemoryOnboardingStorage(this.completed);

  bool completed;
  LearningLanguageContext? pendingLanguage;

  @override
  Future<void> clearPendingLanguageContext() async {
    pendingLanguage = null;
  }

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    completed = true;
  }

  @override
  Future<LearningLanguageContext?> readPendingLanguageContext() async {
    return pendingLanguage;
  }

  @override
  Future<void> writePendingLanguageContext(
    LearningLanguageContext context,
  ) async {
    pendingLanguage = context;
  }
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

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage({this.tokens, this.deviceId});

  AuthTokens? tokens;
  String? deviceId;

  @override
  Future<void> clearTokens() async {
    tokens = null;
  }

  @override
  Future<String?> readAccessToken() async => tokens?.accessToken;

  @override
  Future<String?> readDeviceId() async => deviceId;

  @override
  Future<AuthTokens?> readTokens() async => tokens;

  @override
  Future<void> writeDeviceId(String deviceId) async {
    this.deviceId = deviceId;
  }

  @override
  Future<void> writeTokens(AuthTokens tokens) async {
    this.tokens = tokens;
  }
}
