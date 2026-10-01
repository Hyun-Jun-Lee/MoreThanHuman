import 'dart:async';
import 'package:curitalk/features/history/data/conversation_history_repository.dart';
import 'package:curitalk/features/conversation/conversation.dart';

import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/history/history.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows loading state while history is loading', (
    WidgetTester tester,
  ) async {
    final _FakeHomeRepository repository = _FakeHomeRepository(pending: true);

    await tester.pumpWidget(_historyApp(homeRepository: repository));

    expect(find.text('Loading conversation history...'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no conversations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_historyApp());
    await tester.pumpAndSettle();

    expect(find.text('No conversations yet.'), findsOneWidget);
  });

  testWidgets('shows conversation list and reports selected conversation', (
    WidgetTester tester,
  ) async {
    String? selectedConversationId;

    await tester.pumpWidget(
      _historyApp(
        conversations: <ConversationSummary>[_conversation],
        onConversationSelected: (String conversationId) {
          selectedConversationId = conversationId;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Osaka food trip'), findsOneWidget);
    expect(find.text('FREE CHAT'), findsNothing);

    await tester.tap(find.text('Osaka food trip'));

    expect(selectedConversationId, 'conversation-id');
  });

  testWidgets('shows retry state and reloads failed history', (
    WidgetTester tester,
  ) async {
    final _FakeHomeRepository repository = _FakeHomeRepository(
      errorOnce: true,
      conversations: <ConversationSummary>[_conversation],
    );

    await tester.pumpWidget(_historyApp(homeRepository: repository));
    await tester.pumpAndSettle();

    expect(
      find.text('Conversation history could not be loaded.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.requestCount, 2);
    expect(find.text('Osaka food trip'), findsOneWidget);
  });

  testWidgets('header plus opens the shared start sheet', (tester) async {
    ConversationStartType? selectedType;
    await tester.pumpWidget(
      _historyApp(onStartTypeSelected: (type) => selectedType = type),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byTooltip('New conversation'));
    await tester.pumpAndSettle();
    expect(find.text('Free Chat'), findsOneWidget);
    await tester.tap(find.text('Roleplay'));
    await tester.pumpAndSettle();
    expect(selectedType, ConversationStartType.roleplay);
  });

  testWidgets('locked extra slot appears as a row and blocks the plus action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _historyApp(
        conversations: <ConversationSummary>[_conversation],
        access: const ConversationAccess(
          enabled: true,
          canCreate: false,
          usedSlots: 1,
          slotLimit: 1,
          remainingSlots: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Osaka food trip'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('locked-additional-conversation')),
      findsOneWidget,
    );
    final lockedRow = find.byKey(
      const ValueKey('locked-additional-conversation'),
    );
    final lockIcon = find.descendant(
      of: lockedRow,
      matching: find.byIcon(Icons.lock_rounded),
    );
    expect(lockIcon, findsOneWidget);
    final badge = find.descendant(
      of: lockedRow,
      matching: find.byType(LockedConversationBadge),
    );
    expect(tester.getSize(badge), const Size(40, 40));
    expect(find.text('Additional conversation'), findsNothing);
    expect(
      find.text('An additional conversation requires a pass.'),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Locked additional conversation, pass required'),
      findsOneWidget,
    );
    expect(
      (tester.getCenter(lockedRow) - tester.getCenter(lockIcon)).distance,
      lessThan(1),
    );
    await tester.tap(find.byTooltip('New conversation'));
    await tester.pumpAndSettle();
    expect(
      find.text('An additional conversation requires a pass.'),
      findsWidgets,
    );
    expect(find.text('Free Chat'), findsNothing);
    semantics.dispose();
  });

  testWidgets('locked slot follows the final real conversation page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _historyApp(
        homeRepository: _FakeHomeRepository(
          conversations: <ConversationSummary>[_conversation],
          hasMore: true,
        ),
        access: const ConversationAccess(
          enabled: true,
          canCreate: false,
          usedSlots: 1,
          slotLimit: 1,
          remainingSlots: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Osaka food trip'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('locked-additional-conversation')),
      findsNothing,
    );
    await tester.tap(find.text('Load more conversations'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('locked-additional-conversation')),
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
final ConversationSummary _conversation = ConversationSummary(
  id: 'conversation-id',
  title: 'Osaka food trip',
  kind: ConversationKind.freeChat,
  messageCount: 4,
  isActive: true,
  updatedAt: DateTime.utc(2026, 7, 12),
);

Widget _historyApp({
  _FakeHomeRepository? homeRepository,
  List<ConversationSummary> conversations = const <ConversationSummary>[],
  ValueChanged<ConversationStartType>? onStartTypeSelected,
  ValueChanged<String>? onConversationSelected,
  ConversationAccess access = const ConversationAccess.disabled(),
}) {
  return ProviderScope(
    overrides: [
      tokenStorageProvider.overrideWithValue(
        _MemoryTokenStorage(tokens: _tokens, deviceId: _deviceId),
      ),
      authRepositoryProvider.overrideWithValue(const _FakeAuthRepository()),
      languagePreferencesRepositoryProvider.overrideWithValue(
        const _FakeLanguagePreferencesRepository(),
      ),
      onboardingStorageProvider.overrideWithValue(
        const _FakeOnboardingStorage(),
      ),
      googleIdentityServiceProvider.overrideWithValue(
        const _FakeGoogleIdentityService(),
      ),
      supabaseAuthServiceProvider.overrideWithValue(
        _FakeSupabaseAuthService(hasSession: true),
      ),
      conversationHistoryRepositoryProvider.overrideWithValue(
        homeRepository ?? _FakeHomeRepository(conversations: conversations),
      ),
      conversationAccessRepositoryProvider.overrideWithValue(
        _FakeConversationAccessRepository(access),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      home: HistoryScreen(
        onStartTypeSelected: onStartTypeSelected,
        onConversationSelected: onConversationSelected,
      ),
    ),
  );
}

class _FakeConversationAccessRepository
    implements ConversationAccessRepository {
  const _FakeConversationAccessRepository(this.access);

  final ConversationAccess access;

  @override
  Future<ConversationAccess> getAccess() async => access;

  @override
  Future<ConversationTurnAccess> getTurnAccess(String conversationId) async =>
      const ConversationTurnAccess.disabled();
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
  const _FakeAuthRepository();

  @override
  Future<UserProfile> getCurrentUser() async => _user;
}

class _FakeLanguagePreferencesRepository
    implements LanguagePreferencesRepository {
  const _FakeLanguagePreferencesRepository();

  @override
  Future<LearningLanguageContext> getLanguagePreferences() async =>
      LearningLanguageContext.defaultContext;

  @override
  Future<LearningLanguageContext> updateLanguagePreferences(
    LearningLanguageContext context,
  ) async => context;
}

class _FakeOnboardingStorage implements OnboardingStorage {
  const _FakeOnboardingStorage();

  @override
  Future<void> clearPendingLanguageContext() async {}

  @override
  Future<bool> isCompleted() async => true;

  @override
  Future<void> markCompleted() async {}

  @override
  Future<LearningLanguageContext?> readPendingLanguageContext() async => null;

  @override
  Future<void> writePendingLanguageContext(
    LearningLanguageContext context,
  ) async {}
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

class _FakeHomeRepository implements ConversationHistoryRepository {
  _FakeHomeRepository({
    this.conversations = const <ConversationSummary>[],
    this.errorOnce = false,
    this.pending = false,
    this.hasMore = false,
  });

  final List<ConversationSummary> conversations;
  final bool errorOnce;
  final bool pending;
  final bool hasMore;
  int requestCount = 0;

  @override
  Future<ConversationPage> list({int offset = 0, int limit = 20}) async {
    requestCount += 1;
    if (pending) return Completer<ConversationPage>().future;
    if (errorOnce && requestCount == 1) throw StateError('offline');
    return ConversationPage(
      items: offset == 0 ? conversations : const <ConversationSummary>[],
      nextOffset: conversations.length,
      hasMore: hasMore && offset == 0,
    );
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
