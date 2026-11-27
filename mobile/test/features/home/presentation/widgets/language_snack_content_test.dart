import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:curitalk/features/home/presentation/widgets/language_snack_content.dart';
import '../../snack_test_fixtures.dart';

void main() {
  testWidgets('both core expressions precede examples', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LanguageSnackContent(
              snack: testSnack(0, type: 'usage_contrast'),
            ),
          ),
        ),
      ),
    );
    final first = find.text('word-0-0').first;
    final second = find.text('word-0-1').first;
    final examples = find.text('이렇게 써요');
    expect(
      tester.getTopLeft(first).dy,
      lessThan(tester.getTopLeft(examples).dy),
    );
    expect(
      tester.getTopLeft(second).dy,
      lessThan(tester.getTopLeft(examples).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('idiom meaning and example precede literal explanation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LanguageSnackContent(
              snack: testSnack(0, type: 'idiomatic_expression'),
            ),
          ),
        ),
      ),
    );
    final meaning = tester.getTopLeft(find.text('어색함을 풀다')).dy;
    final example = tester
        .getTopLeft(find.text('We played a game to break the ice.'))
        .dy;
    final literal = tester.getTopLeft(find.text('얼음을 깨다')).dy;
    expect(meaning, lessThan(example));
    expect(example, lessThan(literal));
    expect(tester.takeException(), isNull);
  });

  test('known register labels follow explanation language', () {
    expect(snackRegisterLabel('Formal', true), '격식 있는 표현');
    expect(snackRegisterLabel('Informal', true), '일상적인 표현');
    expect(snackRegisterLabel('Formal', false), 'Formal');
    expect(snackRegisterLabel('친구 사이', true), '친구 사이');
  });
}
