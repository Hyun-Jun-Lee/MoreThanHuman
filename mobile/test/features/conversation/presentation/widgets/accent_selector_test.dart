import 'package:curitalk/features/conversation/presentation/widgets/accent_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('flags select the country and expose selection semantics', (
    tester,
  ) async {
    var accent = 'us';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AccentSelector(
              value: accent,
              onChanged: (value) => setState(() => accent = value),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(4));
    expect(find.byKey(const ValueKey('accent-selected-us')), findsOneWidget);
    expect(find.text('United States'), findsOneWidget);
    expect(find.text('United Kingdom'), findsOneWidget);
    expect(find.text('Australia'), findsOneWidget);
    await tester.tap(find.text('United Kingdom'));
    await tester.pump();
    expect(accent, 'gb');
    expect(find.byKey(const ValueKey('accent-selected-us')), findsNothing);
    expect(find.byKey(const ValueKey('accent-selected-gb')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('accent-selected-gb'))).dy,
      greaterThan(tester.getBottomLeft(find.text('United Kingdom')).dy),
    );
    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'United Kingdom accent',
      ),
    );
    expect(semantics.properties.selected, true);
  });
}
