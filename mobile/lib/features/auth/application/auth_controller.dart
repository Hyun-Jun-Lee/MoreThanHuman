import 'dart:async';

import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/snack_widget_bridge.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController extends AsyncNotifier<AuthSession> {
  late AuthRepository _repository;
  late SupabaseAuthService _supabaseAuthService;
  late GoogleIdentityService _googleIdentityService;
  late OnboardingStorage _onboardingStorage;
  late AccountLocalData _accountLocalData;
  late AuthSessionCoordinator _sessionCoordinator;
  late SnackWidgetBridge _snackWidgetBridge;
  StreamSubscription<SupabaseSessionChange>? _authSubscription;

  @override
  Future<AuthSession> build() async {
    _repository = ref.watch(authRepositoryProvider);
    _supabaseAuthService = ref.watch(supabaseAuthServiceProvider);
    _googleIdentityService = ref.watch(googleIdentityServiceProvider);
    _onboardingStorage = ref.watch(onboardingStorageProvider);
    _accountLocalData = ref.watch(accountLocalDataProvider);
    _snackWidgetBridge = ref.watch(snackWidgetBridgeProvider);
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

  Future<void> reloadProfile() async {
    final userId = state.value?.user?.id;
    if (userId == null) return;
    final refreshed = await _repository.getCurrentUser();
    if (refreshed.id != userId) {
      throw StateError('Refreshed profile belongs to another user.');
    }
    if (ref.mounted && state.value?.user?.id == userId) {
      state = AsyncData<AuthSession>(AuthSession.fromProfile(refreshed));
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
      if (previousSession.isGuest &&
          _supabaseAuthService is IdentityLinkingAuthService) {
        final linking = _supabaseAuthService as IdentityLinkingAuthService;
        try {
          await linking.linkGoogleIdentity(
            idToken: tokens.idToken.trim(),
            accessToken: tokens.accessToken.trim(),
          );
        } on IdentityAlreadyLinkedException {
          await _prepareGuestTransfer();
          await _supabaseAuthService.signInWithGoogleTokens(
            idToken: tokens.idToken.trim(),
            accessToken: tokens.accessToken.trim(),
          );
        }
      } else {
        await _supabaseAuthService.signInWithGoogleTokens(
          idToken: tokens.idToken.trim(),
          accessToken: tokens.accessToken.trim(),
        );
      }
      debugPrint('CuritalkAuth controller: Supabase sign-in completed');
      _sessionCoordinator.activateSession();
      debugPrint('CuritalkAuth controller: requesting /auth/bootstrap');
      final UserProfile user = await _bootstrapAndClaimGuestTransfer();
      debugPrint(
        'CuritalkAuth controller: bootstrap success userId=${user.id}',
      );
      state = AsyncData<AuthSession>(AuthSession.fromProfile(user));
    } on Object catch (error, stackTrace) {
      debugPrint('CuritalkAuth controller sign-in failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (previousSession.isGuest) {
        state = await AsyncValue.guard(_recoverGuestConversion);
      } else if (previousSession.isAuthenticated) {
        await _signOutSafely();
        _sessionCoordinator.activateSession();
        state = AsyncData<AuthSession>(previousSession);
      } else {
        await _signOutSafely();
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
      if (previousSession.isGuest &&
          _supabaseAuthService is IdentityLinkingAuthService) {
        final linking = _supabaseAuthService as IdentityLinkingAuthService;
        try {
          await linking.linkAppleIdentity(
            idToken: tokens.idToken.trim(),
            rawNonce: tokens.rawNonce.trim(),
          );
        } on IdentityAlreadyLinkedException {
          await _prepareGuestTransfer();
          await _supabaseAuthService.signInWithAppleToken(
            idToken: tokens.idToken.trim(),
            rawNonce: tokens.rawNonce.trim(),
          );
        }
      } else {
        await _supabaseAuthService.signInWithAppleToken(
          idToken: tokens.idToken.trim(),
          rawNonce: tokens.rawNonce.trim(),
        );
      }
      _sessionCoordinator.activateSession();
      final UserProfile user = await _bootstrapAndClaimGuestTransfer();
      state = AsyncData<AuthSession>(AuthSession.fromProfile(user));
    } on Object catch (error, stackTrace) {
      if (previousSession.isGuest) {
        state = await AsyncValue.guard(_recoverGuestConversion);
      } else if (previousSession.isAuthenticated) {
        await _signOutSafely();
        _sessionCoordinator.activateSession();
        state = AsyncData<AuthSession>(previousSession);
      } else {
        await _signOutSafely();
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
    await _clearSnackWidget();
    state = await AsyncValue.guard(_createGuestSession);
  }

  Future<void> continueAsGuest() async {
    await _accountLocalData.allowGuestCreation();
    state = const AsyncLoading<AuthSession>();
    state = await AsyncValue.guard(_createGuestSession);
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
    await _accountLocalData.suppressGuestCreation();
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
        await _snackWidgetBridge.clear();
      } on Object catch (error) {
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
    state = AsyncData<AuthSession>(AuthSession.fromProfile(updated));
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
      state = AsyncData<AuthSession>(AuthSession.fromProfile(updated));
    }
  }

  Future<AuthSession> _restoreSession() async {
    final bool hasSession = await _supabaseAuthService.hasCurrentSession();
    if (!hasSession) {
      if (await _accountLocalData.isGuestCreationSuppressed() ||
          !await _onboardingStorage.isCompleted()) {
        _sessionCoordinator.deactivateSession();
        await _clearSnackWidget();
        return const AuthSession.unauthenticated();
      }
      return _createGuestSession();
    }

    try {
      final UserProfile user = await _bootstrapProfile();
      _sessionCoordinator.activateSession();
      final session = AuthSession.fromProfile(user);
      if (session.isGuest) unawaited(_clearSnackWidget());
      return session;
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.unauthorized) {
        rethrow;
      }
      _sessionCoordinator.deactivateSession();
      await _signOutSafely();
      await _clearSnackWidget();
      return const AuthSession.unauthenticated();
    }
  }

  Future<AuthSession> _createGuestSession() async {
    if (_supabaseAuthService case final AnonymousAuthService anonymousAuth) {
      if (!await _supabaseAuthService.hasCurrentSession()) {
        await anonymousAuth.signInAnonymously();
      }
      final profile = await _bootstrapProfile();
      _sessionCoordinator.activateSession();
      final session = AuthSession.fromProfile(profile);
      if (session.isGuest) unawaited(_clearSnackWidget());
      return session;
    }
    _sessionCoordinator.deactivateSession();
    return const AuthSession.unauthenticated();
  }

  void _handleSupabaseSessionChange(SupabaseSessionChange change) {
    if (change.event == SupabaseSessionEvent.signedOut) {
      _sessionCoordinator.deactivateSession();
      state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
      unawaited(_clearSnackWidget());
    }
  }

  void _handleSessionExpired() {
    state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
    unawaited(_clearSnackWidget());
  }

  Future<void> _clearSnackWidget() async {
    try {
      await _snackWidgetBridge.clear();
    } on Object {
      // 위젯 연결 실패가 로그아웃을 막지 않아요.
    }
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

  Future<void> _prepareGuestTransfer() async {
    if (await _accountLocalData.readGuestTransferReceipt() != null) return;
    final repository = _repository;
    if (repository is! GuestTransferRepository) {
      throw StateError('Guest transfer is unavailable.');
    }
    final transfer = await (repository as GuestTransferRepository)
        .issueGuestTransferReceipt();
    await _accountLocalData.saveGuestTransferReceipt(transfer.receipt);
  }

  Future<UserProfile> _bootstrapAndClaimGuestTransfer() async {
    final profile = await _bootstrapProfile();
    if (profile.isGuest) return profile;
    final receipt = await _accountLocalData.readGuestTransferReceipt();
    if (receipt == null) return profile;
    final repository = _repository;
    if (repository is! GuestTransferRepository) return profile;
    final merged = await (repository as GuestTransferRepository)
        .claimGuestTransferReceipt(receipt);
    await _accountLocalData.clearAccountScopedLearningData(merged.guestUserId);
    await _accountLocalData.clearGuestTransferReceipt();
    return merged.profile;
  }

  Future<AuthSession> _recoverGuestConversion() async {
    if (await _supabaseAuthService.hasCurrentSession()) {
      final profile = await _bootstrapAndClaimGuestTransfer();
      _sessionCoordinator.activateSession();
      return AuthSession.fromProfile(profile);
    }
    await _signOutSafely();
    return _createGuestSession();
  }
}

final AsyncNotifierProvider<AuthController, AuthSession>
authControllerProvider = AsyncNotifierProvider<AuthController, AuthSession>(
  AuthController.new,
);
