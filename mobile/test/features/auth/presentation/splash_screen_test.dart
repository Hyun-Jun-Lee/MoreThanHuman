import 'dart:async';

import 'package:curitalk/app/router/app_router.dart';
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

  testWidgets('splash shows only the supplied image while restoring session', (
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
    await tester.pump();

    final Image image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as AssetImage).assetName,
      'assets/images/splash/toma_talk.png',
    );
    expect(find.byType(Text), findsNothing);
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
    expect(find.byType(Text), findsNothing);
  });
}
