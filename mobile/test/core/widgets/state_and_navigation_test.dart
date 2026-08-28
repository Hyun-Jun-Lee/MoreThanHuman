import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppAsyncStateView renders loading and retry states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_themedApp(const AppAsyncStateView.loading()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading...'), findsOneWidget);

    int retryCount = 0;
    await tester.pumpWidget(
      _themedApp(
        AppAsyncStateView.error(
          message: 'Check your connection.',
          onRetry: () => retryCount += 1,
        ),
      ),
    );

    await tester.tap(find.text('Retry'));
    expect(retryCount, 1);
  });

  testWidgets('AppAsyncStateView renders an empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const AppAsyncStateView.empty(message: 'Start a conversation.'),
      ),
    );

    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(find.text('Start a conversation.'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('AppPageIndicator marks the current page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(const AppPageIndicator(count: 3, currentIndex: 1)),
    );

    final Finder indicators = find.byType(AnimatedContainer);

    expect(indicators, findsNWidgets(3));
    expect(
      tester.getSize(indicators.at(0)).width,
      AppSpacing.xs + AppSpacing.xs,
    );
    expect(
      tester.getSize(indicators.at(1)).width,
      AppSpacing.lg + AppSpacing.xs,
    );
    expect(find.bySemanticsLabel('Page 2 of 3'), findsOneWidget);
  });

  testWidgets('showAppModalSheet presents shared sheet content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        Builder(
          builder: (BuildContext context) {
            return TextButton(
              onPressed: () {
                showAppModalSheet<void>(
                  context: context,
                  builder: (_) => const Text('Sheet content'),
                );
              },
              child: const Text('Open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(AppModalSheet), findsOneWidget);
    expect(find.text('Sheet content'), findsOneWidget);
  });

  testWidgets('MainNavigationBar reports typed destinations', (
    WidgetTester tester,
  ) async {
    MainNavigationDestination? selectedDestination;

    await tester.pumpWidget(
      _themedApp(
        MainNavigationBar(
          destination: MainNavigationDestination.home,
          onDestinationSelected: (MainNavigationDestination destination) {
            selectedDestination = destination;
          },
        ),
      ),
    );

    await tester.tap(find.text('Chat'));

    expect(selectedDestination, MainNavigationDestination.chat);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
  });

  testWidgets('shared chrome follows the Korean system locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        Column(
          children: <Widget>[
            Expanded(child: AppAsyncStateView.loading()),
            MainNavigationBar(
              destination: MainNavigationDestination.home,
              onDestinationSelected: (_) {},
            ),
            AppPageIndicator(count: 3, currentIndex: 1),
          ],
        ),
        locale: const Locale('ko'),
      ),
    );

    expect(find.text('불러오는 중...'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('대화'), findsOneWidget);
    expect(find.bySemanticsLabel('3개 중 2번째 페이지'), findsOneWidget);
  });
}

Widget _themedApp(Widget child, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const <Locale>[Locale('en'), Locale('ko')],
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}
