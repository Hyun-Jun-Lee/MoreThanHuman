import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppTextField forwards text input and submission', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    String? changedValue;
    String? submittedValue;

    await tester.pumpWidget(
      _themedApp(
        AppTextField(
          controller: controller,
          hintText: 'Type a topic',
          semanticLabel: 'Conversation topic',
          textInputAction: TextInputAction.search,
          onChanged: (String value) => changedValue = value,
          onSubmitted: (String value) => submittedValue = value,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Apple WWDC');
    await tester.testTextInput.receiveAction(TextInputAction.search);

    expect(changedValue, 'Apple WWDC');
    expect(submittedValue, 'Apple WWDC');
    final Semantics semantics = tester
        .widgetList<Semantics>(
          find.descendant(
            of: find.byType(AppTextField),
            matching: find.byType(Semantics),
          ),
        )
        .firstWhere(
          (Semantics item) => item.properties.label == 'Conversation topic',
        );
    expect(semantics.properties.textField, isTrue);
  });

  testWidgets('AppTextField displays validation feedback', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _themedApp(
        AppTextField(
          controller: controller,
          hintText: 'Type a topic',
          errorText: 'Enter at least 2 characters.',
        ),
      ),
    );

    expect(find.text('Enter at least 2 characters.'), findsOneWidget);
  });
}

Widget _themedApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}
