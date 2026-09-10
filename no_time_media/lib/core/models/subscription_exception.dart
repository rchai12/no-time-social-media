enum SubscriptionErrorType { requiresUpgrade, dailyLimitReached }

class SubscriptionException implements Exception {
  final SubscriptionErrorType type;
  final DateTime? resetsAt;

  const SubscriptionException(this.type, {this.resetsAt});

  @override
  String toString() => switch (type) {
        SubscriptionErrorType.requiresUpgrade =>
          'Monthly generation limit reached',
        SubscriptionErrorType.dailyLimitReached =>
          'Daily generation limit reached',
      };
}
