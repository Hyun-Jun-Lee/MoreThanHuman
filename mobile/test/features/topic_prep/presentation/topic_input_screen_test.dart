import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/home/application/weekly_topics_controller.dart';
import 'package:curitalk/features/home/domain/weekly_topic.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('topic placeholder is vertically centered in its card', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_routerApp(locale: const Locale('ko')));
    await tester.pumpAndSettle();

    final Finder card = find.byKey(const ValueKey<String>('topic-input-card'));
    final Finder hint = find.text('하고 싶은 이야기로 대화해봐요');
    expect(
      tester.getCenter(hint).dy - tester.getCenter(card).dy,
      closeTo(0, 2),
    );
    await tester.enterText(find.byType(TextField), '일주일 동안 인터넷 없이 살아보기');
    await tester.pump();
    expect(
      tester.getCenter(find.byType(EditableText)).dy -
          tester.getCenter(card).dy,
      closeTo(0, 2),
    );
  });

  testWidgets('validates topics shorter than two characters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_routerApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('Conversation topic'), 'A');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'A',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('TALK'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter at least 2 characters.', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Prepared'), findsNothing);
  });

  testWidgets('example cards fill the input and valid topics navigate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_routerApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('A city designed for night owls'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A city designed for night owls'));
    await tester.pumpAndSettle();
    final Finder selectedCard = find
        .ancestor(
          of: find.text('A city designed for night owls'),
          matching: find.byType(Container),
        )
        .first;
    expect(
      (tester.widget<Container>(selectedCard).decoration as BoxDecoration)
          .color,
      const Color(0xFFF6F4EB),
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'A city designed for night owls',
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TALK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Prepared'), findsOneWidget);
    expect(find.text('Recommended topic'), findsOneWidget);
    expect(
      find.textContaining('A city designed for night owls'),
      findsOneWidget,
    );
  });

  testWidgets('uses recommended topics independently of UI locale', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_routerApp(topics: _koreanTopics));

    await tester.pumpAndSettle();
    final Finder starterCard = find.text('일주일 동안 인터넷 없이 살아보기');
    await tester.ensureVisible(starterCard);
    await tester.tap(starterCard);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '일주일 동안 인터넷 없이 살아보기',
    );

    await tester.tap(find.text('TALK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('일주일 동안 인터넷 없이 살아보기'), findsOneWidget);
  });

  testWidgets(
    'uses Korean system UI copy without changing recommended topics',
    (WidgetTester tester) async {
      await tester.pumpWidget(_routerApp(locale: const Locale('ko')));

      await tester.pumpAndSettle();
      expect(find.text('오늘은 어떤 이야기를 나눠볼까요?'), findsOneWidget);
      expect(find.text('FreeChat'), findsOneWidget);
      expect(find.text('하고 싶은 이야기로 대화해봐요'), findsOneWidget);
      expect(find.text('나누고 싶은 주제는 무엇인가요?'), findsNothing);
      final Text title = tester.widget<Text>(find.text('오늘은 어떤 이야기를 나눠볼까요?'));
      expect(title.maxLines, 1);
      expect(title.softWrap, isFalse);
      final TextField input = tester.widget<TextField>(find.byType(TextField));
      expect(input.textAlign, TextAlign.center);
      expect(input.textAlignVertical, TextAlignVertical.center);
      expect(input.decoration?.hintText, '하고 싶은 이야기로 대화해봐요');
      expect(input.decoration?.filled, isFalse);
      expect(find.text('오사카 맛집 여행'), findsNothing);
      expect(find.text('What would you teach an alien?'), findsOneWidget);
      expect(find.text('대화하기'), findsOneWidget);
      final Finder inputCard = find.byKey(
        const ValueKey<String>('topic-input-card'),
      );
      final Finder examplesLabel = find.text('빠르게 골라보세요');
      expect(tester.getSize(inputCard).height, 80);
      expect(
        tester.getTopLeft(examplesLabel).dy -
            tester.getBottomLeft(inputCard).dy,
        56,
      );
      expect(tester.widget<Text>(examplesLabel).textAlign, TextAlign.center);
      expect(
        (tester.widget<Container>(inputCard).decoration as BoxDecoration).color,
        const Color(0xFFF6F4EB),
      );
      expect(find.byType(GridView), findsNothing);
      final first = find.byKey(const ValueKey('topic-example-topic-0'));
      final second = find.byKey(const ValueKey('topic-example-topic-1'));
      expect(tester.getTopLeft(first).dx, tester.getTopLeft(second).dx);
      expect(
        tester.getBottomLeft(first).dy,
        lessThanOrEqualTo(tester.getTopLeft(second).dy),
      );
      expect(tester.getSize(first).width, tester.getSize(inputCard).width);
      expect(
        tester
            .widget<Text>(find.text('What would you teach an alien?'))
            .textAlign,
        TextAlign.center,
      );
    },
  );
  testWidgets('shows at most six recommendations and keeps them while typing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _routerApp(topics: [..._topics, 'Seventh topic', 'Eighth topic']),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('topic-example-topic-$i')), findsOneWidget);
    }
    expect(find.text('Seventh topic'), findsNothing);
    expect(find.text('Eighth topic'), findsNothing);
    await tester.enterText(find.byType(TextField), 'My own topic');
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(ValueKey('topic-example-topic-$i')), findsOneWidget);
    }
  });

  testWidgets('shows available topics when fewer than six exist', (
    tester,
  ) async {
    await tester.pumpWidget(_routerApp(topics: _topics.take(2).toList()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('topic-example-topic-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('topic-example-topic-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('topic-example-topic-2')), findsNothing);
  });

  testWidgets(
    'focusing a recommendation clears it but preserves later manual input',
    (tester) async {
      await tester.pumpWidget(_routerApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text(_topics.first));
      await tester.pump();
      final input = find.byType(TextField);
      await tester.tap(input);
      await tester.pump();
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
        findsNothing,
      );
      await tester.enterText(find.byType(TextField), 'My revised topic');
      await tester.pump();
      tester.widget<TextField>(input).focusNode!.unfocus();
      await tester.pump();
      await tester.tap(input);
      await tester.pump();
      expect(
        tester.widget<TextField>(input).controller!.text,
        'My revised topic',
      );
      await tester.tap(find.text('TALK'));
      await tester.pumpAndSettle();
      expect(find.text('Prepared My revised topic'), findsOneWidget);
      expect(find.text('Recommended topic'), findsNothing);
    },
  );

  testWidgets('no recommendations still allows entering a custom topic', (
    tester,
  ) async {
    await tester.pumpWidget(_routerApp(topics: const []));
    await tester.pumpAndSettle();
    expect(find.text('Pick a topic'), findsNothing);
    await tester.enterText(find.byType(TextField), 'My own topic');
    await tester.pump();
    await tester.tap(find.text('TALK'));
    await tester.pumpAndSettle();
    expect(find.text('Prepared My own topic'), findsOneWidget);
    expect(find.text('Recommended topic'), findsNothing);
  });
}

