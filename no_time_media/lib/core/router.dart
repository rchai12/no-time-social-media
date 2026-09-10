import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/services/prefs_service.dart';
import 'package:no_time_media/core/utils/go_router_refresh_stream.dart';
import 'package:no_time_media/core/widgets/app_shell.dart';
import 'package:no_time_media/features/auth/auth_screen.dart';
import 'package:no_time_media/features/draft_history/draft_history_screen.dart';
import 'package:no_time_media/features/legal/privacy_policy_screen.dart';
import 'package:no_time_media/features/legal/terms_screen.dart';
import 'package:no_time_media/features/onboarding/onboarding_screen.dart';
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
    final onboardingSeen = PrefsService.onboardingSeen;
    final location = state.matchedLocation;

    // First launch: show onboarding before anything else
    if (!onboardingSeen && location != '/onboarding') return '/onboarding';

    // Auth guard
    if (!isSignedIn && location != '/auth' && location != '/onboarding') {
      return '/auth';
    }
    if (isSignedIn && location == '/auth') return '/scan';

    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
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
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsScreen(),
    ),
  ],
);
