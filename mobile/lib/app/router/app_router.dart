import 'dart:async';
import 'package:curitalk/app/navigation/main_shell.dart';
import 'package:curitalk/features/profile/presentation/profile_screen.dart';
import 'package:curitalk/features/billing/paywall_screen.dart';
import 'package:curitalk/features/history/application/conversation_history_controller.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/conversation/conversation.dart';
import 'package:curitalk/features/history/history.dart';
import 'package:curitalk/features/home/home.dart';
import 'package:curitalk/features/onboarding/onboarding.dart';
import 'package:curitalk/features/roleplay_setup/roleplay_setup.dart';
import 'package:curitalk/features/topic_prep/topic_prep.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoute {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String home = '/home';
  static const String history = '/history';
  static const String profile = '/profile';
  static const String paywall = '/paywall';
  static const String topicInput = '/topic-input';
  static const String topicPrep = '/topic-prep';
  static const String roleplaySetup = '/roleplay-setup';
  static const String conversation = '/conversation';

  static String conversationPath(String conversationId) {
    return '$conversation/${Uri.encodeComponent(conversationId)}';
  }
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
        path: AppRoute.paywall,
        builder: (context, state) => const PaywallScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.home,
                builder: (context, state) => HomeScreen(
                  onConversationSelected: (id) =>
                      context.push(AppRoute.conversationPath(id)),
                  onHistorySelected: () => context.go(AppRoute.history),
                  onProfileSelected: () => context.go(AppRoute.profile),
                  onStartTypeSelected: (type) => _startFlow(context, type),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.history,
                builder: (context, state) => HistoryScreen(
                  onConversationSelected: (id) =>
                      context.push(AppRoute.conversationPath(id)),
                  onStartTypeSelected: (type) => _startFlow(context, type),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoute.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoute.topicInput,
        builder: (context, state) {
          return TopicInputScreen(
            initialTopic: state.uri.queryParameters['topic'],
          );
        },
      ),
      GoRoute(
        path: AppRoute.topicPrep,
        builder: (context, state) {
          final String? topic = state.uri.queryParameters['topic'];
          if (topic == null || topic.trim().isEmpty) {
            return const TopicInputScreen();
          }
          return TopicPrepScreen(initialTopic: topic);
        },
      ),
      GoRoute(
        path: AppRoute.roleplaySetup,
        builder: (context, state) => const RoleplaySetupScreen(),
      ),
      GoRoute(
        path: '${AppRoute.conversation}/:conversationId',
        builder: (context, state) {
          final String? conversationId = state.pathParameters['conversationId'];
          if (conversationId == null || conversationId.trim().isEmpty) {
            return const HomeScreen();
          }
          return PopScope(
            onPopInvokedWithResult: (didPop, _) {
              if (didPop && ref.mounted) _refreshLists(ref);
            },
            child: ConversationScreen(conversationId: conversationId),
          );
        },
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

void _refreshLists(Ref ref) {
  ref.invalidate(recentConversationsControllerProvider);
  ref.invalidate(conversationHistoryControllerProvider);
}

Future<void> _startFlow(
  BuildContext context,
  ConversationStartType type,
) async {
  await context.push(
    type == ConversationStartType.freeChat
        ? AppRoute.topicInput
        : AppRoute.roleplaySetup,
  );
}

/// 완료된 준비 경로만 비우고 출발 탭 위에 대화를 올려요.
void openStartedConversation(BuildContext context, String conversationId) {
  final router = GoRouter.of(context);
  while (router.canPop()) {
    final path =
        router.routerDelegate.currentConfiguration.last.matchedLocation;
    if (!{
      AppRoute.topicInput,
      AppRoute.topicPrep,
      AppRoute.roleplaySetup,
    }.contains(path)) {
      break;
    }
    router.pop();
  }
  final location =
      router.routerDelegate.currentConfiguration.last.matchedLocation;
  if ({
    AppRoute.topicInput,
    AppRoute.topicPrep,
    AppRoute.roleplaySetup,
  }.contains(location)) {
    // 직접 준비 화면을 연 경우에도 돌아갈 목적지를 구성해요.
    router.go(AppRoute.home);
  }
  unawaited(router.push(AppRoute.conversationPath(conversationId)));
}
