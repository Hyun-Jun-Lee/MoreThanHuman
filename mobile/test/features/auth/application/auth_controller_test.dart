import 'dart:async';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts unauthenticated when Supabase has no current session', () async {
    final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService();
    final _FakeAuthRepository repository = _FakeAuthRepository();
    final ProviderContainer container = _createContainer(
      supabaseAuth,
      repository,
    );
    addTearDown(container.dispose);

    final AuthSession session = await container.read(
      authControllerProvider.future,
    );

    expect(session.status, AuthStatus.unauthenticated);
    expect(repository.profileRequestCount, 0);
  });

  test(
    'restores an authenticated session from Supabase current session',
    () async {
      final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService(
        hasSession: true,
      );
      final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
      final ProviderContainer container = _createContainer(
        supabaseAuth,
        repository,
      );
      addTearDown(container.dispose);

      final AuthSession session = await container.read(
        authControllerProvider.future,
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.user?.email, 'learner@example.com');
      expect(repository.profileRequestCount, 1);
    },
  );

  test(
    'Google token login creates Supabase session and publishes the user',
    () async {
      final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService();
      final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
      final ProviderContainer container = _createContainer(
        supabaseAuth,
        repository,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .signInWithGoogleTokens(
            const GoogleIdentityTokens(
              idToken: ' google-id-token ',
              accessToken: ' google-access-token ',
            ),
          );

      final AuthSession session = container
          .read(authControllerProvider)
          .requireValue;
      expect(session.isAuthenticated, isTrue);
      expect(supabaseAuth.lastIdToken, 'google-id-token');
      expect(supabaseAuth.lastAccessToken, 'google-access-token');
      expect(repository.profileRequestCount, 1);
    },
  );

  test(
    'syncs pending onboarding language before publishing the user',
    () async {
      final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService();
      final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
      final _FakeOnboardingStorage onboardingStorage = _FakeOnboardingStorage(
        pendingLanguage: const LearningLanguageContext(
          nativeLanguage: LearningLanguageCode.zh,
          targetLanguage: LearningLanguageCode.ko,
          feedbackLanguage: LearningLanguageCode.zh,
        ),
      );
      final _FakeLanguagePreferencesRepository languageRepository =
          _FakeLanguagePreferencesRepository();
      final ProviderContainer container = _createContainer(
        supabaseAuth,
        repository,
        onboardingStorage: onboardingStorage,
        languageRepository: languageRepository,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container
          .read(authControllerProvider.notifier)
          .signInWithGoogleTokens(
            const GoogleIdentityTokens(
              idToken: 'google-id-token',
              accessToken: 'google-access-token',
            ),
          );

      expect(
        languageRepository.updated.single.targetLanguage,
        LearningLanguageCode.ko,
      );
      expect(onboardingStorage.pendingLanguage, isNull);
      expect(
        container.read(authControllerProvider).requireValue.isAuthenticated,
        isTrue,
      );
    },
  );

  test(
    'session expiration immediately publishes unauthenticated state',
    () async {
      final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService(
        hasSession: true,
      );
      final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
      final AuthSessionCoordinator sessionCoordinator =
          AuthSessionCoordinator();
      final ProviderContainer container = _createContainer(
        supabaseAuth,
        repository,
        sessionCoordinator: sessionCoordinator,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      sessionCoordinator.expireSession();

      expect(
        container.read(authControllerProvider).requireValue.status,
        AuthStatus.unauthenticated,
      );
    },
  );

  test(
    'network failure during restore keeps Supabase session for a later retry',
    () async {
      final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService(
        hasSession: true,
      );
      final _FakeAuthRepository repository = _FakeAuthRepository(
        profileError: const ApiException(
          kind: ApiErrorKind.network,
          message: 'offline',
        ),
      );
      final ProviderContainer container = _createContainer(
        supabaseAuth,
        repository,
      );
      addTearDown(container.dispose);
      final Completer<Object?> errorCompleter = Completer<Object?>();
      final ProviderSubscription<AsyncValue<AuthSession>> subscription =
          container.listen(authControllerProvider, (
            _,
            AsyncValue<AuthSession> next,
          ) {
            if (next.hasError && !errorCompleter.isCompleted) {
              errorCompleter.complete(next.error);
            }
          });
      addTearDown(subscription.close);

      container.read(authControllerProvider);
      final Object? error = await errorCompleter.future;

      expect(error, isA<ApiException>());
      expect(supabaseAuth.hasSession, isTrue);
    },
  );

  test('unauthorized restore signs out Supabase session', () async {
    final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService(
      hasSession: true,
    );
    final _FakeAuthRepository repository = _FakeAuthRepository(
      profileError: const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'expired',
        statusCode: 401,
      ),
    );
    final ProviderContainer container = _createContainer(
      supabaseAuth,
      repository,
    );
    addTearDown(container.dispose);

    final AuthSession session = await container.read(
      authControllerProvider.future,
    );

    expect(session.status, AuthStatus.unauthenticated);
    expect(supabaseAuth.hasSession, isFalse);
  });

  test(
    'logout signs out Supabase and Google even when one side fails',
    () async {
      final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService(
        hasSession: true,
      );
      final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
      final _FakeGoogleIdentityService googleIdentityService =
          _FakeGoogleIdentityService(
            signOutError: StateError('google offline'),
          );
      final ProviderContainer container = _createContainer(
        supabaseAuth,
        repository,
        googleIdentityService: googleIdentityService,
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).logout();

      expect(supabaseAuth.hasSession, isFalse);
      expect(googleIdentityService.signOutCount, 1);
      expect(
        container.read(authControllerProvider).requireValue.status,
        AuthStatus.unauthenticated,
      );
    },
  );
}

final UserProfile _user = UserProfile(
  id: 'user-id',
  email: 'learner@example.com',
  name: 'Learner',
  isActive: true,
  oauthProvider: 'google',
  createdAt: DateTime.utc(2026, 6, 23),
  updatedAt: DateTime.utc(2026, 6, 23),
);

ProviderContainer _createContainer(
  _FakeSupabaseAuthService supabaseAuth,
  _FakeAuthRepository repository, {
  AuthSessionCoordinator? sessionCoordinator,
  _FakeGoogleIdentityService? googleIdentityService,
  _FakeOnboardingStorage? onboardingStorage,
  _FakeLanguagePreferencesRepository? languageRepository,
}) {
  final AuthSessionCoordinator coordinator =
      sessionCoordinator ?? AuthSessionCoordinator();
  return ProviderContainer(
    overrides: [
      authSessionCoordinatorProvider.overrideWithValue(coordinator),
      authRepositoryProvider.overrideWithValue(repository),
      onboardingStorageProvider.overrideWithValue(
        onboardingStorage ?? _FakeOnboardingStorage(),
      ),
      languagePreferencesRepositoryProvider.overrideWithValue(
        languageRepository ?? _FakeLanguagePreferencesRepository(),
      ),
      supabaseAuthServiceProvider.overrideWithValue(supabaseAuth),
      googleIdentityServiceProvider.overrideWithValue(
        googleIdentityService ?? _FakeGoogleIdentityService(),
      ),
    ],
  );
}

class _FakeOnboardingStorage implements OnboardingStorage {
  _FakeOnboardingStorage({this.pendingLanguage});

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
  final List<LearningLanguageContext> updated = <LearningLanguageContext>[];

  @override
  Future<LearningLanguageContext> getLanguagePreferences() async {
    if (updated.isEmpty) {
      return LearningLanguageContext.defaultContext;
    }
    return updated.last;
  }

  @override
  Future<LearningLanguageContext> updateLanguagePreferences(
    LearningLanguageContext context,
  ) async {
    updated.add(context);
    return context;
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.user, this.profileError});

  final UserProfile? user;
  final Object? profileError;
  int profileRequestCount = 0;

  @override
  Future<UserProfile> getCurrentUser() async {
    profileRequestCount += 1;
    if (profileError case final Object error) {
      throw error;
    }
    return user ?? _user;
  }
}

class _FakeSupabaseAuthService implements SupabaseAuthService {
  _FakeSupabaseAuthService({this.hasSession = false});

  bool hasSession;
  String? lastIdToken;
  String? lastAccessToken;
  final StreamController<SupabaseSessionChange> _controller =
      StreamController<SupabaseSessionChange>.broadcast();

  @override
  Stream<SupabaseSessionChange> get authStateChanges => _controller.stream;

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
    lastAccessToken = accessToken;
    hasSession = true;
    _controller.add(
      const SupabaseSessionChange(
        event: SupabaseSessionEvent.signedIn,
        hasSession: true,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    hasSession = false;
    _controller.add(
      const SupabaseSessionChange(
        event: SupabaseSessionEvent.signedOut,
        hasSession: false,
      ),
    );
  }
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  _FakeGoogleIdentityService({this.signOutError});

  final Object? signOutError;
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
    if (signOutError case final Object error) {
      throw error;
    }
  }
}
