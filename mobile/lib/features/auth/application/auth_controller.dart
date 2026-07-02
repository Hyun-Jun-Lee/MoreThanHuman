import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/data/api_auth_repository.dart';
import 'package:curitalk/features/auth/domain/auth_repository.dart';
import 'package:curitalk/features/auth/domain/auth_session.dart';
import 'package:curitalk/features/auth/domain/user_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthController extends AsyncNotifier<AuthSession> {
  late AuthRepository _repository;
  late TokenStorage _tokenStorage;
  late InstallationIdService _installationIdService;
  late AuthSessionCoordinator _sessionCoordinator;

  @override
  Future<AuthSession> build() async {
    _repository = ref.watch(authRepositoryProvider);
    _tokenStorage = ref.watch(tokenStorageProvider);
    _installationIdService = ref.watch(installationIdServiceProvider);
    final AuthSessionCoordinator sessionCoordinator = ref.watch(
      authSessionCoordinatorProvider,
    );
    _sessionCoordinator = sessionCoordinator;
    sessionCoordinator.addExpirationListener(_handleSessionExpired);
    ref.onDispose(
      () => sessionCoordinator.removeExpirationListener(_handleSessionExpired),
    );
    return _restoreSession();
  }

  Future<void> restoreSession() async {
    state = const AsyncLoading<AuthSession>();
    state = await AsyncValue.guard(_restoreSession);
  }

  Future<void> signInWithGoogleIdToken(String idToken) async {
    final String normalizedIdToken = idToken.trim();
    if (normalizedIdToken.isEmpty) {
      throw ArgumentError.value(idToken, 'idToken', 'Must not be empty.');
    }

    final AuthSession previousSession =
        state.value ?? const AuthSession.unauthenticated();
    state = const AsyncLoading<AuthSession>();
    try {
      final String deviceId = await _installationIdService.getOrCreate();
      final AuthTokens tokens = await _repository.signInWithGoogleIdToken(
        idToken: normalizedIdToken,
        deviceId: deviceId,
      );
      _sessionCoordinator.deactivateSession();
      await _tokenStorage.writeTokens(tokens);
      _sessionCoordinator.activateSession();
      final UserProfile user = await _repository.getCurrentUser();
      state = AsyncData<AuthSession>(AuthSession.authenticated(user));
    } on Object catch (error, stackTrace) {
      final bool hasTokens = await _tokenStorage.readTokens() != null;
      if (!hasTokens) {
        state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
      } else if (previousSession.isAuthenticated) {
        _sessionCoordinator.activateSession();
        state = AsyncData<AuthSession>(previousSession);
      } else {
        state = AsyncError<AuthSession>(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    _sessionCoordinator.deactivateSession();
    final AuthTokens? tokens = await _tokenStorage.readTokens();
    final String? deviceId = await _tokenStorage.readDeviceId();
    state = const AsyncLoading<AuthSession>();
    await _tokenStorage.clearTokens();
    if (tokens != null && deviceId != null && deviceId.isNotEmpty) {
      await _revokeSession(tokens.refreshToken, deviceId);
    }
    state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
  }

  Future<AuthSession> _restoreSession() async {
    final AuthTokens? tokens = await _tokenStorage.readTokens();
    if (tokens == null) {
      _sessionCoordinator.deactivateSession();
      return const AuthSession.unauthenticated();
    }

    try {
      final UserProfile user = await _repository.getCurrentUser();
      return AuthSession.authenticated(user);
    } on ApiException catch (error) {
      if (error.kind != ApiErrorKind.unauthorized) {
        rethrow;
      }
      _sessionCoordinator.deactivateSession();
      await _tokenStorage.clearTokens();
      return const AuthSession.unauthenticated();
    }
  }

  void _handleSessionExpired() {
    state = const AsyncData<AuthSession>(AuthSession.unauthenticated());
  }

  Future<void> _revokeSession(String refreshToken, String deviceId) async {
    try {
      await _repository.logout(refreshToken: refreshToken, deviceId: deviceId);
    } on Object {
      return;
    }
  }
}

final AsyncNotifierProvider<AuthController, AuthSession>
authControllerProvider = AsyncNotifierProvider<AuthController, AuthSession>(
  AuthController.new,
);
