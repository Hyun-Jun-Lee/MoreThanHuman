import 'dart:async';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/auth/data/account_local_data.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a guest session when onboarding is complete', () async {
    final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService();
    final _FakeAuthRepository repository = _FakeAuthRepository(user: _guest);
    final ProviderContainer container = _createContainer(
      supabaseAuth,
      repository,
    );
    addTearDown(container.dispose);

    final AuthSession session = await container.read(
      authControllerProvider.future,
    );

    expect(session.status, AuthStatus.guest);
    expect(session.isGuest, isTrue);
    expect(supabaseAuth.anonymousSignInCount, 1);
    expect(repository.profileRequestCount, 1);
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
      expect(session.isMember, isTrue);
      expect(session.user?.email, 'learner@example.com');
      expect(repository.profileRequestCount, 1);
      expect(repository.bootstrapRequestCount, 1);
      expect(repository.getCurrentUserCount, 0);
    },
  );

  test(
    'restores a guest session without creating another anonymous user',
    () async {
      final supabaseAuth = _FakeSupabaseAuthService(hasSession: true);
      final repository = _FakeAuthRepository(user: _guest);
      final container = _createContainer(supabaseAuth, repository);
      addTearDown(container.dispose);

      final session = await container.read(authControllerProvider.future);

      expect(session.status, AuthStatus.guest);
      expect(session.user?.id, 'guest-id');
      expect(supabaseAuth.anonymousSignInCount, 0);
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
      expect(repository.profileRequestCount, 2);
    },
  );

  test(
    'Apple token login forwards the raw nonce and publishes the user',
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
          .signInWithAppleToken(
            const AppleIdentityTokens(
              idToken: ' apple-id-token ',
              rawNonce: ' raw-nonce ',
            ),
          );

      expect(supabaseAuth.lastAppleIdToken, 'apple-id-token');
      expect(supabaseAuth.lastRawNonce, 'raw-nonce');
      expect(repository.profileRequestCount, 2);
      expect(
        container.read(authControllerProvider).requireValue.isAuthenticated,
        isTrue,
      );
    },
  );

  test('guest links a new identity without changing its user id', () async {
    final supabaseAuth = _FakeSupabaseAuthService();
    final repository = _FakeAuthRepository(user: _guest);
    final container = _createContainer(supabaseAuth, repository);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    repository.user = UserProfile(
      id: _guest.id,
      email: 'linked@example.com',
      name: _guest.name,
      isActive: true,
      isGuest: false,
      oauthProvider: 'google',
      createdAt: _guest.createdAt,
      updatedAt: _guest.updatedAt,
    );

    await container
        .read(authControllerProvider.notifier)
        .signInWithGoogleTokens(
          const GoogleIdentityTokens(
            idToken: 'google-id-token',
            accessToken: 'google-access-token',
          ),
        );

    expect(supabaseAuth.googleLinkCount, 1);
    expect(supabaseAuth.googleSignInCount, 0);
    expect(
      container.read(authControllerProvider).requireValue.user?.id,
      'guest-id',
    );
    expect(
      container.read(authControllerProvider).requireValue.isMember,
      isTrue,
    );
  });

  test('failed identity link keeps the original guest session', () async {
    final supabaseAuth = _FakeSupabaseAuthService(
      linkError: StateError('temporary link failure'),
    );
    final repository = _FakeAuthRepository(user: _guest);
    final container = _createContainer(supabaseAuth, repository);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await expectLater(
      container
          .read(authControllerProvider.notifier)
          .signInWithGoogleTokens(
            const GoogleIdentityTokens(
              idToken: 'google-id-token',
              accessToken: 'google-access-token',
            ),
          ),
      throwsA(isA<StateError>()),
    );

    final session = container.read(authControllerProvider).requireValue;
    expect(session.isGuest, isTrue);
    expect(session.user?.id, 'guest-id');
    expect(supabaseAuth.hasSession, isTrue);
    expect(supabaseAuth.anonymousSignInCount, 1);
  });

  test(
    'identity conflict issues and claims a guest transfer receipt',
    () async {
      final supabaseAuth = _FakeSupabaseAuthService(linkConflict: true);
      final repository = _FakeAuthRepository(user: _guest);
      final container = _createContainer(supabaseAuth, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      repository.user = _user;

      await container
          .read(authControllerProvider.notifier)
          .signInWithGoogleTokens(
            const GoogleIdentityTokens(
              idToken: 'google-id-token',
              accessToken: 'google-access-token',
            ),
          );

      expect(repository.transferIssueCount, 1);
      expect(repository.transferClaimCount, 1);
      expect(supabaseAuth.googleSignInCount, 1);
      expect(
        container.read(authControllerProvider).requireValue.user?.id,
        'user-id',
      );
    },
  );

  test(
    'syncs pending onboarding defaults before publishing the user',
    () async {
      final _FakeSupabaseAuthService supabaseAuth = _FakeSupabaseAuthService();
      final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
      final _FakeOnboardingStorage onboardingStorage = _FakeOnboardingStorage(
        pendingLanguage: const LearningLanguageContext(
          nativeLanguage: LearningLanguageCode.zh,
          targetLanguage: LearningLanguageCode.ko,
          feedbackLanguage: LearningLanguageCode.zh,
        ),
        pendingAppLocale: 'ko',
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
        repository.bootstrapLanguages.first?.targetLanguage,
        LearningLanguageCode.ko,
      );
      expect(languageRepository.updated, isEmpty);
      expect(onboardingStorage.pendingLanguage, isNull);
      expect(repository.bootstrapAppLocales.first, 'ko');
      expect(onboardingStorage.pendingAppLocale, isNull);
      expect(
        container.read(authControllerProvider).requireValue.isAuthenticated,
        isTrue,
      );
      expect(
        container
            .read(authControllerProvider)
            .requireValue
            .user
            ?.language
            .targetLanguage,
        LearningLanguageCode.ko,
      );
    },
  );

  test('saving a nickname updates the authenticated profile', () async {
    final supabaseAuth = _FakeSupabaseAuthService(hasSession: true);
    final repository = _FakeAuthRepository(user: _user);
    final container = _createContainer(supabaseAuth, repository);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .updateNickname('Tomato');

    expect(repository.updatedNickname, 'Tomato');
    expect(
      container.read(authControllerProvider).requireValue.user?.nickname,
      'Tomato',
    );
  });

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
      final _FakeOnboardingStorage onboardingStorage = _FakeOnboardingStorage(
        pendingLanguage: LearningLanguageContext.defaultContext,
        pendingAppLocale: 'ko',
      );
      final ProviderContainer container = _createContainer(
        supabaseAuth,
        repository,
        onboardingStorage: onboardingStorage,
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
      expect(onboardingStorage.pendingLanguage, isNotNull);
      expect(onboardingStorage.pendingAppLocale, 'ko');
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

      repository.user = _guest;
      await container.read(authControllerProvider.notifier).logout();

      expect(supabaseAuth.hasSession, isTrue);
      expect(googleIdentityService.signOutCount, 1);
      expect(
        container.read(authControllerProvider).requireValue.status,
        AuthStatus.guest,
      );
    },
  );

  test(
    'guest account deletion signs out without creating a new guest',
    () async {
      final supabaseAuth = _FakeSupabaseAuthService(hasSession: true);
      final repository = _FakeAuthRepository(user: _guest);
      final container = _createContainer(supabaseAuth, repository);
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);

      final result = await container
          .read(authControllerProvider.notifier)
          .deleteAccount();

      expect(result.status, 'completed');
      expect(repository.deleteAccountCount, 1);
      expect(supabaseAuth.hasSession, isFalse);
      expect(supabaseAuth.anonymousSignInCount, 0);
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

final UserProfile _guest = UserProfile(
  id: 'guest-id',
  email: null,
  name: 'Guest',
  isActive: true,
  isGuest: true,
  createdAt: DateTime.utc(2026, 11, 23),
  updatedAt: DateTime.utc(2026, 11, 23),
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
      accountLocalDataProvider.overrideWithValue(
        AccountLocalData(_MemorySecureStorage()),
      ),
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
  _FakeOnboardingStorage({this.pendingLanguage, this.pendingAppLocale});

  LearningLanguageContext? pendingLanguage;
  String? pendingAppLocale;

  @override
  Future<void> clearPendingAppLocale() async {
    pendingAppLocale = null;
  }

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
  Future<String?> readPendingAppLocale() async => pendingAppLocale;

  @override
  Future<void> writePendingAppLocale(String appLocale) async {
    pendingAppLocale = appLocale;
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

class _FakeAuthRepository
    implements
        AuthRepository,
        NicknameRepository,
        GuestTransferRepository,
        AccountDeletionRepository {
  _FakeAuthRepository({this.user, this.profileError});

  UserProfile? user;
  final Object? profileError;
  int profileRequestCount = 0;
  int bootstrapRequestCount = 0;
  int getCurrentUserCount = 0;
  LearningLanguageContext? bootstrapLanguage;
  final List<LearningLanguageContext?> bootstrapLanguages =
      <LearningLanguageContext?>[];
  String? bootstrapAppLocale;
  final List<String?> bootstrapAppLocales = <String?>[];
  String? updatedNickname;
  int transferIssueCount = 0;
  int transferClaimCount = 0;
  int deleteAccountCount = 0;

  @override
  Future<UserProfile> getCurrentUser() async {
    profileRequestCount += 1;
    getCurrentUserCount += 1;
    if (profileError case final Object error) {
      throw error;
    }
    return user ?? _user;
  }

  @override
  Future<UserProfile> bootstrap(
    LearningLanguageContext? pendingLanguage,
    String? pendingAppLocale,
  ) async {
    profileRequestCount += 1;
    bootstrapRequestCount += 1;
    bootstrapLanguage = pendingLanguage;
    bootstrapLanguages.add(pendingLanguage);
    bootstrapAppLocale = pendingAppLocale;
    bootstrapAppLocales.add(pendingAppLocale);
    if (profileError case final Object error) {
      throw error;
    }
    final current = user ?? _user;
    final result = UserProfile(
      id: current.id,
      email: current.email,
      name: current.name,
      nickname: current.nickname,
      isActive: current.isActive,
      isAdmin: current.isAdmin,
      isGuest: current.isGuest,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
      language: pendingLanguage ?? current.language,
      appLocale: pendingAppLocale ?? current.appLocale,
      oauthProvider: current.oauthProvider,
      lastActiveAt: current.lastActiveAt,
    );
    user = result;
    return result;
  }

  @override
  Future<UserProfile> updateNickname(String nickname) async {
    updatedNickname = nickname;
    return (user ?? _user).copyWith(nickname: nickname);
  }

  @override
  Future<GuestTransferReceipt> issueGuestTransferReceipt() async {
    transferIssueCount += 1;
    return GuestTransferReceipt(
      receipt: 'guest-transfer-receipt-abcdefghijklmnopqrstuvwxyz',
      expiresAt: DateTime.utc(2026, 11, 23, 1),
    );
  }

  @override
  Future<GuestTransferClaimResult> claimGuestTransferReceipt(
    String receipt,
  ) async {
    transferClaimCount += 1;
    return GuestTransferClaimResult(
      profile: user ?? _user,
      guestUserId: 'guest-id',
    );
  }

  @override
  Future<AccountDeletionResult> deleteAccount({
    String? appleIdentityToken,
    String? appleAuthorizationCode,
  }) async {
    deleteAccountCount += 1;
    return const AccountDeletionResult(
      status: 'completed',
      receipt: 'account-deletion-receipt-abcdefghijklmnopqrstuvwxyz',
      appleDisconnectRequired: false,
    );
  }

  @override
  Future<String> deletionStatus(String receipt) async => 'completed';
}

class _FakeSupabaseAuthService
    implements
        SupabaseAuthService,
        AnonymousAuthService,
        IdentityLinkingAuthService {
  _FakeSupabaseAuthService({
    this.hasSession = false,
    this.linkConflict = false,
    this.linkError,
  });

  bool hasSession;
  final bool linkConflict;
  final Object? linkError;
  String? lastIdToken;
  String? lastAccessToken;
  String? lastAppleIdToken;
  String? lastRawNonce;
  int anonymousSignInCount = 0;
  int googleLinkCount = 0;
  int googleSignInCount = 0;
  final StreamController<SupabaseSessionChange> _controller =
      StreamController<SupabaseSessionChange>.broadcast();

  @override
  Stream<SupabaseSessionChange> get authStateChanges => _controller.stream;

  @override
  Future<void> expireSession() => signOut();

  @override
  Future<bool> hasCurrentSession() async => hasSession;

  @override
  Future<void> signInAnonymously() async {
    anonymousSignInCount += 1;
    hasSession = true;
  }

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
    googleSignInCount += 1;
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
  Future<void> linkGoogleIdentity({
    required String idToken,
    required String accessToken,
  }) async {
    googleLinkCount += 1;
    if (linkError case final Object error) throw error;
    if (linkConflict) throw const IdentityAlreadyLinkedException();
    lastIdToken = idToken;
    lastAccessToken = accessToken;
  }

  @override
  Future<void> linkAppleIdentity({
    required String idToken,
    required String rawNonce,
  }) async {
    if (linkError case final Object error) throw error;
    if (linkConflict) throw const IdentityAlreadyLinkedException();
    lastAppleIdToken = idToken;
    lastRawNonce = rawNonce;
  }

  @override
  Future<void> signInWithAppleToken({
    required String idToken,
    required String rawNonce,
  }) async {
    lastAppleIdToken = idToken;
    lastRawNonce = rawNonce;
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

class _MemorySecureStorage implements SecureStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
