import 'dart:async';
import 'package:curitalk/features/profile/presentation/profile_screen.dart';

import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/storage/storage.dart';
import 'package:curitalk/core/widgets/app_color_block_card.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:curitalk/features/home/application/weekly_topics_controller.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:curitalk/features/home/presentation/widgets/weekly_topic_loop.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../snack_test_fixtures.dart';
import 'package:curitalk/features/home/data/snack_basket_reset_repository.dart';

void main() {
  testWidgets('home delegates navigation to the shared shell', (tester) async {
    await tester.pumpWidget(
      _homeApp(conversations: _recentConversations(count: 5)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.text('KR -> EN'), findsOneWidget);
    final logo = find.byKey(const ValueKey('home-brand-logo'));
    expect(logo, findsOneWidget);
    expect(find.text('tomatalk'), findsNothing);
    expect(tester.getSize(logo), const Size(164, 40));
    expect(
      (tester.widget<Image>(logo).image as AssetImage).assetName,
      'logo_img/KakaoTalk_Photo_2026-10-08-22-20-21 002.png',
    );
    expect(tester.getTopLeft(logo).dx, AppSpacing.screenPadding - 8);
    expect(
      tester.getTopRight(find.text('KR -> EN')).dx,
      greaterThan(tester.getTopRight(logo).dx),
    );
    expect(find.text('Conversation 3'), findsNothing);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Start a conversation'),
      300,
    );
    expect(
      find.widgetWithText(FilledButton, 'Start a conversation'),
      findsOneWidget,
    );
  });

  testWidgets(
    'full slot keeps the real recent conversation and blocks creation',
    (tester) async {
      await tester.pumpWidget(
        _homeApp(
          conversations: _recentConversations(count: 1),
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
      expect(find.text('Conversation 1'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('locked-additional-conversation-home')),
        findsNothing,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Start a conversation'),
        300,
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Start a conversation'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'All active conversation slots are in use. Release a slot in History or subscribe.',
        ),
        findsWidgets,
      );
      expect(find.text('Free Chat'), findsNothing);
    },
  );

  testWidgets('profile displays account and language settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp(profile: true));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu_rounded), findsNothing);

    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('CANCEL'), findsNothing);
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

  testWidgets('language pair confirmation keeps Profile open', (
    WidgetTester tester,
  ) async {
    final _FakeLanguagePreferencesRepository languageRepository =
        _FakeLanguagePreferencesRepository();
    final _FakeAuthRepository authRepository = _FakeAuthRepository(
      languageProvider: () => languageRepository.currentLanguage,
    );

    await tester.pumpWidget(
      _homeApp(
        profile: true,
        authRepository: authRepository,
        languagePreferencesRepository: languageRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    expect(find.text('Save this change?'), findsOneWidget);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(
      languageRepository.currentLanguage.targetLanguage,
      LearningLanguageCode.ko,
    );
  });

  testWidgets('language pair confirmation failure keeps policy note visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(
        profile: true,
        languagePreferencesRepository: _FakeLanguagePreferencesRepository(
          throwOnUpdate: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(find.text('Language pair could not be saved.'), findsOneWidget);
    expect(
      find.text(
        'Applies to new conversations. Existing conversations keep the language pair they started with.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('canceling a language pair change keeps the current setting', (
    WidgetTester tester,
  ) async {
    final _FakeLanguagePreferencesRepository languageRepository =
        _FakeLanguagePreferencesRepository();
    await tester.pumpWidget(
      _homeApp(
        profile: true,
        languagePreferencesRepository: languageRepository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('English -> Korean'));
    await tester.tap(find.text('English -> Korean'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(
      languageRepository.currentLanguage,
      LearningLanguageContext.defaultContext,
    );
    expect(find.text('ACCOUNT'), findsOneWidget);
  });

  testWidgets('app language saves immediately after confirmation', (
    WidgetTester tester,
  ) async {
    final _FakeAuthRepository authRepository = _FakeAuthRepository();
    await tester.pumpWidget(
      _homeApp(profile: true, authRepository: authRepository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('KOREAN'));
    await tester.pumpAndSettle();

    expect(find.text('Change the app language to Korean?'), findsOneWidget);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(authRepository.appLocale, 'ko');
    expect(find.text('ACCOUNT'), findsOneWidget);
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

    final Finder addButton = find.widgetWithText(
      FilledButton,
      'Start a conversation',
    );
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Free Chat'), findsOneWidget);

    await tester.tap(find.text('Free Chat'));
    await tester.pumpAndSettle();

    expect(selectedType, ConversationStartType.freeChat);
  });

  testWidgets('Home empty state shows a single start conversation CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Start a conversation'),
      findsOneWidget,
    );
    expect(find.text('Start a conversation'), findsOneWidget);
  });

  testWidgets('Today tomatoes title is centered with its existing style', (
    tester,
  ) async {
    await tester.pumpWidget(_homeApp());
    await tester.pumpAndSettle();

    final title = find.text("Today's Tomatoes");
    expect(title, findsOneWidget);
    expect(find.text('View all'), findsNothing);
    expect(find.text('Recent'), findsNothing);
    expect(tester.widget<Text>(title).textAlign, TextAlign.center);
    expect(
      tester.widget<Text>(title).style?.fontSize,
      AppTypography.button.fontSize,
    );
    expect(
      tester.getTopLeft(title).dx,
      AppSpacing.screenPadding + AppSpacing.sm,
    );
  });

  testWidgets('weekly topics remain visible beside recent conversations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(
        conversations: _recentConversations(count: 1),
        weeklyTopics: const WeeklyTopics(
          weekStart: '2026-09-28',
          topics: [WeeklyTopic(id: 'topic-1', text: '오늘의 취미 이야기')],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Conversation 1'), findsOneWidget);
    expect(find.byType(WeeklyTopicLoop), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text("Today's Tomatoes")).dy,
      lessThan(tester.getTopLeft(find.byType(WeeklyTopicLoop)).dy),
    );
    expect(
      tester.getBottomLeft(find.byType(WeeklyTopicLoop)).dy,
      lessThan(tester.getTopLeft(find.text('Conversation 1')).dy),
    );
    expect(find.text('Suggested starting points'), findsNothing);
    expect(
      find.ancestor(
        of: find.byType(WeeklyTopicLoop),
        matching: find.byType(AppColorBlockCard),
      ),
      findsNothing,
    );
    expect(find.text('Start a conversation'), findsOneWidget);
  });

  testWidgets('canceling a suggested topic leaves conversations unchanged', (
    WidgetTester tester,
  ) async {
    final repository = _DeferredSuggestedConversationRepository();
    await tester.pumpWidget(
      _homeApp(
        weeklyTopics: _publishedTopics,
        conversationRepository: repository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.byKey(const ValueKey('weekly-topic-topic-1-1')));
    await tester.pump();
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-topic-1-1')),
          )
          .color,
      AppPalette.topicSelectedSurface,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Start a conversation?'), findsOneWidget);
    expect(find.text('오늘의 취미 이야기'), findsWidgets);
    expect(repository.startCalls, 0);

    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.startCalls, 0);
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-topic-1-1')),
          )
          .color,
      AppPalette.topicSurface,
    );
    expect(
      find.byKey(const ValueKey('suggested-conversation-loading')),
      findsNothing,
    );
  });

  testWidgets('confirmed topic shows loading until the chat is ready', (
    WidgetTester tester,
  ) async {
    final repository = _DeferredSuggestedConversationRepository();
    String? openedConversation;
    await tester.pumpWidget(
      _homeApp(
        weeklyTopics: _publishedTopics,
        conversationRepository: repository,
        onConversationSelected: (id) => openedConversation = id,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.byKey(const ValueKey('weekly-topic-topic-1-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('START CONVERSATION'));
    await tester.pump();

    expect(repository.startCalls, 1);
    expect(
      find.byKey(const ValueKey('suggested-conversation-loading')),
      findsOneWidget,
    );
    expect(find.text('Getting your conversation ready...'), findsOneWidget);
    expect(find.byType(WeeklyTopicLoop), findsNothing);

    repository.completeStart();
    await tester.pump();
    expect(openedConversation, 'suggested-conversation');
    expect(
      find.byKey(const ValueKey('suggested-conversation-loading')),
      findsNothing,
    );
  });

  testWidgets('failed topic start restores choices and shows feedback', (
    WidgetTester tester,
  ) async {
    final repository = _DeferredSuggestedConversationRepository();
    await tester.pumpWidget(
      _homeApp(
        weeklyTopics: _publishedTopics,
        conversationRepository: repository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.byKey(const ValueKey('weekly-topic-topic-1-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('START CONVERSATION'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('suggested-conversation-loading')),
      findsOneWidget,
    );

    repository.failStart();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('suggested-conversation-loading')),
      findsNothing,
    );
    expect(find.byType(WeeklyTopicLoop), findsOneWidget);
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-topic-1-1')),
          )
          .color,
      AppPalette.topicSurface,
    );
    expect(
      find.text('The conversation could not be started. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('language snacks stay above recent conversations', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(
        conversations: _recentConversations(count: 1),
        languageSnackRepository: _FakeLanguageSnackRepository(
          snacks: <LanguageSnack>[_languageSnack],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('snack-tomato-touch')), findsOneWidget);
    expect(find.text('Conversation 1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('snack-tomato-touch'))).dy,
      lessThan(tester.getTopLeft(find.text('Conversation 1')).dy),
    );
  });

  testWidgets('language snacks do not replace the empty start CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(
        languageSnackRepository: _FakeLanguageSnackRepository(
          snacks: <LanguageSnack>[_languageSnack],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('snack-tomato-touch')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Start a conversation'),
      300,
    );
    expect(
      find.widgetWithText(FilledButton, 'Start a conversation'),
      findsOneWidget,
    );
  });

  testWidgets('recent cards stop at two and new conversation follows them', (
    tester,
  ) async {
    await tester.pumpWidget(
      _homeApp(conversations: _recentConversations(count: 6)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Conversation 1'), findsOneWidget);
    expect(find.text('Conversation 2'), findsOneWidget);
    expect(find.text('freechat'), findsNWidgets(2));
    expect(find.text('Conversation 3'), findsNothing);
    expect(find.textContaining('messages'), findsNothing);
    expect(find.text('Continue speaking'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(
      tester
          .getTopLeft(find.widgetWithText(FilledButton, 'Start a conversation'))
          .dy,
      greaterThan(tester.getBottomLeft(find.text('Conversation 2')).dy),
    );
  });

  testWidgets('Recent conversations show updating indicator while refreshing', (
    WidgetTester tester,
  ) async {
    final _RefreshableHomeRepository homeRepository =
        _RefreshableHomeRepository();

    await tester.pumpWidget(_homeApp(homeRepository: homeRepository));
    await tester.pumpAndSettle();

    expect(find.text('Conversation 1'), findsOneWidget);
    expect(_refreshIndicator, findsNothing);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
      listen: false,
    );
    container
        .read(recentConversationsRefreshingProvider.notifier)
        .setRefreshing(true);
    container.invalidate(recentConversationsControllerProvider);
    await tester.pump();
    await tester.pump();

    expect(find.text('Conversation 1'), findsOneWidget);
    expect(_refreshIndicator, findsOneWidget);

    homeRepository.completeRefresh();
    await tester.pumpAndSettle();

    expect(find.text('Updated conversation'), findsOneWidget);
    expect(_refreshIndicator, findsNothing);
  });

  testWidgets(
    'shows loading immediately after confirming conversation deletion',
    (WidgetTester tester) async {
      final _DeferredDeletionConversationRepository conversationRepository =
          _DeferredDeletionConversationRepository();
      await tester.pumpWidget(
        _homeApp(
          homeRepository: _DeletionHomeRepository(),
          conversationRepository: conversationRepository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('Conversation 1'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pump();

      expect(conversationRepository.deleteStarted, isTrue);
      expect(find.text('Loading recent conversations...'), findsOneWidget);
      expect(find.text('Conversation 1'), findsNothing);

      conversationRepository.completeDeletion();
      await tester.pumpAndSettle();

      expect(find.text('Start a conversation'), findsOneWidget);
    },
  );

  testWidgets('profile logout clears session', (WidgetTester tester) async {
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
        profile: true,
        tokenStorage: tokenStorage,
        authRepository: authRepository,
        googleIdentityService: googleIdentityService,
        supabaseAuth: supabaseAuth,
      ),
    );
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
        profile: true,
        tokenStorage: tokenStorage,
        supabaseAuth: supabaseAuth,
        googleIdentityService: _FakeGoogleIdentityService(throwOnSignOut: true),
      ),
    );
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
const WeeklyTopics _publishedTopics = WeeklyTopics(
  weekStart: '2026-09-28',
  topics: [WeeklyTopic(id: 'topic-1', text: '오늘의 취미 이야기')],
);
final Finder _refreshIndicator = find.byKey(
  const ValueKey<String>('recent-conversations-refresh-indicator'),
);

Widget _homeApp({
  bool profile = false,
  _MemoryTokenStorage? tokenStorage,
  _FakeAuthRepository? authRepository,
  _FakeLanguagePreferencesRepository? languagePreferencesRepository,
  _FakeGoogleIdentityService? googleIdentityService,
  _FakeSupabaseAuthService? supabaseAuth,
  ValueChanged<ConversationStartType>? onStartTypeSelected,
  ValueChanged<String>? onConversationSelected,
  List<ConversationSummary> conversations = const <ConversationSummary>[],
  HomeRepository? homeRepository,
  LanguageSnackRepository? languageSnackRepository,
  LanguageSnackCache? languageSnackCache,
  ConversationRepository? conversationRepository,
  ConversationAccess access = const ConversationAccess.disabled(),
  WeeklyTopics weeklyTopics = const WeeklyTopics(weekStart: null, topics: []),
}) {
  final _MemoryTokenStorage effectiveTokenStorage =
      tokenStorage ?? _MemoryTokenStorage(tokens: _tokens, deviceId: _deviceId);
  return ProviderScope(
    overrides: [
      snackBasketResetRepositoryProvider.overrideWithValue(
        MemoryBasketResetRepository(),
      ),
      secureStorageBackendProvider.overrideWithValue(MemorySnackStorage()),
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
      homeRepositoryProvider.overrideWithValue(
        homeRepository ?? _FakeHomeRepository(conversations: conversations),
      ),
      languageSnackRepositoryProvider.overrideWithValue(
        languageSnackRepository ?? _FakeLanguageSnackRepository(),
      ),
      languageSnackCacheProvider.overrideWithValue(
        languageSnackCache ?? _FakeLanguageSnackCache(),
      ),
      if (conversationRepository != null)
        conversationRepositoryProvider.overrideWithValue(
          conversationRepository,
        ),
      conversationAccessRepositoryProvider.overrideWithValue(
        _FakeConversationAccessRepository(access),
      ),
      conversationAccessProvider.overrideWith((ref) async => access),
      weeklyTopicsControllerProvider.overrideWith(
        () => _FixedWeeklyTopicsController(weeklyTopics),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      home: profile
          ? const ProfileScreen()
          : HomeScreen(
              onConversationSelected: onConversationSelected,
              onStartTypeSelected: onStartTypeSelected,
            ),
    ),
  );
}

class _FixedWeeklyTopicsController extends WeeklyTopicsController {
  _FixedWeeklyTopicsController(this.topics);

  final WeeklyTopics topics;

  @override
  Future<WeeklyTopics> build() async => topics;

  @override
  void refreshIfNewWeek() {}
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

  @override
  Future<void> activate(
    String conversationId, {
    String? replaceConversationId,
  }) async {}

  @override
  Future<void> deactivate(String conversationId) async {}
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

class _FakeAuthRepository implements AuthRepository, AppLocaleRepository {
  _FakeAuthRepository({this.languageProvider});

  final LearningLanguageContext Function()? languageProvider;
  String? appLocale;

  @override
  Future<UserProfile> getCurrentUser() async {
    return _userWithLanguage(
      languageProvider?.call() ?? LearningLanguageContext.defaultContext,
    ).copyWith(appLocale: appLocale);
  }

  @override
  Future<UserProfile> updateAppLocale(String value) async {
    appLocale = value;
    return getCurrentUser();
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
  Future<void> signInWithAppleToken({
    required String idToken,
    required String rawNonce,
  }) async {
    hasSession = true;
  }

  @override
  Future<void> signOut() async {
    hasSession = false;
  }
}

class _FakeHomeRepository implements HomeRepository {
  const _FakeHomeRepository({
    this.conversations = const <ConversationSummary>[],
  });

  final List<ConversationSummary> conversations;

  @override
  Future<List<ConversationSummary>> listRecentConversations({
    int limit = 5,
  }) async {
    return conversations;
  }
}

class _FakeLanguageSnackRepository implements LanguageSnackRepository {
  const _FakeLanguageSnackRepository({this.snacks = const <LanguageSnack>[]});

  final List<LanguageSnack> snacks;

  @override
  Future<List<LanguageSnack>> listPublished() async => snacks;
}

class _FakeLanguageSnackCache implements LanguageSnackCache {
  const _FakeLanguageSnackCache();

  @override
  Future<List<LanguageSnack>?> read() async => null;

  @override
  Future<void> write(List<LanguageSnack> snacks) async {}
}

class _RefreshableHomeRepository implements HomeRepository {
  Completer<List<ConversationSummary>>? _refreshCompleter;
  int _callCount = 0;

  @override
  Future<List<ConversationSummary>> listRecentConversations({int limit = 5}) {
    _callCount += 1;
    if (_callCount == 1) {
      return Future<List<ConversationSummary>>.value(
        _recentConversations(count: 1),
      );
    }

    _refreshCompleter ??= Completer<List<ConversationSummary>>();
    return _refreshCompleter!.future;
  }

  void completeRefresh() {
    _refreshCompleter?.complete(<ConversationSummary>[
      ConversationSummary(
        id: 'updated-conversation',
        title: 'Updated conversation',
        kind: ConversationKind.roleplay,
        messageCount: 1,
        isActive: true,
        updatedAt: DateTime.utc(2026, 8, 14),
      ),
    ]);
  }
}

class _DeletionHomeRepository implements HomeRepository {
  int _callCount = 0;

  @override
  Future<List<ConversationSummary>> listRecentConversations({
    int limit = 5,
  }) async {
    _callCount += 1;
    return _callCount == 1
        ? _recentConversations(count: 1)
        : const <ConversationSummary>[];
  }
}

class _DeferredDeletionConversationRepository
    implements ConversationRepository, ConversationDeletionRepository {
  final Completer<void> _deleteCompleter = Completer<void>();
  bool deleteStarted = false;

  @override
  Future<void> deleteConversation(String conversationId) {
    deleteStarted = true;
    return _deleteCompleter.future;
  }

  void completeDeletion() {
    _deleteCompleter.complete();
  }

  @override
  Future<PaginatedMessages> listMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) => throw UnimplementedError();

  @override
  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) => throw UnimplementedError();

  @override
  Future<MultimodalMessageResponse> sendAudioTurn({
    required String conversationId,
    required ConversationAudioFile audioFile,
    bool includeAudioResponse = true,
  }) => throw UnimplementedError();

  @override
  Future<MultimodalMessageResponse> sendTextTurn({
    required String conversationId,
    required String text,
    bool includeAudioResponse = true,
  }) => throw UnimplementedError();

  @override
  Future<MultimodalConversationResponse> startFreeChat({
    required String firstMessage,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) => throw UnimplementedError();

  @override
  Future<MultimodalConversationResponse> startFreeChatWithAudio({
    required ConversationAudioFile audioFile,
    String? searchContext,
    String? topic,
    String? conversationDirection,
    String? selectedQuestion,
    bool includeAudioResponse = true,
  }) => throw UnimplementedError();

  @override
  Future<MultimodalConversationResponse> startRoleplay({
    required String roleCharacter,
    String? searchContext,
    bool includeAudioResponse = true,
  }) => throw UnimplementedError();
}

class _DeferredSuggestedConversationRepository
    extends _DeferredDeletionConversationRepository
    implements SuggestedConversationRepository {
  final Completer<SuggestedConversationResponse> _startCompleter =
      Completer<SuggestedConversationResponse>();
  int startCalls = 0;

  @override
  Future<SuggestedConversationResponse> startSuggestedFreeChat({
    required String topicId,
    required String startRequestId,
    bool includeAudioResponse = true,
  }) {
    startCalls += 1;
    return _startCompleter.future;
  }

  void completeStart() {
    _startCompleter.complete(
      const SuggestedConversationResponse(
        conversationId: 'suggested-conversation',
        assistantMessageId: 'assistant-message',
        response: 'What do you enjoy?',
      ),
    );
  }

  void failStart() {
    _startCompleter.completeError(StateError('start failed'));
  }
}

List<ConversationSummary> _recentConversations({required int count}) {
  return List<ConversationSummary>.generate(count, (int index) {
    final int number = index + 1;
    return ConversationSummary(
      id: 'conversation-$number',
      title: 'Conversation $number',
      kind: ConversationKind.freeChat,
      messageCount: number,
      isActive: true,
      updatedAt: DateTime.utc(2026, 8, number),
    );
  });
}

final LanguageSnack _languageSnack = LanguageSnack.fromJson(<String, dynamic>{
  'id': '550e8400-e29b-41d4-a716-446655440000',
  'content_type': 'regional_variant',
  'schema_version': 1,
  'content_language': 'en',
  'explanation_language': 'ko',
  'payload': {
    'meaning': '둘 다 감자칩을 뜻해요.',
    'items': [
      {'label': 'British English', 'expression': 'crisps'},
      {'label': 'American English', 'expression': 'chips'},
    ],
  },
  'published_at': '2026-09-06T12:00:00Z',
  'created_at': '2026-09-06T12:00:00Z',
  'updated_at': '2026-09-06T12:00:00Z',
});

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
