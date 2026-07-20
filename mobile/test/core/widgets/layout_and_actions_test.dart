import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppScaffold applies safe area and screen padding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(const AppScaffold(body: Text('Content'))),
    );

    final Finder safeAreaFinder = find.descendant(
      of: find.byType(AppScaffold),
      matching: find.byType(SafeArea),
    );
    final SafeArea safeArea = tester.widget<SafeArea>(safeAreaFinder.first);
    final Iterable<Padding> paddings = tester.widgetList<Padding>(
      find.descendant(of: safeAreaFinder.first, matching: find.byType(Padding)),
    );

    expect(safeArea.top, isTrue);
    expect(safeArea.bottom, isTrue);
    expect(
      paddings.any(
        (Padding padding) =>
            padding.padding ==
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      ),
      isTrue,
    );
  });

  testWidgets('AppPrimaryButton handles enabled and loading states', (
    WidgetTester tester,
  ) async {
    int pressCount = 0;

    await tester.pumpWidget(
      _themedApp(
        AppPrimaryButton(label: 'Continue', onPressed: () => pressCount += 1),
      ),
    );

    await tester.tap(find.text('Continue'));
    expect(pressCount, 1);

    await tester.pumpWidget(
      _themedApp(
        AppPrimaryButton(
          label: 'Continue',
          isLoading: true,
          onPressed: () => pressCount += 1,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(pressCount, 1);

    await tester.pumpWidget(
      _themedApp(
        AppPrimaryButton(
          label: 'Compact',
          expand: false,
          onPressed: () => pressCount += 1,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Compact'), findsOneWidget);
  });

  testWidgets('AppBottomActionBar protects its action with SafeArea', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(const AppBottomActionBar(child: Text('Action'))),
    );

    final SafeArea safeArea = tester.widget<SafeArea>(find.byType(SafeArea));

    expect(safeArea.top, isFalse);
    expect(find.text('Action'), findsOneWidget);
  });

  testWidgets('AppSectionLabel uses uppercase mono text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_themedApp(const AppSectionLabel('Recent')));

    final Text text = tester.widget<Text>(find.text('RECENT'));

    expect(text.style?.fontFamily, AppTypography.monoFontFamily);
  });

  testWidgets('AppColorBlockCard applies color and tap behavior', (
    WidgetTester tester,
  ) async {
    int tapCount = 0;

    await tester.pumpWidget(
      _themedApp(
        AppColorBlockCard(
          color: AppPalette.blockLime,
          onTap: () => tapCount += 1,
          child: const Text('Topic'),
        ),
      ),
    );

    final Material material = tester.widget<Material>(
      find.descendant(
        of: find.byType(AppColorBlockCard),
        matching: find.byType(Material),
      ),
    );

    expect(material.color, AppPalette.blockLime);
    await tester.tap(find.text('Topic'));
    expect(tapCount, 1);
  });
}

Widget _themedApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}
