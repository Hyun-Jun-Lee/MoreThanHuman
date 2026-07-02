import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoute {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefreshNotifier refreshNotifier = _RouterRefreshNotifier(ref);
  final GoRouter router = GoRouter(
    initialLocation: AppRoute.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final AsyncValue<AuthSession> auth = ref.read(authControllerProvider);
      final AsyncValue<bool> onboarding = ref.read(
        onboardingControllerProvider,
      );
      final String location = state.matchedLocation;

      if (auth.isLoading || onboarding.isLoading) {
        final bool isLoginInProgress =
            location == AppRoute.login && onboarding.value == true;
        return isLoginInProgress || location == AppRoute.splash
            ? null
            : AppRoute.splash;
      }

      if (auth.hasError || onboarding.hasError) {
        return location == AppRoute.login || location == AppRoute.splash
            ? null
            : AppRoute.splash;
      }

      if (onboarding.value != true) {
        return location == AppRoute.onboarding ? null : AppRoute.onboarding;
      }

      final bool isAuthenticated = auth.value?.isAuthenticated == true;
      if (!isAuthenticated) {
        return location == AppRoute.login ? null : AppRoute.login;
      }

      final bool isBootstrapRoute =
          location == AppRoute.splash ||
          location == AppRoute.onboarding ||
          location == AppRoute.login;
      return isBootstrapRoute ? AppRoute.home : null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoute.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(onboardingControllerProvider, (_, _) => notifyListeners());
  }
}
