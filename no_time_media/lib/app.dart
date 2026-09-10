import 'package:flutter/material.dart';
import 'core/router.dart' as router;

class NoTimeMediaApp extends StatelessWidget {
  const NoTimeMediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'No Time Media',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: router.appRouter,
    );
  }
}
