import 'dart:async';

import 'package:curitalk/app/router/app_router.dart';
import 'package:curitalk/app/theme/tokens/tokens.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingAuthController extends AuthController {
  @override
  Future<AuthSession> build() => Completer<AuthSession>().future;
}

class _FailedAuthController extends AuthController {
  @override
  Future<AuthSession> build() =>
      Future<AuthSession>.error(StateError('offline'));
}

class _UnauthenticatedAuthController extends AuthController {
  @override
  Future<AuthSession> build() async => const AuthSession.unauthenticated();
}

class _PendingOnboardingController extends OnboardingController {
  @override
  Future<bool> build() => Completer<bool>().future;
}

class _CompletedOnboardingController extends OnboardingController {
  @override
  Future<bool> build() async => true;
}

void main() {
  testWidgets('routing waits until the splash motion finishes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            _UnauthenticatedAuthController.new,
          ),
          onboardingControllerProvider.overrideWith(
            _CompletedOnboardingController.new,
          ),
        ],
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) =>
              MaterialApp.router(routerConfig: ref.watch(appRouterProvider)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 650));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('splash image presses once and returns to its original size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_PendingAuthController.new),
          onboardingControllerProvider.overrideWith(
            _PendingOnboardingController.new,
          ),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    final ScaleTransition scale = tester.widget<ScaleTransition>(
      find.ancestor(
        of: find.byType(Image),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(scale.scale.value, 1);

    await tester.pump(const Duration(milliseconds: 195));
    expect(scale.scale.value, closeTo(0.96, 0.001));

    await tester.pump(const Duration(milliseconds: 455));
    expect(scale.scale.value, closeTo(1, 0.001));

    await tester.pump(const Duration(seconds: 1));
    expect(scale.scale.value, closeTo(1, 0.001));
  });

  testWidgets('splash image stays still when animations are disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_PendingAuthController.new),
          onboardingControllerProvider.overrideWith(
            _PendingOnboardingController.new,
          ),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SplashScreen(),
          ),
        ),
      ),
    );

    final ScaleTransition scale = tester.widget<ScaleTransition>(
      find.ancestor(
        of: find.byType(Image),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(scale.scale.value, 1);
    await tester.pump(const Duration(milliseconds: 650));
    expect(scale.scale.value, 1);
  });

  testWidgets('splash shows the supplied image and home-matched title', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_PendingAuthController.new),
          onboardingControllerProvider.overrideWith(
            _PendingOnboardingController.new,
          ),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    final Image image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/splash/toma_talk.png',
    );
    final Text title = tester.widget<Text>(find.text('오늘의 토마톡!'));
    expect(title.textAlign, TextAlign.center);
    expect(title.style?.fontFamily, AppTypography.button.fontFamily);
    expect(title.style?.fontSize, AppTypography.button.fontSize);
    expect(title.style?.fontWeight, AppTypography.button.fontWeight);
    expect(find.text('오늘의 토마톡!'), findsOneWidget);
    final Rect brand = tester.getRect(
      find.byKey(const ValueKey('splash-brand-group')),
    );
    final Rect screen = tester.getRect(find.byType(Scaffold));
    expect(brand.center.dx, closeTo(screen.center.dx, 1));
    expect(brand.center.dy, lessThan(screen.center.dy - 75));
    expect(
      tester.getTopLeft(find.text('오늘의 토마톡!')).dy,
      greaterThan(
        tester
            .getBottomLeft(find.byKey(const ValueKey('splash-image-viewport')))
            .dy,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash keeps an icon-only retry action on restore error', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FailedAuthController.new),
          onboardingControllerProvider.overrideWith(
            _PendingOnboardingController.new,
          ),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text('오늘의 토마톡!'), findsOneWidget);
  });
}
