import 'package:go_router/go_router.dart';
import 'package:no_time_media/features/photo_scan/photo_scan_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const PhotoScanScreen(),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const PhotoScanScreen(),
    ),
  ],
);