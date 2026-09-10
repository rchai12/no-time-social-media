import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/utils/go_router_refresh_stream.dart';
import 'package:no_time_media/core/widgets/app_shell.dart';
import 'package:no_time_media/features/auth/auth_screen.dart';
import 'package:no_time_media/features/draft_history/draft_history_screen.dart';
import 'package:no_time_media/features/photo_scan/photo_scan_screen.dart';
import 'package:no_time_media/features/post_editor/post_editor_screen.dart';
import 'package:no_time_media/features/settings/settings_screen.dart';
import 'package:no_time_media/features/subscription/paywall_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/scan',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final isSignedIn = Supabase.instance.client.auth.currentUser != null;
    final isOnAuth = state.matchedLocation == '/auth';

    if (!isSignedIn && !isOnAuth) return '/auth';
    if (isSignedIn && isOnAuth) return '/scan';
    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/scan',
          builder: (context, state) => const PhotoScanScreen(),
        ),
        GoRoute(
          path: '/drafts',
          builder: (context, state) => const DraftHistoryScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/editor',
      builder: (context, state) {
        final drafts = state.extra as List<PostDraft>;
        return PostEditorScreen(drafts: drafts);
      },
    ),
    GoRoute(
      path: '/paywall',
      builder: (context, state) => const PaywallScreen(),
    ),
  ],
);
