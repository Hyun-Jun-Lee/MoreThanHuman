import 'package:curitalk/core/notifications/badge_choice_dialog.dart';
import 'package:curitalk/core/notifications/badge_sync_controller.dart';
import 'package:curitalk/core/notifications/ios_badge_bridge.dart';
import 'package:curitalk/core/storage/storage_providers.dart';
import 'package:curitalk/core/storage/token_storage.dart';
import 'package:curitalk/features/profile/presentation/nickname_dialog.dart';
import 'package:curitalk/app/navigation/main_shell.dart';
import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'badge choice follows notice and required nickname, then profile can enable it',
    (tester) async {
      final fixture = _BadgeFixture(nickname: null);
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      expect(find.text('Consent for AI conversations'), findsOneWidget);
      expect(find.text('Use badge'), findsNothing);
      expect(fixture.bridge.requests, 0);
      await tester.tap(find.text('Decide later'));
      await tester.pumpAndSettle();
      expect(find.byType(NicknameDialog), findsOneWidget);
      expect(find.text('Use badge'), findsNothing);
      expect(fixture.bridge.requests, 0);
      await tester.enterText(
        find.byKey(const ValueKey('nickname-input')),
        'Tomato',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NicknameDialog),
          matching: find.byType(FilledButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Use badge'), findsOneWidget);
      expect(fixture.bridge.requests, 0);
      await tester.tap(find.text('Not now / turn off'));
      await tester.pumpAndSettle();
      expect(fixture.storage.values['badge.choice.member'], 'disabled');
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unread notifications'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.bridge.requests, 1);
      expect(fixture.storage.values['badge.choice.member'], 'enabled');
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Use badge'), findsNothing);
    },
  );

  testWidgets('guest has no badge choice or settings', (tester) async {
    final fixture = _BadgeFixture(guest: true, accepted: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    expect(find.text('Use badge'), findsNothing);
    fixture.router.go(AppRoute.profile);
    await tester.pumpAndSettle();
    expect(find.text('Unread notifications'), findsNothing);
    expect(fixture.bridge.requests, 0);
  });

  testWidgets('failed notice initialization never offers badge permission', (
    tester,
  ) async {
    final fixture = _BadgeFixture(failNotice: true);
    addTearDown(fixture.dispose);
    await tester.pumpWidget(fixture.app);
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Use badge'), findsNothing);
    expect(fixture.bridge.requests, 0);
  });

  testWidgets(
    'denied badge permission opens settings without requesting again',
    (tester) async {
      final fixture = _BadgeFixture(accepted: true);
      fixture.bridge.status = BadgePermission.denied;
      addTearDown(fixture.dispose);
      await tester.pumpWidget(fixture.app);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use badge'));
      await tester.pumpAndSettle();
      expect(fixture.bridge.requests, 0);
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      expect(fixture.bridge.settingsOpened, 1);
    },
  );

  testWidgets('tabs retain scroll position and reselection scrolls to top', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_testApp(router));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final controller = MainTabScope.maybeOf(
      tester.element(find.byType(ListView)),
    )!.controllers[0];
    final offset = controller.offset;
    expect(offset, greaterThan(0));
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(controller.offset, offset);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  for (final origin in [AppRoute.home, AppRoute.profile]) {
    for (final preparation in [AppRoute.topicInput, AppRoute.roleplaySetup]) {
      testWidgets(
        '$origin returns from $preparation without completed preparation',
        (tester) async {
          final router = _router(initialLocation: origin);
          addTearDown(router.dispose);
          await tester.pumpWidget(_testApp(router));
          await tester.pumpAndSettle();
          router.push(preparation);
          await tester.pumpAndSettle();
          expect(find.byType(NavigationBar), findsNothing);
          expect(
            tester
                .widget<MainTabScope>(
                  find.byType(MainTabScope, skipOffstage: false),
                )
                .index,
            -1,
          );
          if (preparation == AppRoute.topicInput) {
            router.push(AppRoute.topicPrep);
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Finish preparation'));
          await tester.pumpAndSettle();
          expect(find.text('Conversation'), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);
          expect(
            tester
                .widget<MainTabScope>(
                  find.byType(MainTabScope, skipOffstage: false),
                )
                .index,
            -1,
          );
          router.pop();
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, origin);
          expect(find.text('Finish preparation'), findsNothing);
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(router.canPop(), isFalse);
        },
      );
    }
  }

  testWidgets('history opens above home and conversation returns to history', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_testApp(router));
    await tester.pumpAndSettle();
    router.push(AppRoute.history);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    router.push(AppRoute.topicInput);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish preparation'));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoute.home);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}

GoRouter _router({String initialLocation = AppRoute.home}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(navigationShell: shell),
      branches: [
        for (final (index, path) in [AppRoute.home, AppRoute.profile].indexed)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: path,
                builder: (context, _) => ListView.builder(
                  controller: MainTabScope.maybeOf(context)!.controllers[index],
                  itemCount: 40,
                  itemExtent: 60,
                  itemBuilder: (_, item) => index == 1 && item == 0
                      ? const BadgeSettingsButton()
                      : Text('$path $item'),
                ),
              ),
            ],
          ),
      ],
    ),
    GoRoute(
      path: AppRoute.history,
      builder: (_, _) => const Scaffold(body: Text('History')),
    ),
    for (final path in [
      AppRoute.topicInput,
      AppRoute.topicPrep,
      AppRoute.roleplaySetup,
    ])
      GoRoute(
        path: path,
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => openStartedConversation(context, 'created'),
            child: const Text('Finish preparation'),
          ),
        ),
      ),
    GoRoute(
      path: '${AppRoute.conversation}/:id',
      builder: (_, _) => const Scaffold(body: Text('Conversation')),
    ),
  ],
);

