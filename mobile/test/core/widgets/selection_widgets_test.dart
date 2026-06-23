import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppSelectionChip reports selection changes', (
    WidgetTester tester,
  ) async {
    bool? selected;
    await tester.pumpWidget(
      _themedApp(
        AppSelectionChip(
          label: 'Casual chat',
          selected: false,
          onSelected: (bool value) => selected = value,
        ),
      ),
    );

    expect(find.text('CASUAL CHAT'), findsOneWidget);
    await tester.tap(find.byType(ChoiceChip));
    expect(selected, isTrue);
  });

  testWidgets('AppSelectionChip disables interaction', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        AppSelectionChip(
          label: 'Unavailable',
          selected: false,
          onSelected: null,
        ),
      ),
    );

    final ChoiceChip chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.onSelected, isNull);
  });

  testWidgets('AppSelectionCard displays selection and handles taps', (
    WidgetTester tester,
  ) async {
    int tapCount = 0;
    await tester.pumpWidget(
      _themedApp(
        AppSelectionCard(
          title: 'Free Chat',
          description: 'Bring your own topic',
          selected: true,
          onTap: () => tapCount += 1,
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          surfaceColor: AppPalette.blockLilacSoft,
        ),
      ),
    );

    expect(find.text('Free Chat'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    final Semantics semantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(AppSelectionCard),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere((Semantics item) => item.properties.selected == true);
    expect(semantics.properties.button, isTrue);
    expect(semantics.properties.selected, isTrue);
    await tester.tap(find.text('Free Chat'));
    expect(tapCount, 1);
  });
}

Widget _themedApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}
