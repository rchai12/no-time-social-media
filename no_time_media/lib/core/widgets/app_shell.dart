import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_time_media/core/providers/photo_scan_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = switch (location) {
      '/drafts' => 1,
      '/settings' => 2,
      _ => 0,
    };
    final title = switch (index) {
      1 => 'Drafts',
      2 => 'Settings',
      _ => 'Select Photos',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (index == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(photoScanProvider),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              try {
                await Purchases.logOut();
              } catch (_) {
                // RevenueCat may be unconfigured in local/dev builds.
              }
            },
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/scan');
          if (i == 1) context.go('/drafts');
          if (i == 2) context.go('/settings');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.drafts), label: 'Drafts'),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
