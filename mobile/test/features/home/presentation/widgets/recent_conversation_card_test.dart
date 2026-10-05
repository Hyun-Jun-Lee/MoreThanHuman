import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('RecentConversationCard presents conversation metadata', (
    WidgetTester tester,
  ) async {
    int tapCount = 0;
    await tester.pumpWidget(
      _themedApp(
        RecentConversationCard(
          category: 'freechat',
          title: 'Osaka food trip',
          color: AppPalette.blockLimeSoft,
          onTap: () => tapCount += 1,
        ),
      ),
    );

    final badge = find.text('freechat');
    expect(badge, findsOneWidget);
    expect(find.text('Osaka food trip'), findsOneWidget);
    expect(find.textContaining('messages'), findsNothing);
    expect(find.text('Continue speaking'), findsNothing);
    final Semantics semantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(RecentConversationCard),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere(
          (Semantics item) =>
              item.properties.label == 'freechat conversation: Osaka food trip',
        );
    expect(
      semantics.properties.label,
      'freechat conversation: Osaka food trip',
    );
    expect(
      tester.getRect(badge).left,
      greaterThan(tester.getRect(find.text('Osaka food trip')).right),
    );

    final Material card = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(RecentConversationCard),
            matching: find.byType(Material),
          ),
        )
        .firstWhere(
          (Material material) => material.color == AppPalette.blockLimeSoft,
        );
    expect(card.color, AppPalette.blockLimeSoft);

    await tester.tap(find.text('Osaka food trip'));
    expect(tapCount, 1);
  });

  testWidgets(
    'swiping left reveals Delete and preserves confirmation callback',
    (WidgetTester tester) async {
      int deleteCount = 0;
      int tapCount = 0;
      await tester.pumpWidget(
        _themedApp(
          RecentConversationCard(
            category: 'roleplaying',
            title: 'Osaka food trip',
            color: AppPalette.blockLimeSoft,
            onTap: () => tapCount += 1,
            onDelete: () => deleteCount += 1,
          ),
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsNothing);
      expect(find.text('roleplaying'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNull,
      );
      await tester.drag(find.text('Osaka food trip'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNotNull,
      );
      await tester.drag(find.text('Osaka food trip'), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNull,
      );
      await tester.drag(find.text('Osaka food trip'), const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deleteCount, 1);
      expect(tapCount, 0);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Osaka food trip'));
      expect(tapCount, 1);
    },
  );
}

Widget _themedApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
    ),
  );
}
