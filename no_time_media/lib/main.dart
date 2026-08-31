import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://pawkqzzucfbgnsxywmyx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInVzZXJfaWQiOiJiOTlmMjQ4OC03NDQ2LTQzODctYjU2NC01MDE5Y2IyMDQ5MDAiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTY5MjUwMDU3NCwiZXhwIjoxOTk3OTkwNTc0fQ.d9l4hXZgF8DmK2WdE7sT1tCp5nOQ7bR9LJrNk8gG6vU',
  );
  
  runApp(
    ProviderScope(
      child: const NoTimeMediaApp(),
    ),
  );
}