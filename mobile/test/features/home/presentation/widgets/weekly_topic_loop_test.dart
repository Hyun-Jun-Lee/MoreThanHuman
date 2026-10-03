import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:curitalk/features/home/presentation/widgets/weekly_topic_loop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
      AppPalette.blockBlue,
    );
    expect(
      tester
          .widget<Material>(
            find.byKey(const ValueKey('weekly-topic-card-second')),
          )
          .color,
      AppPalette.blockPink,
    );
    await tester.tap(find.byKey(const ValueKey('weekly-topic-second')));
    expect(selected?.id, 'second');
    expect(tester.takeException(), isNull);
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
}

void _ignore(WeeklyTopic _) {}
