import 'package:curitalk/core/notifications/badge_sync_controller.dart';
import 'package:curitalk/core/notifications/badge_choice_dialog.dart';
import 'package:curitalk/core/copy/copy.dart';
import 'package:curitalk/features/auth/auth.dart';
import 'package:curitalk/features/profile/presentation/nickname_dialog.dart';
import 'package:curitalk/core/widgets/main_navigation_bar.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _controllers = List.generate(2, (_) => ScrollController());
  bool _setupOpen = false;
  String? _setupAccount;
  String? _handledAccount;
  bool _dialogOpen = false;

  String? get _account {
    final session = ref.read(authControllerProvider).value;
    return session?.user == null
        ? null
        : '${session!.user!.id}:${session.status.name}';
  }

  bool get _homeVisible =>
      widget.navigationShell.currentIndex == 0 &&
      GoRouter.of(context).routerDelegate.currentConfiguration.uri.path ==
          '/home';

  void _scheduleHomeSetup() {
    final account = _account;
    if (account == null ||
        _setupOpen ||
        widget.navigationShell.currentIndex != 0 ||
        _handledAccount == account) {
      return;
    }
    _setupOpen = true;
    _setupAccount = account;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted || _account != account || !_homeVisible) return;
        final user = ref.read(authControllerProvider).value!.user!;
        final controller = ref.read(aiConsentControllerProvider.notifier);
        if (ref.read(handledAINoticeProvider) != user.id) {
          final status = await controller.load();
          if (!mounted || _account != account || !_homeVisible) return;
          if (!status.accepted || !status.noticeAcknowledged) {
            _dialogOpen = true;
            try {
              await showAIConsentNotice(
                context,
                load: controller.load,
                initialStatus: status,
                onChoice: (notice, acceptAI) async {
                  if (_account != account) throw StateError('Account changed.');
                  final result = await controller.recordChoice(
                    notice,
                    acceptAI: acceptAI,
                  );
                  if (!mounted || _account != account) {
                    throw StateError('Account changed.');
                  }
                  return result.accepted;
                },
              );
            } finally {
              _dialogOpen = false;
            }
          }
        }
        if (!mounted || _account != account || !_homeVisible) return;
        _handledAccount = account;
        await _showRequiredNickname(account);
        if (!mounted || _account != account || !_homeVisible) return;
        final eligible = ref.read(authControllerProvider).value;
        if (eligible?.isMember == true &&
            eligible?.user?.nickname != null &&
            await ref.read(badgeSyncControllerProvider).needsChoice()) {
          if (!mounted || _account != account || !_homeVisible) return;
          _dialogOpen = true;
          try {
            await showBadgeChoice(context, ref);
          } finally {
            _dialogOpen = false;
          }
        }
      } catch (_) {
        if (mounted && _account == account) {
          _handledAccount = account;
          final copy = AppCopy.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(copy.aiConsentSaveFailed),
              action: SnackBarAction(
                label: copy.retryLabel,
                onPressed: () {
                  setState(() => _handledAccount = null);
                },
              ),
            ),
          );
          await _showRequiredNickname(account);
        }
      } finally {
        _setupOpen = false;
        _setupAccount = null;
        if (mounted && _homeVisible) setState(() {});
      }
    });
  }

  Future<void> _showRequiredNickname(String account) async {
    if (!mounted || _account != account || !_homeVisible) return;
    final user = ref.read(authControllerProvider).value?.user;
    if (user == null || user.isGuest || user.nickname != null) return;
    _dialogOpen = true;
    try {
      await showNicknameDialog(context, requiredSetup: true);
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (_, next) {
      if (_account != _setupAccount && _setupOpen && mounted && _dialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (_account != _handledAccount) {
        _handledAccount = null;
        ref.read(handledAINoticeProvider.notifier).mark('');
      }
    });
    return ListenableBuilder(
      listenable: GoRouter.of(context).routerDelegate,
      builder: (context, _) {
        _scheduleHomeSetup();
        return MainTabScope(
          index:
              GoRouter.of(context).routerDelegate.currentConfiguration.last
                  is ShellRouteMatch
              ? widget.navigationShell.currentIndex
              : -1,
          controllers: _controllers,
          child: Scaffold(
            body: widget.navigationShell,
            bottomNavigationBar: MainNavigationBar(
              destination: MainNavigationDestination
                  .values[widget.navigationShell.currentIndex],
              onDestinationSelected: (destination) {
                if (destination == MainNavigationDestination.profile &&
                    ref.read(authControllerProvider).value?.isGuest == true) {
                  context.go('/login');
                  return;
                }
                final repeated =
                    destination.index == widget.navigationShell.currentIndex;
                widget.navigationShell.goBranch(
                  destination.index,
                  initialLocation: repeated,
                );
                if (repeated && _controllers[destination.index].hasClients) {
                  _controllers[destination.index].jumpTo(0);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
