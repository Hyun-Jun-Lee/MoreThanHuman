import 'package:curitalk/app/navigation/main_shell.dart';
import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('tabs retain scroll position and reselection scrolls to top', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    final controller = MainTabScope.maybeOf(
      tester.element(find.byType(ListView)),
    )!.controllers[0];
    final offset = controller.offset;
    expect(offset, greaterThan(0));
    await tester.tap(find.text('Conversations'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(controller.offset, offset);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
  });

  for (final origin in [AppRoute.home, AppRoute.history]) {
    for (final preparation in [AppRoute.topicInput, AppRoute.roleplaySetup]) {
      testWidgets(
        '$origin returns from $preparation without completed preparation',
        (tester) async {
          final router = _router(initialLocation: origin);
          addTearDown(router.dispose);
          await tester.pumpWidget(
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          );
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
}

GoRouter _router({String initialLocation = AppRoute.home}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => MainShell(navigationShell: shell),
      branches: [
        for (final (index, path) in [
          AppRoute.home,
          AppRoute.history,
          AppRoute.profile,
        ].indexed)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: path,
                builder: (context, _) => ListView.builder(
                  controller: MainTabScope.maybeOf(context)!.controllers[index],
                  itemCount: 40,
                  itemExtent: 60,
                  itemBuilder: (_, item) => Text('$path $item'),
                ),
              ),
            ],
          ),
      ],
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
