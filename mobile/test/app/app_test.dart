import 'package:curitalk/app/app.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
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

      await tester.pumpWidget(
        _appScope(
          tokenStorage: tokenStorage,
          onboardingStorage: onboardingStorage,
          authRepository: authRepository,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Talk about what\nyou actually care about.'),
        findsOneWidget,
      );

      await tester.tap(find.text('SKIP'));
      await tester.pumpAndSettle();

      expect(
        find.text('Practice English with your own topics.'),
        findsOneWidget,
      );

      await tester.tap(find.text('CONTINUE WITH GOOGLE'));
      await tester.pumpAndSettle();

      expect(find.text('Hi, Learner'), findsOneWidget);
      expect(find.text('Welcome to Curitalk'), findsOneWidget);
      expect(onboardingStorage.completed, isTrue);
      expect(tokenStorage.tokens?.accessToken, 'access-token');
      expect(authRepository.lastIdToken, 'google-id-token');
    },
  );

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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hi, Learner'), findsOneWidget);
    expect(find.text('Practice English with your own topics.'), findsNothing);
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
      homeRepositoryProvider.overrideWithValue(const _FakeHomeRepository()),
    ],
    child: const CuritalkApp(),
  );
}

class _FakeGoogleIdentityService implements GoogleIdentityService {
  const _FakeGoogleIdentityService();

  @override
  Future<String?> signIn() async => 'google-id-token';

  @override
  Future<void> signOut() async {}
}

class _FakeAuthRepository implements AuthRepository {
  String? lastIdToken;

  @override
  Future<UserProfile> getCurrentUser() async => _user;

  @override
  Future<void> logout({
    required String refreshToken,
    required String deviceId,
  }) async {}

  @override
  Future<AuthTokens> signInWithGoogleIdToken({
    required String idToken,
    required String deviceId,
  }) async {
    lastIdToken = idToken;
    return _tokens;
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

class _MemoryOnboardingStorage implements OnboardingStorage {
  _MemoryOnboardingStorage(this.completed);

  bool completed;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async {
    completed = true;
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
