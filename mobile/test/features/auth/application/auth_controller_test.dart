import 'package:curitalk/core/network/network.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts unauthenticated when no token pair is stored', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage();
    final _FakeAuthRepository repository = _FakeAuthRepository();
    final ProviderContainer container = _createContainer(storage, repository);
    addTearDown(container.dispose);

    final AuthSession session = await container.read(
      authControllerProvider.future,
    );

    expect(session.status, AuthStatus.unauthenticated);
    expect(repository.profileRequestCount, 0);
  });

  test('restores an authenticated session from stored tokens', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage(
      tokens: _tokens,
      deviceId: _deviceId,
    );
    final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
    final ProviderContainer container = _createContainer(storage, repository);
    addTearDown(container.dispose);

    final AuthSession session = await container.read(
      authControllerProvider.future,
    );

    expect(session.isAuthenticated, isTrue);
    expect(session.user?.email, 'learner@example.com');
    expect(repository.profileRequestCount, 1);
  });

  test('Google id token login stores tokens and publishes the user', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage();
    final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
    final ProviderContainer container = _createContainer(storage, repository);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .signInWithGoogleIdToken(' google-id-token ');

    final AuthSession session = container
        .read(authControllerProvider)
        .requireValue;
    expect(session.isAuthenticated, isTrue);
    expect(storage.tokens?.accessToken, 'access-token');
    expect(storage.deviceId, _deviceId);
    expect(repository.lastIdToken, 'google-id-token');
    expect(repository.lastDeviceId, _deviceId);
  });

  test(
    'session expiration immediately publishes unauthenticated state',
    () async {
      final _MemoryTokenStorage storage = _MemoryTokenStorage(
        tokens: _tokens,
        deviceId: _deviceId,
      );
      final _FakeAuthRepository repository = _FakeAuthRepository(user: _user);
      final AuthSessionCoordinator sessionCoordinator =
          AuthSessionCoordinator();
      final ProviderContainer container = _createContainer(
        storage,
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
    'network failure during restore keeps tokens for a later retry',
    () async {
      final _MemoryTokenStorage storage = _MemoryTokenStorage(
        tokens: _tokens,
        deviceId: _deviceId,
      );
      final _FakeAuthRepository repository = _FakeAuthRepository(
        profileError: const ApiException(
          kind: ApiErrorKind.network,
          message: 'offline',
        ),
      );
      final ProviderContainer container = _createContainer(storage, repository);
      addTearDown(container.dispose);

      await expectLater(
        container.read(authControllerProvider.future),
        throwsA(isA<ApiException>()),
      );

      expect(storage.tokens, same(_tokens));
    },
  );

  test('unauthorized restore clears tokens and signs out', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage(
      tokens: _tokens,
      deviceId: _deviceId,
    );
    final _FakeAuthRepository repository = _FakeAuthRepository(
      profileError: const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'expired',
        statusCode: 401,
      ),
    );
    final ProviderContainer container = _createContainer(storage, repository);
    addTearDown(container.dispose);

    final AuthSession session = await container.read(
      authControllerProvider.future,
    );

    expect(session.status, AuthStatus.unauthenticated);
    expect(storage.tokens, isNull);
  });

  test('logout clears local tokens even when server revoke fails', () async {
    final _MemoryTokenStorage storage = _MemoryTokenStorage(
      tokens: _tokens,
      deviceId: _deviceId,
    );
    final _FakeAuthRepository repository = _FakeAuthRepository(
      user: _user,
      logoutError: StateError('offline'),
    );
    final ProviderContainer container = _createContainer(storage, repository);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    await container.read(authControllerProvider.notifier).logout();

    expect(storage.tokens, isNull);
    expect(storage.deviceId, _deviceId);
    expect(
      container.read(authControllerProvider).requireValue.status,
      AuthStatus.unauthenticated,
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
  name: 'Learner',
  isActive: true,
  oauthProvider: 'google',
  createdAt: DateTime.utc(2026, 6, 23),
  updatedAt: DateTime.utc(2026, 6, 23),
);

ProviderContainer _createContainer(
  _MemoryTokenStorage storage,
  _FakeAuthRepository repository, {
  AuthSessionCoordinator? sessionCoordinator,
}) {
  final AuthSessionCoordinator coordinator =
      sessionCoordinator ?? AuthSessionCoordinator();
  return ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      installationIdServiceProvider.overrideWithValue(
        InstallationIdService(storage, generateId: () => _deviceId),
      ),
      authSessionCoordinatorProvider.overrideWithValue(coordinator),
      authRepositoryProvider.overrideWithValue(repository),
    ],
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.user, this.profileError, this.logoutError});

  final UserProfile? user;
  final Object? profileError;
  final Object? logoutError;
  int profileRequestCount = 0;
  String? lastIdToken;
  String? lastDeviceId;

  @override
  Future<UserProfile> getCurrentUser() async {
    profileRequestCount += 1;
    if (profileError case final Object error) {
      throw error;
    }
    return user ?? _user;
  }

  @override
  Future<void> logout({
    required String refreshToken,
    required String deviceId,
  }) async {
    if (logoutError case final Object error) {
      throw error;
    }
  }

  @override
  Future<AuthTokens> signInWithGoogleIdToken({
    required String idToken,
    required String deviceId,
  }) async {
    lastIdToken = idToken;
    lastDeviceId = deviceId;
    return _tokens;
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
