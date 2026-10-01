import 'package:curitalk/core/widgets/main_navigation_bar.dart';
import 'package:curitalk/core/widgets/main_tab_scope.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatefulWidget {
  const MainShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _controllers = List.generate(3, (_) => ScrollController());
  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
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
