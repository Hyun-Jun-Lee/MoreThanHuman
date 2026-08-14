import 'dart:async';

import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('removes hamburger and opens account sheet from profile avatar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_rounded), findsNothing);

    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('Learner Kim'), findsOneWidget);
    expect(find.text('learner@example.com'), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);
    expect(
      find.text(
        'Applies to new conversations. Existing conversations keep the language pair they started with.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('language pair save refreshes Home active pair', (
    WidgetTester tester,
  ) async {
    final _FakeLanguagePreferencesRepository languageRepository =
        _FakeLanguagePreferencesRepository();
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      languageProvider: () => languageRepository.currentLanguage,
    );

    await tester.pumpWidget(
      _homeApp(
        authRepository: authRepository,
        languagePreferencesRepository: languageRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KR -> EN'), findsOneWidget);

    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SAVE LANGUAGE PAIR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE LANGUAGE PAIR'));
    await tester.pumpAndSettle();

    expect(find.text('EN -> KR'), findsOneWidget);
    expect(
      languageRepository.currentLanguage.targetLanguage,
      LearningLanguageCode.ko,
    );
  });

  testWidgets('language pair save failure keeps policy note visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(
        languagePreferencesRepository: _FakeLanguagePreferencesRepository(
          throwOnUpdate: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('L'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('SAVE LANGUAGE PAIR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE LANGUAGE PAIR'));
    await tester.pumpAndSettle();

    expect(find.text('Language pair could not be saved.'), findsOneWidget);
    expect(
      find.text(
        'Applies to new conversations. Existing conversations keep the language pair they started with.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Chat tab opens start conversation sheet', (
    WidgetTester tester,
  ) async {
    ConversationStartType? selectedType;

    await tester.pumpWidget(
      _homeApp(
        onStartTypeSelected: (ConversationStartType type) {
          selectedType = type;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Start a conversation'), findsOneWidget);

    await tester.tap(find.text('Free Chat'));
    await tester.pumpAndSettle();

    expect(selectedType, ConversationStartType.freeChat);
  });

  testWidgets('Home add button opens start conversation sheet', (
    WidgetTester tester,
  ) async {
    ConversationStartType? selectedType;

    await tester.pumpWidget(
      _homeApp(
        onStartTypeSelected: (ConversationStartType type) {
          selectedType = type;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Start conversation'));
    await tester.pumpAndSettle();

    expect(find.text('Start a conversation'), findsOneWidget);

    await tester.tap(find.text('Free Chat'));
    await tester.pumpAndSettle();

    expect(selectedType, ConversationStartType.freeChat);
  });

  testWidgets('Home empty state shows a single start conversation CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();

    expect(find.text('START CONVERSATION'), findsOneWidget);
  });

  testWidgets('History tab calls navigation callback', (
    WidgetTester tester,
  ) async {
    int historyTapCount = 0;

    await tester.pumpWidget(
      _homeApp(onHistorySelected: () => historyTapCount += 1),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('History'));

    expect(historyTapCount, 1);
  });

  testWidgets('Profile tab opens account sheet and logout clears session', (
    WidgetTester tester,
  ) async {
    final _MemoryTokenStorage tokenStorage = _MemoryTokenStorage(
      tokens: _tokens,
      deviceId: _deviceId,
    );
    final _FakeAuthRepository authRepository = _FakeAuthRepository();
    final _FakeGoogleIdentityService googleIdentityService =
        _FakeGoogleIdentityService();
    final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService(
      hasSession: true,
    );

    await tester.pumpWidget(
      _homeApp(
        tokenStorage: tokenStorage,
        authRepository: authRepository,
        googleIdentityService: googleIdentityService,
        supabaseAuth: supabaseAuth,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    expect(supabaseAuth.hasSession, isFalse);
    expect(googleIdentityService.signOutCount, 1);
  });

  testWidgets('Google sign out failure does not block app logout', (
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
      _homeApp(
        tokenStorage: tokenStorage,
        supabaseAuth: supabaseAuth,
        googleIdentityService: _FakeGoogleIdentityService(throwOnSignOut: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();

    expect(supabaseAuth.hasSession, isFalse);
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

Widget _homeApp({
  _MemoryTokenStorage? tokenStorage,
  _FakeAuthRepository? authRepository,
  _FakeLanguagePreferencesRepository? languagePreferencesRepository,
  _FakeGoogleIdentityService? googleIdentityService,
  _FakeSupabaseAuthService? supabaseAuth,
  ValueChanged<ConversationStartType>? onStartTypeSelected,
  VoidCallback? onHistorySelected,
}) {
  final _MemoryTokenStorage effectiveTokenStorage =
      tokenStorage ?? _MemoryTokenStorage(tokens: _tokens, deviceId: _deviceId);
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(effectiveTokenStorage),
      installationIdServiceProvider.overrideWithValue(
        InstallationIdService(
          effectiveTokenStorage,
          generateId: () => _deviceId,
        ),
      ),
      authRepositoryProvider.overrideWithValue(
        authRepository ?? _FakeAuthRepository(),
      ),
      onboardingStorageProvider.overrideWithValue(_FakeOnboardingStorage()),
      languagePreferencesRepositoryProvider.overrideWithValue(
        languagePreferencesRepository ?? _FakeLanguagePreferencesRepository(),
      ),
      googleIdentityServiceProvider.overrideWithValue(
        googleIdentityService ?? _FakeGoogleIdentityService(),
      ),
      supabaseAuthServiceProvider.overrideWithValue(
        supabaseAuth ?? _FakeSupabaseAuthService(hasSession: true),
      ),
      homeRepositoryProvider.overrideWithValue(const _FakeHomeRepository()),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: HomeScreen(
        onStartTypeSelected: onStartTypeSelected,
        onHistorySelected: onHistorySelected,
      ),
    ),
  );
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  _FakeGoogleIdentityService({this.throwOnSignOut = false});

  final bool throwOnSignOut;
  int signOutCount = 0;

  @override
  Future<GoogleIdentityTokens?> signIn() async {
    return const GoogleIdentityTokens(
      idToken: 'google-id-token',
      accessToken: 'google-access-token',
    );
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    if (throwOnSignOut) {
      throw StateError('google unavailable');
    }
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.languageProvider});

  final LearningLanguageContext Function()? languageProvider;

  @override
  Future<UserProfile> getCurrentUser() async {
    return _userWithLanguage(
      languageProvider?.call() ?? LearningLanguageContext.defaultContext,
    );
  }
}

class _FakeOnboardingStorage implements OnboardingStorage {
  LearningLanguageContext? pendingLanguage;

  @override
  Future<void> clearPendingLanguageContext() async {
    pendingLanguage = null;
  }

  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> markCompleted() async {}

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
  _FakeLanguagePreferencesRepository({this.throwOnUpdate = false});

  final bool throwOnUpdate;
  LearningLanguageContext currentLanguage =
      LearningLanguageContext.defaultContext;

  @override
  Future<LearningLanguageContext> getLanguagePreferences() async {
    return currentLanguage;
  }

  @override
  Future<LearningLanguageContext> updateLanguagePreferences(
    LearningLanguageContext context,
  ) async {
    if (throwOnUpdate) {
      throw StateError('language unavailable');
    }
    currentLanguage = context;
    return context;
  }
}

UserProfile _userWithLanguage(LearningLanguageContext language) {
  return UserProfile(
    id: _user.id,
    email: _user.email,
    name: _user.name,
    isActive: _user.isActive,
    oauthProvider: _user.oauthProvider,
    language: language,
    createdAt: _user.createdAt,
    updatedAt: _user.updatedAt,
  );
}

class _FakeSupabaseAuthService implements SupabaseAuthService {
  _FakeSupabaseAuthService({this.hasSession = false});

  bool hasSession;

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
