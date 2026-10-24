import 'package:curitalk/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('highlights each tomato in order and repeats', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLoadingIndicator(width: 200))),
    );

    expect(_frameAsset(tester), 'assets/images/loading/tomato_row_0.png');
    expect(tester.getSize(find.byType(AppLoadingIndicator)).width, 200);

    await tester.pump(const Duration(milliseconds: 420));
    expect(_frameAsset(tester), 'assets/images/loading/tomato_row_1.png');

    await tester.pump(const Duration(milliseconds: 1680));
    expect(_frameAsset(tester), 'assets/images/loading/tomato_row_0.png');
  });

  testWidgets('stays on the first frame when animations are disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: AppLoadingIndicator()),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(_frameAsset(tester), 'assets/images/loading/tomato_row_0.png');
  });
}

String _frameAsset(WidgetTester tester) {
  final Image image = tester.widget<Image>(
    find.descendant(
      of: find.byType(AppLoadingIndicator),
      matching: find.byType(Image),
    ),
  );
  return (image.image as AssetImage).assetName;
}
