import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a single paragraph as one text block', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const AppParagraphText(
          text: 'A single paragraph.',
          style: AppTypography.bodySm,
        ),
      ),
    );

    expect(find.text('A single paragraph.'), findsOneWidget);
    expect(find.byType(Column), findsNothing);
  });

  testWidgets('splits blank-line separated paragraphs with spacing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const AppParagraphText(
          text: 'First paragraph.\n\nSecond paragraph.',
          style: AppTypography.bodySm,
        ),
      ),
    );

    expect(find.text('First paragraph.'), findsOneWidget);
    expect(find.text('Second paragraph.'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is SizedBox && widget.height == AppSpacing.sm,
      ),
      findsOneWidget,
    );
  });

  testWidgets('trims empty leading and repeated blank lines', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const AppParagraphText(
          text: '\n\n First paragraph. \n\n\n Second paragraph. \n',
          style: AppTypography.bodySm,
        ),
      ),
    );

    expect(find.text('First paragraph.'), findsOneWidget);
    expect(find.text('Second paragraph.'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  testWidgets('keeps start alignment as the default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _themedApp(
        const AppParagraphText(
          text: 'First paragraph.\n\nSecond paragraph.',
          style: AppTypography.bodySm,
        ),
      ),
    );

    final Text firstParagraph = tester.widget<Text>(
      find.text('First paragraph.'),
    );
    expect(firstParagraph.textAlign, TextAlign.start);
  });
}

Widget _themedApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  );
}
