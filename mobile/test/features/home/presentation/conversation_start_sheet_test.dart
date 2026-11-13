import 'package:curitalk/features/home/domain/conversation_start_type.dart';
import 'package:curitalk/features/home/presentation/conversation_start_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Korean start sheet uses English option titles', (tester) async {
    ConversationStartType? selectedType;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selectedType = await showConversationStartSheet(context);
              },
              child: const Text('대화 시작'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('대화 시작'));
    await tester.pumpAndSettle();

    expect(find.text('FreeChat'), findsOneWidget);
    expect(find.text('Role Playing'), findsOneWidget);
    expect(find.text('자유 대화'), findsNothing);
    expect(find.text('역할극'), findsNothing);

    await tester.tap(find.text('Role Playing'));
    await tester.pumpAndSettle();
    expect(selectedType, ConversationStartType.roleplay);
  });
}
