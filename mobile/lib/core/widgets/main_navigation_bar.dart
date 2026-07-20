import 'package:flutter/material.dart';

enum MainNavigationDestination { home, chat, history, profile }

class MainNavigationBar extends StatelessWidget {
  const MainNavigationBar({
    required this.destination,
    required this.onDestinationSelected,
    super.key,
  });

  final MainNavigationDestination destination;
  final ValueChanged<MainNavigationDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: destination.index,
      onDestinationSelected: (int index) {
        onDestinationSelected(MainNavigationDestination.values[index]);
      },
      destinations: const <NavigationDestination>[
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_bubble_rounded),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Profile',
        ),
      ],
    );
  }
}
