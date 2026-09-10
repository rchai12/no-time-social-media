import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_time_media/features/auth/auth_screen.dart';
import 'package:no_time_media/core/models/subscription_exception.dart';

void main() {
  testWidgets('Auth screen shows sign in and sign up tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    expect(find.text('No Time Media'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Sign Up'), findsOneWidget);
  });

  test('SubscriptionException messages match spec', () {
    expect(
      const SubscriptionException(SubscriptionErrorType.requiresUpgrade)
          .toString(),
      'Monthly generation limit reached',
    );
    expect(
      const SubscriptionException(SubscriptionErrorType.dailyLimitReached)
          .toString(),
      'Daily generation limit reached',
    );
  });
}
