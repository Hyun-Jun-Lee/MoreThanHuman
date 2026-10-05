import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _displayTitle = 'Osaka food\ntrip';

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
    expect(find.text(_displayTitle), findsOneWidget);
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
      greaterThan(tester.getRect(find.text(_displayTitle)).right),
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

    await tester.tap(find.text(_displayTitle));
    expect(tapCount, 1);
  });

  testWidgets('Korean title wraps in pairs but keeps its original semantics', (
    WidgetTester tester,
  ) async {
    const title = '내가 배우고 싶은 새로운 기술';
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _themedApp(
        const RecentConversationCard(
          category: 'freechat',
          title: title,
          color: AppPalette.blockLimeSoft,
          onTap: null,
        ),
      ),
    );

    final titleFinder = find.byWidgetPredicate(
      (widget) => widget is Text && widget.semanticsLabel == title,
    );
    final text = tester.widget<Text>(titleFinder);
    expect(text.data?.replaceAll('\u2060', ''), '내가 배우고\n싶은 새로운\n기술');
    expect(text.semanticsLabel, title);
    expect(text.maxLines, 3);
    final richText = find.descendant(
      of: titleFinder,
      matching: find.byType(RichText),
    );
    final paragraph = tester.renderObject<RenderParagraph>(richText);
    final rendered = paragraph.text.toPlainText();
    final technology = rendered.indexOf('기\u2060술');
    expect(technology, isNonNegative);
    expect(
      paragraph.getBoxesForSelection(
        TextSelection(baseOffset: technology, extentOffset: technology + 1),
      ),
      isNotEmpty,
    );
    expect(tester.takeException(), isNull);
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
      await tester.drag(find.text(_displayTitle), const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNotNull,
      );
      await tester.drag(find.text(_displayTitle), const Offset(120, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Delete'))
            .onPressed,
        isNull,
      );
      await tester.drag(find.text(_displayTitle), const Offset(-120, 0));
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

      await tester.tap(find.text(_displayTitle));
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
