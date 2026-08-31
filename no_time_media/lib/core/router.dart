import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:no_time_media/core/app_shell.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/features/draft_history/draft_history_screen.dart';
import 'package:no_time_media/features/photo_scan/photo_scan_screen.dart';
import 'package:no_time_media/features/post_editor/post_editor_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/scan',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
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
      parentNavigatorKey: _rootNavigatorKey,
      path: '/editor',
      builder: (context, state) {
        final extra = state.extra;
        final drafts = extra is List<PostDraft>
            ? extra
            : extra is List
                ? extra.whereType<PostDraft>().toList()
                : <PostDraft>[];
        return PostEditorScreen(drafts: drafts);
      },
    ),
    GoRoute(
      path: '/',
      redirect: (context, state) => '/scan',
    ),
  ],
);
