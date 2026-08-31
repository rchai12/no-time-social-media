# Feature Spec 05 — Subscription & Paywall

## Purpose

Gate AI generation behind a subscription. Free tier allows 3 generations/month. Pro tier allows up to 20 generations/day. All limits enforced server-side.

## Tiers

| Tier | Price | Generations |
|---|---|---|
| Free | $0 | 3 per month |
| Pro | ~$7.99/month | 20 per day (resets midnight UTC) |

Note: Pricing is a starting suggestion. Adjust before App Store submission.

## RevenueCat Setup

### Product IDs

| Store | Product ID |
|---|---|
| Apple App Store | `no_time_media_pro_monthly` |
| Google Play | `no_time_media_pro_monthly` |

### Entitlement

One entitlement: `pro`

### RevenueCat SDK (Flutter)

```dart
// Initialize in main.dart before runApp
await Purchases.setLogLevel(LogLevel.debug); // disable in prod
await Purchases.configure(
  PurchasesConfiguration(Env.revenueCatKey)
    ..appUserID = supabase.auth.currentUser?.id,
);
```

Map the Supabase user ID to the RevenueCat app user ID for cross-platform entitlement consistency.

## Supabase Schema

### `subscriptions` table

```sql
CREATE TABLE subscriptions (
  user_id     UUID PRIMARY KEY REFERENCES auth.users(id),
  tier        TEXT NOT NULL DEFAULT 'free',   -- 'free' | 'pro'
  expires_at  TIMESTAMPTZ,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);
```

### `usage_daily` table

```sql
CREATE TABLE usage_daily (
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  date        DATE NOT NULL DEFAULT CURRENT_DATE,
  count       INT NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, date)
);
```

### Atomic Usage Increment (in Edge Function)

```sql
INSERT INTO usage_daily (user_id, date, count)
VALUES ($1, CURRENT_DATE, 1)
ON CONFLICT (user_id, date)
DO UPDATE SET count = usage_daily.count + 1
RETURNING count;
```

Check the returned `count` against the tier limit before proceeding. If `count > limit`, the increment has already happened — decrement it back and return 429.

Preferred approach: check first, then increment only if under limit, using a single CTE:

```sql
WITH check AS (
  SELECT COALESCE(
    (SELECT count FROM usage_daily WHERE user_id = $1 AND date = CURRENT_DATE),
    0
  ) AS current_count
),
tier_limit AS (
  SELECT CASE WHEN tier = 'pro' THEN 20 ELSE 3 END AS lim
  FROM subscriptions WHERE user_id = $1
)
INSERT INTO usage_daily (user_id, date, count)
SELECT $1, CURRENT_DATE, 1
FROM check, tier_limit
WHERE check.current_count < tier_limit.lim
ON CONFLICT (user_id, date)
DO UPDATE SET count = usage_daily.count + 1
RETURNING count;
```

If no row is inserted (0 rows returned), the limit was reached — return 429.

## RevenueCat Webhook → Supabase

**Edge Function:** `supabase/functions/revenuecat-webhook/index.ts`

Events handled:
- `INITIAL_PURCHASE` → set `tier = 'pro'`, set `expires_at`
- `RENEWAL` → update `expires_at`
- `CANCELLATION` / `EXPIRATION` → set `tier = 'free'`, clear `expires_at`

Verify webhook signature using RevenueCat's `X-RevenueCat-Signature` header.

## Flutter Subscription Service

```dart
class SubscriptionService {
  Future<UserSubscription> fetchStatus() async {
    // 1. Check RevenueCat entitlement
    final info = await Purchases.getCustomerInfo();
    final isPro = info.entitlements.active.containsKey('pro');

    // 2. Fetch daily usage from Supabase
    final usage = await supabase
      .from('usage_daily')
      .select('count')
      .eq('user_id', supabase.auth.currentUser!.id)
      .eq('date', DateTime.now().toUtc().toIso8601String().substring(0, 10))
      .maybeSingle();

    return UserSubscription(
      tier: isPro ? SubscriptionTier.pro : SubscriptionTier.free,
      dailyGenerationsUsed: usage?['count'] ?? 0,
      dailyGenerationLimit: isPro ? 20 : 3,
      expiresAt: isPro ? info.entitlements.active['pro']!.expirationDate : null,
    );
  }

  Future<void> purchase() async {
    final offerings = await Purchases.getOfferings();
    final monthly = offerings.current?.monthly;
    if (monthly != null) {
      await Purchases.purchasePackage(monthly);
    }
  }

  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}
```

## Paywall Screen

Shown when:
- User taps "Generate Posts" and is on free tier with 0 generations remaining
- User is on Pro and hits the 20/day limit

### Free Tier Paywall

```
┌─────────────────────────────┐
│  Unlock No Time Media Pro   │
│                             │
│  ✓ 20 AI post drafts/day   │
│  ✓ All AI providers         │
│  ✓ Instagram-optimized      │
│                             │
│  $7.99 / month              │
│                             │
│  [Start Pro Subscription]   │
│  [Restore Purchases]        │
│  [Not now]                  │
└─────────────────────────────┘
```

### Daily Limit State (Pro)

Not a full paywall — shown as a modal sheet:

```
You've used your 20 drafts for today.
Your limit resets at midnight UTC.

[OK]
```

## App Store / Play Store Requirements

- Privacy policy URL required (must disclose photo access, AI processing)
- Subscription terms must be displayed on paywall screen
- iOS: `SKPaymentQueue` handled by RevenueCat; no manual StoreKit code
- Android: Billing Library handled by RevenueCat; no manual billing code

## Dependencies

- `purchases_flutter: ^7.0.0` (RevenueCat SDK)
- `supabase_flutter: ^2.3.0`
