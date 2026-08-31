import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/router.dart' as router;

void main() {
  runApp(const NoTimeMediaApp());
}

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