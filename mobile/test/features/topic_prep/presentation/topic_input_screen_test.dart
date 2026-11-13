import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/language/language.dart';
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

    final Finder card = find.byKey(const ValueKey<String>('topic-input-card'));
    final Finder hint = find.text('나누고 싶은 주제는 무엇인가요?');
    expect(
      tester.getCenter(hint).dy - tester.getCenter(card).dy,
      closeTo(0, 2),
    );
    await tester.enterText(find.byType(TextField), '이번 주말 계획');
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

    await tester.scrollUntilVisible(
      find.text('Osaka food trip'),
      80,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Osaka food trip'));
    await tester.pumpAndSettle();
    final Finder selectedCard = find
        .ancestor(
          of: find.text('Osaka food trip'),
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
      'Osaka food trip',
    );

    await tester.tap(find.text('TALK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Prepared'), findsOneWidget);
    expect(find.textContaining('Osaka food trip'), findsOneWidget);
  });

  testWidgets(
    'uses native-language starter queries independently of UI locale',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _routerApp(nativeLanguage: LearningLanguageCode.ko),
      );

      final Finder starterCard = find.text('이번 주말 계획');
      await tester.ensureVisible(starterCard);
      await tester.tap(starterCard);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '이번 주말 계획',
      );

      await tester.tap(find.text('TALK'));
      await tester.pumpAndSettle();
      expect(find.textContaining('이번 주말 계획'), findsOneWidget);
    },
  );

  testWidgets('uses Korean system UI copy without changing starter queries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _routerApp(
        nativeLanguage: LearningLanguageCode.en,
        locale: const Locale('ko'),
      ),
    );

    expect(find.text('오늘은 어떤 이야기를 나눠볼까요?'), findsOneWidget);
    expect(find.text('FreeChat'), findsOneWidget);
    expect(find.text('하고 싶은 이야기로 대화해봐요'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('하고 싶은 이야기로 대화해봐요')).textAlign,
      TextAlign.center,
    );
    final Text title = tester.widget<Text>(find.text('오늘은 어떤 이야기를 나눠볼까요?'));
    expect(title.maxLines, 1);
    expect(title.softWrap, isFalse);
    final TextField input = tester.widget<TextField>(find.byType(TextField));
    expect(input.textAlign, TextAlign.center);
    expect(input.textAlignVertical, TextAlignVertical.center);
    expect(input.decoration?.hintText, '나누고 싶은 주제는 무엇인가요?');
    expect(input.decoration?.filled, isFalse);
    expect(find.text('오사카 맛집 여행'), findsNothing);
    expect(find.text('Weekend plans'), findsOneWidget);
    expect(find.text('대화하기'), findsOneWidget);
    final Finder inputCard = find.byKey(
      const ValueKey<String>('topic-input-card'),
    );
    final Finder examplesLabel = find.text('빠르게 골라주세요');
    expect(tester.getSize(inputCard).height, 80);
    expect(
      tester.getTopLeft(examplesLabel).dy - tester.getBottomLeft(inputCard).dy,
      56,
    );
    expect(tester.widget<Text>(examplesLabel).textAlign, TextAlign.center);
    expect(
      (tester.widget<Container>(inputCard).decoration as BoxDecoration).color,
      const Color(0xFFF6F4EB),
    );
    expect(find.byType(GridView), findsOneWidget);
    final GridView grid = tester.widget<GridView>(find.byType(GridView));
    final SliverGridDelegateWithFixedCrossAxisCount delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.mainAxisExtent, 76);
    expect(
      tester.widget<Text>(find.text('Weekend plans')).textAlign,
      TextAlign.center,
    );
  });
}

Widget _routerApp({
  LearningLanguageCode nativeLanguage = LearningLanguageCode.en,
  Locale? locale,
}) {
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
            body: Text('Prepared ${state.uri.queryParameters['topic']}'),
          );
        },
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      topicStarterNativeLanguageProvider.overrideWithValue(nativeLanguage),
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
