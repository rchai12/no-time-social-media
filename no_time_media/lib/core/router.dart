import 'package:go_router/go_router.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/widgets/app_shell.dart';
import 'package:no_time_media/features/draft_history/draft_history_screen.dart';
import 'package:no_time_media/features/photo_scan/photo_scan_screen.dart';
import 'package:no_time_media/features/post_editor/post_editor_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/scan',
  routes: [
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
      ],
    ),
    GoRoute(
      path: '/editor',
      builder: (context, state) {
        final drafts = state.extra as List<PostDraft>;
        return PostEditorScreen(drafts: drafts);
      },
    ),
  ],
);
