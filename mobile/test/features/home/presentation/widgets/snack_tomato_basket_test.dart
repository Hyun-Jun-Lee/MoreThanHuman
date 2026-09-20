import 'dart:io';
import 'dart:ui' as ui;
import 'package:curitalk/app/theme/app_theme.dart';
import 'package:curitalk/features/home/domain/daily_snack_basket.dart';
import 'package:curitalk/features/home/domain/language_snack.dart';
import 'package:curitalk/features/home/presentation/widgets/snack_tomato_basket.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../snack_test_fixtures.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final entry in {
      'Pretendard': 'Pretendard',
      'JetBrains Mono': 'JetBrainsMono',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            rootBundle.load('assets/fonts/${entry.value}Variable.ttf'),
          ))
          .load();
    }
  });
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets('pickup moves and grows without spending a bite at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await _capture(tester, 'pickup-before-${width.toInt()}');
      final bounds = tester.getRect(_touch);
      await tester.tap(_touch);
      await tester.pump();
      expect(find.byKey(const ValueKey('tomato-pickup')), findsOneWidget);
      final initialScale = _pickupScale(tester);
      final initialOffset = _pickupOffset(tester);
      expect(initialScale, closeTo(.42, .001));
      expect(tester.widget<InkWell>(_touch).onTap, isNull);
      await tester.tap(_touch);
      await tester.pump(const Duration(milliseconds: 80));
      expect(_pickupScale(tester), greaterThan(initialScale));
      expect(_pickupOffset(tester), lessThan(initialOffset));
      await _capture(tester, 'pickup-080-${width.toInt()}', settle: false);
      await tester.pump(const Duration(milliseconds: 120));
      expect(_pickupScale(tester), greaterThan(1));
      expect(tester.getRect(_touch), bounds);
      expect(harness.interactions, [true]);
      expect(harness.basket.consumed, 0);
      expect(find.byType(Dialog), findsNothing);
      await _capture(tester, 'pickup-200-${width.toInt()}', settle: false);
      await tester.pump(const Duration(milliseconds: 120));
      await _capture(tester, 'pickup-320-${width.toInt()}', settle: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tomato-pickup')), findsNothing);
      expect(find.byKey(const ValueKey('tomato-stage-0')), findsOneWidget);
      expect(tester.widget<InkWell>(_touch).onTap, isNotNull);
      expect(harness.interactions, [true, false]);
      expect(harness.basket.consumed, 0);
      expect(tester.getRect(_touch), bounds);
      await _capture(tester, 'pickup-finished-${width.toInt()}');
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      expect(harness.basket.consumed, 1);
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion opens immediately without a pickup transition', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app(reducedMotion: true));
    await tester.pumpAndSettle();
    await tester.tap(_touch);
    await tester.pump();
    expect(find.byKey(const ValueKey('tomato-pickup')), findsNothing);
    expect(find.byKey(const ValueKey('tomato-stage-0')), findsOneWidget);
    expect(tester.widget<InkWell>(_touch).onTap, isNotNull);
    expect(harness.basket.consumed, 0);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('leaving during pickup cancels it without spending a bite', (
    tester,
  ) async {
    final harness = _Harness();
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(_touch);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tomato-pickup')), findsOneWidget);
    harness.setState(() => harness.visible = false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(harness.basket.consumed, 0);
    expect(find.byType(Dialog), findsNothing);
    harness.setState(() => harness.visible = true);
    await tester.pumpAndSettle();
    _expectBasket(tester, 3);
  });

  for (final opened in [false, true]) {
    testWidgets('touch background stays unchanged (opened: $opened)', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      if (opened) {
        await tester.tap(_touch);
        await tester.pumpAndSettle();
      }
      final point = tester.getTopLeft(_touch) + const Offset(8, 8);
      final before = await _pixelAt(tester, point);
      final gesture = await tester.startGesture(point);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final pressed = await _pixelAt(tester, point);
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(pressed, before);
    });
  }
  testWidgets(
    'basket opens; twelve bites exhaust it without immediate refill',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tomato-stage-basket')), findsOneWidget);
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      expect(harness.basket.consumed, 0);
      for (var i = 0; i < 12; i++) {
        await tester.tap(_touch);
        await tester.pumpAndSettle();
        expect(harness.basket.consumed, i + 1);
        expect(find.text('word-$i-0'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('${i + 1} / 12'),
          ),
          findsNothing,
        );
        expect(find.text('${i + 1} / 12'), findsOneWidget);
        expect(
          find.byKey(ValueKey('tomato-stage-${i % 4 + 1}')),
          findsOneWidget,
        );
        await tester.tap(_close);
        await tester.pumpAndSettle();
        if ((i + 1) % 4 == 0) {
          final remaining = 3 - (i + 1) ~/ 4;
          _expectBasket(tester, remaining);
          await _capture(tester, 'basket-left-$remaining');
          if (remaining > 0) {
            await tester.tap(_touch);
            await tester.pumpAndSettle();
            expect(harness.basket.consumed, i + 1);
            expect(find.byType(Dialog), findsNothing);
            expect(
              find.byKey(const ValueKey('tomato-stage-0')),
              findsOneWidget,
            );
          }
        }
      }
      expect(harness.basket.consumed, 12);
      _expectBasket(tester, 0);
      expect(find.text('Refills at midnight'), findsOneWidget);
      expect(tester.widget<InkWell>(_touch).onTap, isNull);
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(harness.basket.consumed, 12);
      await _capture(tester, 'exhausted');
    },
  );

  for (final consumed in [0, 4, 8, 12]) {
    testWidgets('restores remaining basket at $consumed bites', (tester) async {
      final harness = _Harness();
      harness.basket = harness.basket.withConsumed(consumed);
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      _expectBasket(tester, 3 - consumed ~/ 4);
      expect(tester.widget<InkWell>(_touch).onTap == null, consumed == 12);
    });
  }

  testWidgets('returning to basket preserves a partially eaten tomato', (
    tester,
  ) async {
    final harness = _Harness();
    harness.basket = harness.basket.withConsumed(5);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tomato-stage-1')), findsOneWidget);
    expect(find.byIcon(Icons.circle), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
    expect(find.bySemanticsLabel('Tomato 2, 3 bites left'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.shopping_basket_outlined));
    await tester.pumpAndSettle();
    _expectBasket(tester, 2);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
    expect(find.text('Language note'), findsNothing);
    expect(find.text('오늘의 언어'), findsNothing);
    await tester.tap(_touch);
    await tester.pumpAndSettle();
    expect(harness.basket.consumed, 5);
    expect(find.byKey(const ValueKey('tomato-stage-1')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets(
    'rapid taps cannot spend multiple bites and no five-second advance',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      await tester.tap(_touch);
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      expect(harness.basket.consumed, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(find.text('word-0-0'), findsOneWidget);
      expect(harness.basket.consumed, 1);
    },
  );

  testWidgets(
    'leaving during animation cancels popup and disposed modal is removed',
    (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.app());
      await tester.pumpAndSettle();
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      await tester.tap(_touch);
      await tester.pump(const Duration(milliseconds: 100));
      harness.setState(() => harness.visible = false);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      expect(harness.basket.consumed, 0);
      harness.setState(() => harness.visible = true);
      await tester.pumpAndSettle();
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      await tester.tap(_touch);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      harness.setState(() => harness.visible = false);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 768.0]) {
    for (final type in ['regional_variant', 'usage_contrast', 'homonym']) {
      testWidgets(
        '$type popup fits $width with large text and reduced motion',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final harness = _Harness(
            snacks: List.generate(
              12,
              (i) => testSnack(i, type: type, long: true),
            ),
          );
          await tester.pumpWidget(
            harness.app(textScale: 2, reducedMotion: true),
          );
          await tester.pumpAndSettle();
          if (width == 390 && type == 'regional_variant') {
            await _capture(tester, 'basket');
          }
          await tester.tap(_touch);
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel('Tomato 1, 4 bites left'),
            findsOneWidget,
          );
          if (width == 390 && type == 'regional_variant') {
            await _capture(tester, 'tomato');
          }
          await tester.tap(_touch);
          await tester.pumpAndSettle();
          expect(find.text('word-0-0'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await _capture(tester, 'popup-$type-${width.toInt()}');
          await tester.tap(_close);
          await tester.pumpAndSettle();
          expect(harness.basket.consumed, 1);
        },
      );
    }
  }
}

final _touch = find.byKey(const ValueKey('snack-tomato-touch'));
final _close = find.byKey(const ValueKey('close-snack'));

double _pickupScale(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('tomato-pickup-scale')))
    .transform
    .entry(0, 0);

double _pickupOffset(WidgetTester tester) => tester
    .widget<Transform>(find.byKey(const ValueKey('tomato-pickup-offset')))
    .transform
    .entry(1, 3);

void _expectBasket(WidgetTester tester, int remaining) {
  expect(find.text('LANGUAGE NOTE'), findsNothing);
  expect(find.text('오늘의 언어'), findsNothing);
  expect(find.byIcon(Icons.check_circle), findsNothing);
  expect(find.byIcon(Icons.circle_outlined), findsNothing);
  final finder = find.byKey(const ValueKey('tomato-stage-basket'));
  expect(finder, findsOneWidget);
  final provider = tester.widget<Image>(finder).image as ResizeImage;
  final asset = provider.imageProvider as AssetImage;
  expect(
    asset.assetName,
    '${SnackTomatoBasket.assetRoot}${remaining == 3 ? 'tomato_basket.png' : 'tomato_basket_leave_$remaining.png'}',
  );
}

class _Harness {
  _Harness({List<LanguageSnack>? snacks})
    : basket = DailySnackBasket(
        day: '2026-09-18',
        snacks: snacks ?? List.generate(12, testSnack),
      );
  DailySnackBasket basket;
  final List<bool> interactions = [];
  bool visible = true;
  late StateSetter setState;
  Widget app({double textScale = 1, bool reducedMotion = false}) =>
      RepaintBoundary(
        key: const ValueKey('capture-screen'),
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reducedMotion,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                setState = update;
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: visible
                        ? SnackTomatoBasket(
                            basket: basket,
                            onInteractionChanged: interactions.add,
                            onBite: () {
                              final snack = basket.snacks[basket.consumed];
                              update(
                                () => basket = basket.withConsumed(
                                  basket.consumed + 1,
                                ),
                              );
                              return snack;
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              },
            ),
          ),
        ),
      );
}

Future<List<int>?> _pixelAt(WidgetTester tester, Offset globalPoint) =>
    tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture-screen')),
      );
      final point = boundary.globalToLocal(globalPoint);
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
      final pixel = List<int>.generate(4, (i) => bytes!.getUint8(offset + i));
      image.dispose();
      return pixel;
    });

Future<void> _capture(
  WidgetTester tester,
  String name, {
  bool settle = true,
}) async {
  final directory = Platform.environment['SNACK_CAPTURE_DIR'];
  if (directory == null) return;
  final context = tester.element(find.byType(SnackTomatoBasket));
  await tester.runAsync(() async {
    for (final file in [
      ...SnackTomatoBasket.stages,
      ...SnackTomatoBasket.basketStages,
    ]) {
      await precacheImage(
        ResizeImage(
          AssetImage('${SnackTomatoBasket.assetRoot}$file'),
          width: 768,
        ),
        context,
      );
    }
  });
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  expect(tester.widget<RawImage>(find.byType(RawImage).first).image, isNotNull);
  final target = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture-screen')),
  );
  await tester.runAsync(() async {
    final image = await target.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
