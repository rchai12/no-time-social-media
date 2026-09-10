import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/services/subscription_service.dart';

final subscriptionProvider = FutureProvider<bool>((ref) async {
  try {
    return await SubscriptionService.isPro();
  } catch (_) {
    return false;
  }
});
