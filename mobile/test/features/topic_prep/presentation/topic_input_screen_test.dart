import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/language/language.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    await tester.tap(find.text('Osaka food trip'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Osaka food trip',
    );

    await tester.tap(find.text('PREPARE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Prepared'), findsOneWidget);
    expect(find.textContaining('Osaka food trip'), findsOneWidget);
  });

  testWidgets(
    'uses native-language starter queries independently of UI locale',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _routerApp(nativeLanguage: LearningLanguageCode.ko),
      );

      final Finder starterChip = find.widgetWithText(ActionChip, '이번 주 AI 뉴스');
      await tester.ensureVisible(starterChip);
      await tester.tap(starterChip);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '이번 주 AI 뉴스',
      );

      await tester.tap(find.text('PREPARE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('이번 주 AI 뉴스'), findsOneWidget);
    },
  );

  testWidgets('uses Korean system UI copy without changing starter queries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _routerApp(
        nativeLanguage: LearningLanguageCode.en,
        locale: const Locale('ko'),
      ),
    );

    expect(find.text('어떤 주제로 이야기하고 싶나요?'), findsOneWidget);
    expect(find.text('오사카 맛집 여행'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'AI news this week'), findsOneWidget);
    expect(find.text('준비하기'), findsOneWidget);
  });
}

Widget _routerApp({
  LearningLanguageCode nativeLanguage = LearningLanguageCode.en,
  Locale? locale,
}) {
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
  return ProviderScope(
    overrides: [
      topicStarterNativeLanguageProvider.overrideWithValue(nativeLanguage),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: const <Locale>[Locale('en'), Locale('ko')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}
