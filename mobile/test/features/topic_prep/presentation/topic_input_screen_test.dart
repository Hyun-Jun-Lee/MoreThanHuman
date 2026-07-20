import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('validates topics shorter than two characters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_routerApp());

    await tester.enterText(find.bySemanticsLabel('Conversation topic'), 'A');
    await tester.tap(find.text('PREPARE'));
    await tester.pumpAndSettle();

    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
    expect(find.text('Prepared'), findsNothing);
  });

  testWidgets('example chips fill the input and valid topics navigate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_routerApp());

    await tester.tap(find.text('오사카 여행 맛집'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '오사카 여행 맛집',
    );

    await tester.tap(find.text('PREPARE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Prepared'), findsOneWidget);
    expect(find.textContaining('오사카 여행 맛집'), findsOneWidget);
  });
}

Widget _routerApp() {
  final GoRouter router = GoRouter(
    initialLocation: AppRoute.topicInput,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.topicInput,
        builder: (_, _) => const TopicInputScreen(),
      ),
      GoRoute(
        path: AppRoute.topicPrep,
        builder: (_, GoRouterState state) {
          return Scaffold(
            body: Text('Prepared ${state.uri.queryParameters['topic']}'),
          );
        },
      ),
    ],
  );
  return MaterialApp.router(theme: AppTheme.light, routerConfig: router);
}