Widget _testApp(GoRouter router) => ProviderScope(
  overrides: [authControllerProvider.overrideWith(_ShellAuthController.new)],
  child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
);

class _ShellAuthController extends AuthController {
  @override
  Future<AuthSession> build() async => const AuthSession.unauthenticated();
}

class _BadgeFixture {
  _BadgeFixture({
    String? nickname = 'Tomato',
    bool guest = false,
    bool accepted = false,
    bool failNotice = false,
  }) {
    final user = UserProfile(
      id: 'member',
      email: 'test@example.com',
      name: 'Test',
      nickname: nickname,
      isGuest: guest,
      isActive: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _BadgeAuthController(AuthSession.fromProfile(user)),
        ),
        aiConsentControllerProvider.overrideWith(
          () => _BadgeConsentController(accepted, failNotice),
        ),
        iosBadgeBridgeProvider.overrideWithValue(bridge),
        secureStorageBackendProvider.overrideWithValue(storage),
      ],
    );
    container.read(badgeSyncControllerProvider);
  }
  final router = _router();
  final bridge = _BadgeBridge();
  final storage = _BadgeStorage();
  late final ProviderContainer container;
  Widget get app => UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
  void dispose() {
    router.dispose();
    container.dispose();
  }
}

class _BadgeAuthController extends AuthController {
  _BadgeAuthController(this.session);
  final AuthSession session;
  @override
  Future<AuthSession> build() async => session;
  @override
  Future<void> updateNickname(String nickname) async {
    state = AsyncData(
      AuthSession.member(state.requireValue.user!.copyWith(nickname: nickname)),
    );
  }
}

class _BadgeConsentController extends AIConsentController {
  _BadgeConsentController(this.accepted, this.fail);
  final bool accepted;
  final bool fail;
  AIConsentStatus get status => AIConsentStatus(
    accepted: accepted,
    noticeAcknowledged: accepted,
    requiredVersions: const {},
    acceptedVersions: const {},
    missing: const [],
    privacyPolicyUrl: '',
    privacyPolicyUrlEn: '',
  );
  @override
  Future<AIConsentStatus> load() async {
    if (fail) throw StateError('offline');
    return status;
  }

  @override
  Future<AIConsentStatus> recordChoice(
    AIConsentStatus notice, {
    required bool acceptAI,
  }) async => status;
}

class _BadgeBridge extends IOSBadgeBridge {
  BadgePermission status = BadgePermission.notDetermined;
  int requests = 0;
  int settingsOpened = 0;
  @override
  Future<BadgePermission> permission({bool request = false}) async {
    if (request) requests++;
    return status;
  }

  @override
  Future<void> setCount(int count) async {}
  @override
  Future<void> openSettings() async {
    settingsOpened++;
  }
}

class _BadgeStorage implements SecureStorageBackend {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
