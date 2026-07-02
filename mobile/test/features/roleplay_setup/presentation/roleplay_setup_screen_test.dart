import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/roleplay_setup/roleplay_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows preset scenarios and starts disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(find.text('Choose a situation'), findsOneWidget);
    expect(find.text('Cafe order'), findsOneWidget);
    expect(find.text('Hotel check-in'), findsOneWidget);
    expect(roleplayPresetScenarios, hasLength(7));
    expect(_startButton(tester).enabled, isFalse);
  });

  testWidgets('selecting a preset enables start', (WidgetTester tester) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.text('Cafe order'));
    await tester.pumpAndSettle();

    expect(_startButton(tester).enabled, isTrue);
    expect(
      find.bySemanticsLabel('Roleplay scenario: Cafe order'),
      findsOneWidget,
    );
  });

  testWidgets('changing difficulty updates selected chip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.scrollUntilVisible(
      find.text('CHALLENGE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('CHALLENGE'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unexpected questions that invite longer answers.'),
      findsOneWidget,
    );
  });

  testWidgets('custom input validates minimum length and enables start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.scrollUntilVisible(
      find.text('CUSTOM ROLEPLAY'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('CUSTOM ROLEPLAY'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.bySemanticsLabel('Custom roleplay situation'),
      'A',
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
    expect(_startButton(tester).enabled, isFalse);

    await tester.enterText(
      find.bySemanticsLabel('Custom roleplay situation'),
      '오사카 식당에서 예약 확인하기',
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter at least 2 characters.'), findsNothing);
    expect(_startButton(tester).enabled, isTrue);
  });
}

FilledButton _startButton(WidgetTester tester) {
  return tester.widget<FilledButton>(find.byType(FilledButton));
}

Widget _app() {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      home: const RoleplaySetupScreen(),
    ),
  );
}
