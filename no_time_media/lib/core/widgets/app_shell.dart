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
    final index = location == '/drafts' ? 1 : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(index == 1 ? 'Drafts' : 'Select Photos'),
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
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.drafts), label: 'Drafts'),
        ],
      ),
    );
  }
}
