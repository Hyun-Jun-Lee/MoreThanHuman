import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:curitalk/features/home/presentation/widgets/weekly_topic_loop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:text_ko/text_ko.dart';

void main() {
  const topics = [
    WeeklyTopic(id: 'first', text: '오늘의 취미 이야기'),
    WeeklyTopic(id: 'second', text: '주말 산책 이야기'),
  ];

  testWidgets('reduce motion shows independent static choices', (tester) async {
    WeeklyTopic? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: WeeklyTopicLoop(
              topics: topics,
              onSelected: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('weekly-topics-static')), findsOneWidget);
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-first')),
          )
          .color,
      AppPalette.topicSurface,
    );
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-second')),
          )
          .color,
      AppPalette.topicSurface,
    );
    await tester.tap(find.byKey(const ValueKey('weekly-topic-second')));
    expect(selected?.id, 'second');
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected topic changes every copy to red with black text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeeklyTopicLoop(
            topics: topics,
            selectedTopicId: 'second',
            onSelected: _ignore,
          ),
        ),
      ),
    );
    for (final copy in [0, 1]) {
      expect(
        tester
            .widget<Material>(
              find.byKey(ValueKey('weekly-topic-card-second-$copy')),
            )
            .color,
        AppPalette.topicSelectedSurface,
      );
    }
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-first-0')),
          )
          .color,
      AppPalette.topicSurface,
    );
    expect(
      tester.widget<Text>(find.text('주말 산책 이야기').first).style?.color,
      AppPalette.ink,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'moving cards keep equal width and centered one- or two-line text',
    (tester) async {
      const short = '취미 이야기';
      const long = '주말에 가장 기억에 남는 활동 이야기';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WeeklyTopicLoop(
              topics: [
                WeeklyTopic(id: 'short', text: short),
                WeeklyTopic(id: 'long', text: long),
              ],
              onSelected: _ignore,
            ),
          ),
        ),
      );

      for (final id in ['short', 'long']) {
        final card = find.byKey(ValueKey('weekly-topic-card-$id-0'));
        final text = find.text(id == 'short' ? short : long).first;
        expect(tester.getSize(card), const Size(156, 84));
        expect(
          tester.getCenter(text).dx,
          closeTo(tester.getCenter(card).dx, 0.1),
        );
        expect(tester.widget<Text>(text).maxLines, 2);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Korean topic keeps 기술 together on the second line', (
    tester,
  ) async {
    const topic = '내가 배우고 싶은 새로운 기술';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeeklyTopicLoop(
            topics: [WeeklyTopic(id: 'korean', text: topic)],
            onSelected: _ignore,
          ),
        ),
      ),
    );

    final richText = find
        .descendant(
          of: find.byType(TextKo).first,
          matching: find.byType(RichText),
        )
        .first;
    final paragraph = tester.renderObject<RenderParagraph>(richText);
    final rendered = paragraph.text.toPlainText();
    final technology = rendered.indexOf('기\u2060술');
    expect(technology, isNonNegative);

    double topOf(int index) => paragraph
        .getBoxesForSelection(
          TextSelection(baseOffset: index, extentOffset: index + 1),
        )
        .single
        .top;

    expect(topOf(technology), topOf(technology + 2));
    expect(topOf(technology), greaterThan(topOf(rendered.indexOf('내'))));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('large text fits a narrow screen in static mode', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: WeeklyTopicLoop(
              topics: [
                WeeklyTopic(id: 'long', text: '주말에 가장 기억에 남는 활동과 그 이유에 관한 이야기'),
              ],
              onSelected: _ignore,
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('weekly-topics-static')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topics move right and pause under touch', (tester) async {
    WeeklyTopic? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyTopicLoop(
            topics: topics,
            onSelected: (topic) => selected = topic,
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey('weekly-topic-second-0'));
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-second-0')),
          )
          .color,
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-second-1')),
          )
          .color,
    );
    final before = tester.getTopLeft(first).dx;
    await tester.pump(const Duration(seconds: 1));
    final after = tester.getTopLeft(first).dx;
    expect(after, greaterThan(before));
    final gesture = await tester.startGesture(tester.getCenter(first));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(first).dx, closeTo(after, 0.1));
    await gesture.up();
    expect(selected?.id, 'second');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('drag moves topics both ways and auto motion resumes', (
    tester,
  ) async {
    WeeklyTopic? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyTopicLoop(
            topics: topics,
            onSelected: (topic) => selected = topic,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final card = find.byKey(const ValueKey('weekly-topic-second-0'));
    final before = tester.getTopLeft(card).dx;
    final gesture = await tester.startGesture(tester.getCenter(card));

    await gesture.moveBy(const Offset(-64, 0));
    await tester.pump();
    final left = tester.getTopLeft(card).dx;
    expect(left, lessThan(before - 20));

    await gesture.moveBy(const Offset(112, 0));
    await tester.pump();
    final right = tester.getTopLeft(card).dx;
    expect(right, greaterThan(left + 60));

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(card).dx, greaterThan(right));
    expect(selected, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

void _ignore(WeeklyTopic _) {}
