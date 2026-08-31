import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = location == '/drafts' ? 1 : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/scan');
          if (i == 1) context.go('/drafts');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.drafts), label: 'Drafts'),
        ],
      ),
    );
  }
}
