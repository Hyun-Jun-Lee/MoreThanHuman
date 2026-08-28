import 'dart:async';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/data/api_auth_repository.dart';
import 'package:curitalk/features/auth/data/google_identity_service.dart';
import 'package:curitalk/features/auth/data/supabase_auth_service.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:curitalk/features/auth/domain/auth_session.dart';
import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/data/onboarding_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController extends AsyncNotifier<AuthSession> {
  late AuthRepository _repository;
  late SupabaseAuthService _supabaseAuthService;
  late GoogleIdentityService _googleIdentityService;
  late LanguagePreferencesRepository _languagePreferencesRepository;
  late OnboardingStorage _onboardingStorage;
  late AuthSessionCoordinator _sessionCoordinator;
  StreamSubscription<SupabaseSessionChange>? _authSubscription;

  @override
  Future<AuthSession> build() async {
    _repository = ref.watch(authRepositoryProvider);
    _supabaseAuthService = ref.watch(supabaseAuthServiceProvider);
    _googleIdentityService = ref.watch(googleIdentityServiceProvider);
    _languagePreferencesRepository = ref.watch(
      languagePreferencesRepositoryProvider,
    );
    _onboardingStorage = ref.watch(onboardingStorageProvider);
    final AuthSessionCoordinator sessionCoordinator = ref.watch(
      authSessionCoordinatorProvider,
    );
    _sessionCoordinator = sessionCoordinator;
    sessionCoordinator.addExpirationListener(_handleSessionExpired);
    _authSubscription = _supabaseAuthService.authStateChanges.listen(
      _handleSupabaseSessionChange,
      onError: (_) {},
    );
    ref.onDispose(() {
      sessionCoordinator.removeExpirationListener(_handleSessionExpired);
      unawaited(_authSubscription?.cancel());
    });
    return _restoreSession();
  }

  Future<void> restoreSession() async {
    state = const AsyncLoading<AuthSession>();
    state = await AsyncValue.guard(_restoreSession);
  }

  Future<void> signInWithGoogleTokens(GoogleIdentityTokens tokens) async {
    if (tokens.idToken.trim().isEmpty || tokens.accessToken.trim().isEmpty) {
      throw ArgumentError.value(tokens, 'tokens', 'Must not be empty.');
    }

    final AuthSession previousSession =
        state.value ?? const AuthSession.unauthenticated();
    state = const AsyncLoading<AuthSession>();
    try {
      debugPrint('CuritalkAuth controller: signing in with Supabase');
      await _supabaseAuthService.signInWithGoogleTokens(
        idToken: tokens.idToken.trim(),
        accessToken: tokens.accessToken.trim(),
      );
      debugPrint('CuritalkAuth controller: Supabase sign-in completed');
      _sessionCoordinator.activateSession();
      debugPrint('CuritalkAuth controller: requesting /auth/me');
      await _syncPendingLanguageContext();
      final UserProfile user = await _repository.getCurrentUser();
      debugPrint('CuritalkAuth controller: /auth/me success userId=${user.id}');
      state = AsyncData<AuthSession>(AuthSession.authenticated(user));
    } on Object catch (error, stackTrace) {
      debugPrint('CuritalkAuth controller sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _signOutSafely();
      if (previousSession.isAuthenticated) {
        _sessionCoordinator.activateSession();
        state = AsyncData<AuthSession>(previousSession);
      } else {
        _sessionCoordinator.deactivateSession();
        state = AsyncError<AuthSession>(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading<AuthSession>();
    _sessionCoordinator.deactivateSession();
    await _signOutSafely();
    state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
  }

  Future<void> updateAppLocale(String appLocale) async {
    final UserProfile? currentUser = state.value?.user;
    if (currentUser == null) {
      throw StateError('A signed-in user is required to update app locale.');
    }
    final AuthRepository repository = _repository;
    if (repository is! AppLocaleRepository) {
      throw StateError(
        'App locale updates are unavailable for this repository.',
      );
    }
    final UserProfile updated = await (repository as AppLocaleRepository)
        .updateAppLocale(appLocale);
    state = AsyncData<AuthSession>(AuthSession.authenticated(updated));
  }

  Future<AuthSession> _restoreSession() async {
    final bool hasSession = await _supabaseAuthService.hasCurrentSession();
    if (!hasSession) {
      _sessionCoordinator.deactivateSession();
      return const AuthSession.unauthenticated();
    }

    try {
      await _syncPendingLanguageContext();
      final UserProfile user = await _repository.getCurrentUser();
      _sessionCoordinator.activateSession();
      return AuthSession.authenticated(user);
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.unauthorized) {
        rethrow;
      }
      _sessionCoordinator.deactivateSession();
      await _signOutSafely();
      return const AuthSession.unauthenticated();
    }
  }

  void _handleSupabaseSessionChange(SupabaseSessionChange change) {
    if (change.event == SupabaseSessionEvent.signedOut) {
      _sessionCoordinator.deactivateSession();
      state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
    }
  }

  void _handleSessionExpired() {
    state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
  }

  Future<void> _signOutSafely() async {
    try {
      await _supabaseAuthService.signOut();
    } on Object {
      // 로컬 상태 정리가 더 중요하므로 무시해요.
    }
    try {
      await _googleIdentityService.signOut();
    } on Object {
      // Google SDK 로그아웃 실패는 다음 로그인에서 복구 가능해요.
    }
  }

  Future<void> _syncPendingLanguageContext() async {
    final LearningLanguageContext? pending = await _onboardingStorage
        .readPendingLanguageContext();
    if (pending == null) {
      return;
    }
    await _languagePreferencesRepository.updateLanguagePreferences(pending);
    await _onboardingStorage.clearPendingLanguageContext();
  }
}

final AsyncNotifierProvider<AuthController, AuthSession>
authControllerProvider = AsyncNotifierProvider<AuthController, AuthSession>(
  AuthController.new,
);
