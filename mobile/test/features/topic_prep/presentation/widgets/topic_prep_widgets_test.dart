import 'package:curitalk/app/theme/app_semantic_colors.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/topic_prep/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SourceLinkTile presents a source host and handles taps', (
    WidgetTester tester,
  ) async {
    int tapCount = 0;
    await tester.pumpWidget(
      _themedApp(
        SourceLinkTile(
          title: 'Osaka food guide',
          url: 'https://example.com/osaka/food',
          onTap: () => tapCount += 1,
        ),
      ),
    );

    expect(find.text('example.com'), findsOneWidget);
    expect(find.bySemanticsLabel('Source: Osaka food guide'), findsOneWidget);
    await tester.tap(find.text('Osaka food guide'));
    expect(tapCount, 1);
  });

  testWidgets('SourceLinkTile falls back to the original URL text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        SourceLinkTile(title: 'Source', url: 'not a url', onTap: () {}),
      ),
    );

    expect(find.text('not a url'), findsOneWidget);
  });

  testWidgets('TopicRetryCard exposes both recovery actions', (
    WidgetTester tester,
  ) async {
    int editCount = 0;
    int ideaCount = 0;
    await tester.pumpWidget(
      _themedApp(
        TopicRetryCard(
          message: 'Try a more specific topic.',
          onEditTopic: () => editCount += 1,
          onTryAnotherIdea: () => ideaCount += 1,
        ),
      ),
    );

    expect(find.text('We need a clearer topic'), findsOneWidget);
    final Material card = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(TopicRetryCard),
            matching: find.byType(Material),
          ),
        )
        .firstWhere(
          (Material material) =>
              material.color == AppSemanticColors.light.searchRetrySurface,
        );
    expect(card.color, AppSemanticColors.light.searchRetrySurface);

    await tester.tap(find.text('Edit topic'));
    await tester.tap(find.text('Try another idea'));
    expect(editCount, 1);
    expect(ideaCount, 1);
  });
}

Widget _themedApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: child,
      ),
    ),
  );
}
