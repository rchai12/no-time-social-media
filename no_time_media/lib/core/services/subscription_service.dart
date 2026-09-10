import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static Future<bool> isPro() async {
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey('pro');
  }

  static Future<void> purchase() async {
    final offerings = await Purchases.getOfferings();
    final monthly = offerings.current?.monthly;
    if (monthly == null) throw Exception('No offering available');
    await Purchases.purchasePackage(monthly);
  }

  static Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}
