import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_time_media/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('onboarding shows value prop then advances', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    expect(find.text('Your best shot, instantly'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Scan → Curate → Post'), findsOneWidget);
  });
}
