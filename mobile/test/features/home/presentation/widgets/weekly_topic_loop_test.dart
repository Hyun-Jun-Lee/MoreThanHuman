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
      tester.widget<TextKo>(find.text('주말 산책 이야기').first).style?.color,
      AppPalette.ink,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('moving cards keep equal width and centered wrapped text', (
    tester,
  ) async {
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
      expect(tester.getSize(card).width, 156);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(104));
      expect(
        tester.getSize(card),
        tester.getSize(find.byKey(const ValueKey('weekly-topic-card-short-0'))),
      );
      expect(
        tester.getCenter(text).dx,
        closeTo(tester.getCenter(card).dx, 0.1),
      );
      expect(tester.widget<TextKo>(text).maxLines, isNull);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('topic wraps naturally without changing its original', (
    tester,
  ) async {
    const topic = '내가 배우고 싶은 새로운 기술';
    WeeklyTopic? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeeklyTopicLoop(
            topics: const [WeeklyTopic(id: 'korean', text: topic)],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    final display = tester.widget<TextKo>(find.byType(TextKo).first);
    expect(display.data, topic);
    expect(display.semanticsLabel, topic);
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
    expect(paragraph.didExceedMaxLines, isFalse);
    await tester.tap(find.byKey(const ValueKey('weekly-topic-korean-1')));
    expect(selected?.text, topic);
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

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('long Korean and English topics fit at text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const longTopics = [
        WeeklyTopic(id: 'short', text: '취미 이야기'),
        WeeklyTopic(
          id: 'ko',
          text: '좀비 세상에서 의외로 쓸모 있을 내 숨겨진 재능과 생존 전략에 대해 이야기해 보기',
        ),
        WeeklyTopic(
          id: 'en',
          text:
              'What would you bring to a new world where you can only keep three things from your old life?',
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: WeeklyTopicLoop(
                  topics: longTopics,
                  onSelected: _ignore,
                  selectedTopicId: 'short',
                ),
              ),
            ),
          ),
        ),
      );
      final suffix = scale > 1.3 ? '' : '-0';
      final shortCard = find.byKey(ValueKey('weekly-topic-card-short$suffix'));
      final size = tester.getSize(shortCard);
      expect(size.height, greaterThan(104));
      for (final topic in longTopics) {
        final card = find.byKey(
          ValueKey('weekly-topic-card-${topic.id}$suffix'),
        );
        expect(tester.getSize(card), size);
        final text = find.descendant(of: card, matching: find.byType(TextKo));
        expect(tester.widget<TextKo>(text).data, topic.text);
        final rich = find.descendant(of: text, matching: find.byType(RichText));
        final paragraph = tester.renderObject<RenderParagraph>(rich);
        expect(paragraph.didExceedMaxLines, isFalse);
        final rendered = paragraph.text.toPlainText();
        // 줄 끝 공백의 selection box는 너비 밖으로 뻗을 수 있어 실제 글자를 검증해요.
        for (var index = 0; index < rendered.length; index++) {
          if (rendered[index].trim().isEmpty || rendered[index] == '\u2060') {
            continue;
          }
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: index, extentOffset: index + 1),
          );
          expect(boxes, isNotEmpty);
          for (final box in boxes) {
            expect(box.bottom, lessThanOrEqualTo(paragraph.size.height + 0.1));
            expect(
              box.left,
              greaterThanOrEqualTo(-0.1),
              reason: '${topic.id}: ${rendered[index]}',
            );
            expect(
              box.right,
              lessThanOrEqualTo(paragraph.size.width + 0.1),
              reason: '${topic.id}: ${rendered[index]}',
            );
          }
        }
        expect(
          tester.getBottomLeft(rich).dy,
          lessThanOrEqualTo(tester.getBottomLeft(card).dy - 12 + 0.1),
        );
        expect(
          tester.getBottomLeft(card).dy,
          lessThanOrEqualTo(
            tester.getBottomLeft(find.byType(WeeklyTopicLoop)).dy,
          ),
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('an empty topic list takes no space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeeklyTopicLoop(topics: [], onSelected: _ignore),
        ),
      ),
    );
    expect(tester.getSize(find.byType(WeeklyTopicLoop)), Size.zero);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
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