Widget _routerApp({List<String> topics = _topics, Locale? locale}) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoute.topicInput,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.topicInput,
        builder: (_, _) => const TopicInputScreen(),
      ),
      GoRoute(
        path: AppRoute.topicPrep,
        builder: (_, GoRouterState state) {
          return Scaffold(
            body: Column(
              children: [
                Text('Prepared ${state.uri.queryParameters['topic']}'),
                if (state.uri.queryParameters['recommended'] == 'true')
                  const Text('Recommended topic'),
              ],
            ),
          );
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      topicInputTopicsProvider.overrideWith(
        () => _FixedTopicsController(topics),
      ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: locale,
      supportedLocales: const <Locale>[Locale('en'), Locale('ko')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

const _topics = <String>[
  'What would you teach an alien?',
  'A city designed for night owls',
  'A world without clocks',
  'Trading jobs with a friend',
  'One invention you would undo',
  'A museum about your life',
];
const _koreanTopics = <String>['일주일 동안 인터넷 없이 살아보기'];

class _FixedTopicsController extends WeeklyTopicsController {
  _FixedTopicsController(this.topics);
  final List<String> topics;

  @override
  Future<WeeklyTopics> build() async => WeeklyTopics(
    weekStart: null,
    topics: [
      for (var i = 0; i < topics.length; i++)
        WeeklyTopic(id: 'topic-$i', text: topics[i]),
    ],
  );
}
