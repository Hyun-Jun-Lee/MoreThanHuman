import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/presentation/widgets/language_snack_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final type in ['regional_variant', 'usage_contrast', 'homonym']) {
    testWidgets('$type fits 320px and large text with twelve cards', (
      tester,
    ) async {
      tester.view.reset();
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final json = _snackJson(
        id: 'long',
        leftWord: 'crisps',
        rightWord: 'chips',
      );
      if (type != 'regional_variant') {
        json['content_type'] = type;
        json['payload'] = {
          'items': List.generate(
            2,
            (i) => {
              'expression': i == 0 ? 'speak' : 'talk',
              type == 'homonym' ? 'meaning' : 'usage':
                  '표현의 의미와 사용 맥락을 설명하는 문장이에요. ' * 3,
              'example': 'This is an example sentence for the expression. ' * 3,
              'example_translation': '이 표현을 사용한 예문이에요. ' * 3,
            },
          ),
        };
      }
      final snack = LanguageSnack.fromJson(json);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: LanguageSnackCarousel(snacks: List.filled(12, snack)),
              ),
            ),
          ),
        ),
      );
      expect(find.text('1 / 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'shows card content, navigation controls, and advances after five seconds',
    (WidgetTester tester) async {
      await tester.pumpWidget(_app(<LanguageSnack>[_crisps, _flat]));

      expect(find.text('crisps'), findsOneWidget);
      expect(find.text('chips'), findsOneWidget);
      expect(find.byTooltip('Next language snack'), findsOneWidget);
      expect(find.byTooltip('Previous language snack'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));

      expect(find.text('flat'), findsOneWidget);
      expect(find.text('apartment'), findsOneWidget);
    },
  );

  testWidgets('previous, next, and page controls show the selected card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(<LanguageSnack>[_crisps, _flat]));

    await tester.tap(find.byTooltip('Next language snack'));
    await tester.pump();
    expect(find.text('flat'), findsOneWidget);

    await tester.tap(find.byTooltip('Previous language snack'));
    await tester.pump();
    expect(find.text('crisps'), findsOneWidget);

    await tester.tap(find.byTooltip('Show language snack 2'));
    await tester.pump();
    expect(find.text('flat'), findsOneWidget);
  });

  testWidgets(
    'does not auto advance when reduce motion or an inactive lifecycle is active',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(<LanguageSnack>[_crisps, _flat], disableAnimations: true),
      );
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('crisps'), findsOneWidget);

      await tester.pumpWidget(_app(<LanguageSnack>[_crisps, _flat]));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('crisps'), findsOneWidget);
    },
  );

  testWidgets('does not auto advance while a navigation control has focus', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(<LanguageSnack>[_crisps, _flat]));

    await tester.tap(find.byTooltip('Next language snack'));
    await tester.pump();
    expect(find.text('flat'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('flat'), findsOneWidget);
  });

  testWidgets('single snack hides pagination and exposes one semantic card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(<LanguageSnack>[_crisps]));

    expect(find.byTooltip('Next language snack'), findsNothing);
    expect(find.byTooltip('Previous language snack'), findsNothing);
    expect(find.byTooltip('Show language snack 1'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'British English crisps. American English chips. 둘 다 감자칩을 뜻해요.',
      ),
      findsOneWidget,
    );
  });
}

Widget _app(List<LanguageSnack> snacks, {bool disableAnimations = false}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: LanguageSnackCarousel(snacks: snacks)),
    ),
  );
}

final LanguageSnack _crisps = LanguageSnack.fromJson(
  _snackJson(
    id: '550e8400-e29b-41d4-a716-446655440000',
    leftWord: 'crisps',
    rightWord: 'chips',
  ),
);
final LanguageSnack _flat = LanguageSnack.fromJson(
  _snackJson(
    id: '660e8400-e29b-41d4-a716-446655440000',
    leftWord: 'flat',
    rightWord: 'apartment',
  ),
);

Map<String, dynamic> _snackJson({
  required String id,
  required String leftWord,
  required String rightWord,
}) => <String, dynamic>{
  'id': id,
  'content_type': 'regional_variant',
  'schema_version': 1,
  'content_language': 'en',
  'explanation_language': 'ko',
  'payload': {
    'meaning': '둘 다 감자칩을 뜻해요.',
    'items': [
      {'label': 'British English', 'expression': leftWord},
      {'label': 'American English', 'expression': rightWord},
    ],
  },
  'published_at': '2026-09-06T12:00:00Z',
  'created_at': '2026-09-06T12:00:00Z',
  'updated_at': '2026-09-06T12:00:00Z',
};
