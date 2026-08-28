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
          category: 'Travel',
          title: 'Osaka food trip',
          preview: 'Let us make sure we visit Dotonbori for takoyaki.',
          color: AppPalette.blockLimeSoft,
          onTap: () => tapCount += 1,
        ),
      ),
    );

    expect(find.text('TRAVEL'), findsNothing);
    expect(find.text('Osaka food trip'), findsOneWidget);
    final Semantics semantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(RecentConversationCard),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere(
          (Semantics item) =>
              item.properties.label == 'Travel conversation: Osaka food trip',
        );
    expect(semantics.properties.label, 'Travel conversation: Osaka food trip');

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

  testWidgets('places the small delete X at the card top right', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        RecentConversationCard(
          category: 'Travel',
          title: 'Osaka food trip',
          preview: 'Let us make sure we visit Dotonbori for takoyaki.',
          color: AppPalette.blockLimeSoft,
          onTap: () {},
          onDelete: () {},
        ),
      ),
    );

    final Finder cardFinder = find.byType(RecentConversationCard);
    final Finder deleteFinder = find.byTooltip('Delete conversation');
    final Rect cardRect = tester.getRect(cardFinder);
    final Rect deleteRect = tester.getRect(deleteFinder);

    expect(deleteRect.size, const Size(28, 28));
    expect(deleteRect.right, closeTo(cardRect.right - AppSpacing.lg, 0.1));
    expect(deleteRect.top, closeTo(cardRect.top + AppSpacing.lg, 0.1));
  });
}

Widget _themedApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
    ),
  );
}
