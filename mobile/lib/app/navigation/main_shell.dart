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
  bool _nicknameDialogOpen = false;
  String? _nicknameDialogUserId;

  void _openNicknameDialog(String userId) {
    if (_nicknameDialogOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final user = ref.read(authControllerProvider).value?.user;
      if (_nicknameDialogOpen || user?.id != userId || user?.nickname != null) {
        return;
      }
      _nicknameDialogOpen = true;
      _nicknameDialogUserId = userId;
      try {
        await showNicknameDialog(context, requiredSetup: true);
      } finally {
        _nicknameDialogOpen = false;
        _nicknameDialogUserId = null;
      }
    });
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
    final user = ref.watch(authControllerProvider).value?.user;
    if (user != null && user.nickname == null) {
      _openNicknameDialog(user.id);
    }
    ref.listen(authControllerProvider, (_, next) {
      if (_nicknameDialogOpen &&
          next.value?.user?.id != _nicknameDialogUserId &&
          mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
    return ListenableBuilder(
      listenable: GoRouter.of(context).routerDelegate,
      builder: (context, _) => MainTabScope(
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
      ),
    );
  }
}
