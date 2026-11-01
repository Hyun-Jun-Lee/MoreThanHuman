import 'dart:async';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/features/auth/data/api_auth_repository.dart';
import 'package:curitalk/features/auth/data/account_local_data.dart';
import 'package:curitalk/features/auth/data/apple_identity_service.dart';
import 'package:curitalk/features/auth/data/google_identity_service.dart';
import 'package:curitalk/features/auth/data/supabase_auth_service.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:curitalk/features/auth/domain/auth_session.dart';
import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/data/onboarding_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController extends AsyncNotifier<AuthSession> {
  late AuthRepository _repository;
  late SupabaseAuthService _supabaseAuthService;
  late GoogleIdentityService _googleIdentityService;
  late OnboardingStorage _onboardingStorage;
  late AccountLocalData _accountLocalData;
  late AuthSessionCoordinator _sessionCoordinator;
  StreamSubscription<SupabaseSessionChange>? _authSubscription;

  @override
  Future<AuthSession> build() async {
    _repository = ref.watch(authRepositoryProvider);
    _supabaseAuthService = ref.watch(supabaseAuthServiceProvider);
    _googleIdentityService = ref.watch(googleIdentityServiceProvider);
    _onboardingStorage = ref.watch(onboardingStorageProvider);
    _accountLocalData = ref.watch(accountLocalDataProvider);
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

  /// 설정 저장 뒤에는 현재 탭을 유지하며 프로필만 갱신해요.
  Future<void> refreshProfile() async {
    final userId = state.value?.user?.id;
    final restored = await _restoreSession();
    if (ref.mounted && state.value?.user?.id == userId) {
      state = AsyncData<AuthSession>(restored);
    }
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
      debugPrint('CuritalkAuth controller: requesting /auth/bootstrap');
      final UserProfile user = await _bootstrapProfile();
      debugPrint(
        'CuritalkAuth controller: bootstrap success userId=${user.id}',
      );
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

  Future<void> signInWithAppleToken(AppleIdentityTokens tokens) async {
    if (tokens.idToken.trim().isEmpty || tokens.rawNonce.trim().isEmpty) {
      throw ArgumentError.value(tokens, 'tokens', 'Must not be empty.');
    }

    final AuthSession previousSession =
        state.value ?? const AuthSession.unauthenticated();
    state = const AsyncLoading<AuthSession>();
    try {
      await _supabaseAuthService.signInWithAppleToken(
        idToken: tokens.idToken.trim(),
        rawNonce: tokens.rawNonce.trim(),
      );
      _sessionCoordinator.activateSession();
      final UserProfile user = await _bootstrapProfile();
      state = AsyncData<AuthSession>(AuthSession.authenticated(user));
    } on Object catch (error, stackTrace) {
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

  Future<AccountDeletionResult> deleteAccount({
    AppleIdentityTokens? appleTokens,
  }) async {
    final userId = state.value?.user?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required to delete an account.');
    }
    final repository = _repository;
    if (repository is! AccountDeletionRepository) {
      throw StateError('Account deletion is unavailable.');
    }
    final result = await (repository as AccountDeletionRepository)
        .deleteAccount(
          appleIdentityToken: appleTokens?.idToken,
          appleAuthorizationCode: appleTokens?.authorizationCode,
        );
    _sessionCoordinator.deactivateSession();
    var localCleanupFailed = false;
    try {
      if (!await _accountLocalData.clearLearningData(userId)) {
        localCleanupFailed = true;
      }
      try {
        if (result.status == 'processing') {
          await _accountLocalData.saveReceipt(result.receipt);
        } else {
          await _accountLocalData.clearReceipt();
        }
      } on Object {
        localCleanupFailed = true;
      }
      try {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await const MethodChannel(
            'com.morethanhuman.curitalk/snack_widget',
          ).invokeMethod<void>('clear');
        }
      } on MissingPluginException {
        // 위젯 확장이 없는 빌드에서도 계정 삭제는 계속해요.
      } on PlatformException catch (error) {
        localCleanupFailed = true;
        debugPrint('Could not clear local widget state: $error');
      }
    } finally {
      await _signOutSafely();
      state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
    }
    return AccountDeletionResult(
      status: result.status,
      receipt: result.receipt,
      appleDisconnectRequired: result.appleDisconnectRequired,
      localCleanupFailed: localCleanupFailed,
    );
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

  Future<void> updateNickname(String nickname) async {
    final UserProfile? currentUser = state.value?.user;
    if (currentUser == null) {
      throw StateError('A signed-in user is required to update nickname.');
    }
    final AuthRepository repository = _repository;
    if (repository is! NicknameRepository) {
      throw StateError('Nickname updates are unavailable for this repository.');
    }
    final UserProfile updated = await (repository as NicknameRepository)
        .updateNickname(nickname);
    if (ref.mounted && state.value?.user?.id == currentUser.id) {
      state = AsyncData<AuthSession>(AuthSession.authenticated(updated));
    }
  }

  Future<AuthSession> _restoreSession() async {
    final bool hasSession = await _supabaseAuthService.hasCurrentSession();
    if (!hasSession) {
      _sessionCoordinator.deactivateSession();
      return const AuthSession.unauthenticated();
    }

    try {
      final UserProfile user = await _bootstrapProfile();
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

  Future<UserProfile> _bootstrapProfile() async {
    final LearningLanguageContext? pending = await _onboardingStorage
        .readPendingLanguageContext();
    final UserProfile profile = await _repository.bootstrap(pending);
    if (pending != null) {
      await _onboardingStorage.clearPendingLanguageContext();
    }
    return profile;
  }
}

final AsyncNotifierProvider<AuthController, AuthSession>
authControllerProvider = AsyncNotifierProvider<AuthController, AuthSession>(
  AuthController.new,
);
