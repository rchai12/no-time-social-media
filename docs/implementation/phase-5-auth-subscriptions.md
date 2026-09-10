# Phase 5 — Auth, Subscriptions & Usage Enforcement

**Depends on:** Phase 4 complete.
**Spec references:** `docs/features/05-subscription.md`, `docs/api/backend-api.md`, `docs/architecture/data-models.md`.

Read all three before starting.

---

## Overview

Phase 5 has four parallel tracks that must be completed in the order below because each track depends on the one before it.

```
Track A: Database (correct schema + trigger)
    ↓
Track B: Edge Functions (JWT check + usage enforcement + webhook)
    ↓
Track C: Flutter Auth (sign-in/sign-up + session guard)
    ↓
Track D: Flutter Subscription (RevenueCat + paywall + usage gating)
```

---

## Track A — Database Migration

### A1 — Replace the broken migration

`supabase/migrations/001_create_subscriptions_and_usage_tables.sql` contains a Stripe-style schema that does not match the spec. Create a new migration to drop and replace it.

**File:** `supabase/migrations/002_correct_schema.sql`

```sql
-- Drop incorrect tables from migration 001 (if they exist)
DROP TABLE IF EXISTS public.usage_daily CASCADE;
DROP TABLE IF EXISTS public.subscriptions CASCADE;

-- ─── subscriptions ───────────────────────────────────────────────────────────
CREATE TABLE public.subscriptions (
  user_id    UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier       TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  expires_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create a free-tier row for every new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.subscriptions (user_id) VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ─── usage_daily ─────────────────────────────────────────────────────────────
CREATE TABLE public.usage_daily (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date    DATE NOT NULL DEFAULT CURRENT_DATE,
  count   INT  NOT NULL DEFAULT 0 CHECK (count >= 0),
  PRIMARY KEY (user_id, date)
);

-- ─── RLS ─────────────────────────────────────────────────────────────────────
-- Edge Functions use service_role key (bypasses RLS).
-- Flutter client must never query these tables directly.
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usage_daily   ENABLE ROW LEVEL SECURITY;
-- No policies — service_role only.
```

Apply with:
```bash
supabase db push
```

---

## Track B — Edge Functions

### B1 — Fix the shared Supabase client

**File:** `supabase/functions/_shared/supabaseClient.ts`

The current file uses `SUPABASE_ANON_KEY`. Edge Functions that query `subscriptions` and `usage_daily` (RLS-protected) need the service_role key. Replace the file:

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// Service-role client — bypasses RLS. Only used inside Edge Functions.
export const supabaseAdmin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } }
);
```

`SUPABASE_SERVICE_ROLE_KEY` is automatically injected by Supabase into every Edge Function — no manual secrets needed.

### B2 — Upgrade `generate-post` with JWT verification and usage enforcement

**File:** `supabase/functions/generate-post/index.ts`

Add the following logic **before** the AI call (insert at the top of the `try` block, after parsing the request body). The existing AI routing and response logic stays intact.

#### Step B2a — Extract and verify JWT

```typescript
import { supabaseAdmin } from "../_shared/supabaseClient.ts";

// Inside Deno.serve handler, before AI call:
const authHeader = req.headers.get("Authorization");
if (!authHeader?.startsWith("Bearer ")) {
  return new Response(JSON.stringify({ error: "unauthorized" }), {
    status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
const token = authHeader.replace("Bearer ", "");
const { data: { user }, error: authError } = await supabaseAdmin.auth.getUser(token);
if (authError || !user) {
  return new Response(JSON.stringify({ error: "unauthorized" }), {
    status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
const userId = user.id;
```

#### Step B2b — Fetch subscription tier

```typescript
const { data: sub } = await supabaseAdmin
  .from("subscriptions")
  .select("tier")
  .eq("user_id", userId)
  .maybeSingle();

const tier = sub?.tier ?? "free";
const isPro = tier === "pro";
const limit = isPro ? 20 : 3;
```

#### Step B2c — Check usage (daily for Pro, monthly for Free)

```typescript
let currentUsage = 0;

if (isPro) {
  // Pro: daily limit
  const today = new Date().toISOString().substring(0, 10);
  const { data: usage } = await supabaseAdmin
    .from("usage_daily")
    .select("count")
    .eq("user_id", userId)
    .eq("date", today)
    .maybeSingle();
  currentUsage = usage?.count ?? 0;
} else {
  // Free: monthly limit — sum all rows for the current calendar month
  const firstOfMonth = new Date();
  firstOfMonth.setUTCDate(1);
  const firstOfMonthStr = firstOfMonth.toISOString().substring(0, 10);

  const { data: rows } = await supabaseAdmin
    .from("usage_daily")
    .select("count")
    .eq("user_id", userId)
    .gte("date", firstOfMonthStr);

  currentUsage = (rows ?? []).reduce((sum, r) => sum + (r.count ?? 0), 0);
}
```

#### Step B2d — Enforce limit

```typescript
if (currentUsage >= limit) {
  if (isPro) {
    const tomorrow = new Date();
    tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
    tomorrow.setUTCHours(0, 0, 0, 0);
    return new Response(
      JSON.stringify({
        error: "daily_limit_reached",
        limit,
        resets_at: tomorrow.toISOString(),
      }),
      { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } else {
    return new Response(
      JSON.stringify({ error: "subscription_required" }),
      { status: 402, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}
```

#### Step B2e — Atomic increment (after limit check, before AI call)

```typescript
const today = new Date().toISOString().substring(0, 10);
await supabaseAdmin.rpc("increment_usage", { p_user_id: userId, p_date: today });
```

Create this as a Postgres function to keep the upsert atomic. Add to the migration or as a separate migration:

```sql
-- supabase/migrations/003_increment_usage_fn.sql
CREATE OR REPLACE FUNCTION public.increment_usage(p_user_id UUID, p_date DATE)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO public.usage_daily (user_id, date, count)
  VALUES (p_user_id, p_date, 1)
  ON CONFLICT (user_id, date)
  DO UPDATE SET count = usage_daily.count + 1;
$$;
```

### B3 — Create `revenuecat-webhook` Edge Function

**File:** `supabase/functions/revenuecat-webhook/index.ts`

```typescript
import { supabaseAdmin } from "../_shared/supabaseClient.ts";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // 1. Verify RevenueCat webhook signature
  const signature  = req.headers.get("X-RevenueCat-Signature") ?? "";
  const rawBody    = await req.text();
  const secret     = Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "";

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sigBytes  = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  const expected  = Array.from(new Uint8Array(sigBytes))
    .map(b => b.toString(16).padStart(2, "0")).join("");

  if (signature !== expected) {
    return new Response("Unauthorized", { status: 401 });
  }

  // 2. Parse event
  const payload = JSON.parse(rawBody);
  const event   = payload?.event;
  if (!event) return new Response("{}", { status: 200 });

  const userId      = event.app_user_id as string;
  const eventType   = event.type as string;
  const expiresAtMs = event.expiration_at_ms as number | undefined;
  const expiresAt   = expiresAtMs ? new Date(expiresAtMs).toISOString() : null;

  // 3. Update subscriptions table
  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
      await supabaseAdmin.from("subscriptions").upsert({
        user_id:    userId,
        tier:       "pro",
        expires_at: expiresAt,
        updated_at: new Date().toISOString(),
      });
      break;

    case "EXPIRATION":
      await supabaseAdmin.from("subscriptions").upsert({
        user_id:    userId,
        tier:       "free",
        expires_at: null,
        updated_at: new Date().toISOString(),
      });
      break;

    case "CANCELLATION":
    case "BILLING_ISSUE":
      // No tier change — access continues until EXPIRATION
      console.log(`RevenueCat event ${eventType} for user ${userId} — no action`);
      break;

    default:
      console.log(`Unhandled RevenueCat event: ${eventType}`);
  }

  // Always return 200 — RevenueCat retries on non-2xx
  return new Response("{}", {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
```

Set the secret:
```bash
supabase secrets set REVENUECAT_WEBHOOK_SECRET=<your-secret>
```

Configure the webhook URL in the RevenueCat dashboard:
```
https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
```

Deploy both functions:
```bash
supabase functions deploy generate-post
supabase functions deploy revenuecat-webhook
```

---

## Track C — Flutter Auth

### C1 — Uncomment `purchases_flutter` in pubspec.yaml

Find the commented-out line:
```yaml
# purchases_flutter: ^7.1.0
```

Replace with:
```yaml
purchases_flutter: ^7.1.0
```

Run `flutter pub get`.

### C2 — Create `GoRouterRefreshStream` helper

**File:** `no_time_media/lib/core/utils/go_router_refresh_stream.dart`

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

### C3 — Add auth guard to `router.dart`

Update `no_time_media/lib/core/router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/utils/go_router_refresh_stream.dart';
import 'package:no_time_media/core/widgets/app_shell.dart';
import 'package:no_time_media/features/auth/auth_screen.dart';
import 'package:no_time_media/features/draft_history/draft_history_screen.dart';
import 'package:no_time_media/features/photo_scan/photo_scan_screen.dart';
import 'package:no_time_media/features/post_editor/post_editor_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/scan',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final isSignedIn = Supabase.instance.client.auth.currentUser != null;
    final isOnAuth   = state.matchedLocation == '/auth';

    if (!isSignedIn && !isOnAuth) return '/auth';
    if (isSignedIn  && isOnAuth)  return '/scan';
    return null;
  },
  routes: [
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/scan',
          builder: (context, state) => const PhotoScanScreen(),
        ),
        GoRoute(
          path: '/drafts',
          builder: (context, state) => const DraftHistoryScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/editor',
      builder: (context, state) {
        final drafts = state.extra as List<PostDraft>;
        return PostEditorScreen(drafts: drafts);
      },
    ),
  ],
);
```

### C4 — Create `AuthScreen`

**File:** `no_time_media/lib/features/auth/auth_screen.dart`

`AuthScreen` is a `StatefulWidget` with two tabs: Sign In and Sign Up. Use `DefaultTabController`.

**Layout:**

```
AppBar: "No Time Media"
TabBar: [Sign In] [Sign Up]
TabBarView:
  ── Sign In tab ──
    Email TextField
    Password TextField (obscured, with show/hide toggle)
    [Sign In] button (full width)
    [Forgot password?] text button → calls resetPasswordForEmail()
    Loading indicator overlaid while request is in-flight

  ── Sign Up tab ──
    Email TextField
    Password TextField (obscured, min 8 chars)
    Confirm Password TextField
    [Create Account] button (full width)
    Loading indicator

Error banner at top (red) when Supabase returns an AuthException
```

**Auth calls (use `Supabase.instance.client.auth`):**

```dart
// Sign in
await supabase.auth.signInWithPassword(email: email, password: password);

// Sign up
await supabase.auth.signUp(email: email, password: password);

// Reset password
await supabase.auth.resetPasswordForEmail(email);
```

On success, `go_router` redirect fires automatically via `GoRouterRefreshStream` — **do not** call `context.go('/scan')` manually.

On `AuthException`: display `exception.message` in the error banner.

### C5 — Add sign-out to `AppShell`

Add an `IconButton(icon: Icon(Icons.logout))` to the `AppBar` inside `AppShell`:

```dart
onPressed: () async {
  await Supabase.instance.client.auth.signOut();
  // go_router redirect fires automatically
},
```

---

## Track D — Flutter Subscription

### D1 — Create `SubscriptionException`

**File:** `no_time_media/lib/core/models/subscription_exception.dart`

```dart
enum SubscriptionErrorType { requiresUpgrade, dailyLimitReached }

class SubscriptionException implements Exception {
  final SubscriptionErrorType type;
  final DateTime? resetsAt;   // only set for dailyLimitReached

  const SubscriptionException(this.type, {this.resetsAt});

  @override
  String toString() => switch (type) {
    SubscriptionErrorType.requiresUpgrade    => 'Monthly generation limit reached',
    SubscriptionErrorType.dailyLimitReached  => 'Daily generation limit reached',
  };
}
```

### D2 — Update `AIService` to throw `SubscriptionException`

**File:** `no_time_media/lib/core/services/ai_service.dart`

In the `generatePosts` method, after `_supabase.functions.invoke(...)`, check the response status before parsing:

`supabase_flutter` surfaces HTTP errors via `FunctionsException`. Check the response status code. If the `functions.invoke` call returns without throwing but `response.data` contains an `error` key, handle it:

```dart
// After invoke:
final body = response.data;
if (body is Map) {
  final error = body['error'] as String?;
  if (error == 'subscription_required') {
    throw const SubscriptionException(SubscriptionErrorType.requiresUpgrade);
  }
  if (error == 'daily_limit_reached') {
    final resetsAt = body['resets_at'] != null
        ? DateTime.parse(body['resets_at'] as String)
        : null;
    throw SubscriptionException(
        SubscriptionErrorType.dailyLimitReached, resetsAt: resetsAt);
  }
}
```

If `supabase_flutter` throws a `FunctionsException` with status 401, rethrow as a plain `Exception('Session expired — please sign in again')`.

### D3 — Handle `SubscriptionException` in `GenerationNotifier`

**File:** `no_time_media/lib/core/providers/generation_provider.dart`

The `generatePosts` catch block already sets `state = AsyncError(e, st)`. No changes needed here — the error propagates up. The screen handles display.

### D4 — Create `SubscriptionService`

**File:** `no_time_media/lib/core/services/subscription_service.dart`

```dart
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
```

### D5 — Initialize RevenueCat in `main.dart`

```dart
import 'package:purchases_flutter/purchases_flutter.dart';

// In main(), after Hive init and before runApp:
const revenueCatKey = String.fromEnvironment('REVENUECAT_KEY');
await Purchases.setLogLevel(LogLevel.debug); // remove for production
final config = PurchasesConfiguration(revenueCatKey);
await Purchases.configure(config);

// Set app user ID once Supabase session is known
final userId = Supabase.instance.client.auth.currentUser?.id;
if (userId != null) {
  await Purchases.logIn(userId);
}
```

Pass the key at build time:
```bash
flutter run --dart-define=REVENUECAT_KEY=appl_xxxxxxxx   # iOS
flutter run --dart-define=REVENUECAT_KEY=goog_xxxxxxxx   # Android
```

Add a listener so RevenueCat switches user identity on sign-in/sign-out. In `AuthScreen`, after a successful sign-in:
```dart
await Purchases.logIn(Supabase.instance.client.auth.currentUser!.id);
```

In `AppShell` sign-out handler:
```dart
await Supabase.instance.client.auth.signOut();
await Purchases.logOut();
```

### D6 — Create `PaywallScreen`

**File:** `no_time_media/lib/features/subscription/paywall_screen.dart`

Shown as a full-screen route (`context.push('/paywall')`) when `GenerationNotifier` error is a `SubscriptionException` with type `requiresUpgrade`.

**Layout** (match `docs/features/05-subscription.md`):

```
AppBar: "← Back"

Body (centred column):
  Logo / illustration
  "Unlock No Time Media Pro"  (title, 22sp)
  ✓ 20 AI post drafts / day
  ✓ Priority AI processing
  ✓ Instagram-optimized captions
  "$7.99 / month"  (price, 18sp)

  [Start Pro Subscription]  ← calls SubscriptionService.purchase()
  [Restore Purchases]       ← calls SubscriptionService.restorePurchases()
  [Not now]                 ← context.pop()

  Subscription terms text (required by App Store):
  "Payment charged to your App Store / Google Play account on confirmation.
   Subscription renews automatically unless cancelled 24 hours before the
   end of the current period."
```

Loading state during purchase: overlay the button with a `CircularProgressIndicator`.
On purchase success: `context.pop()` then re-trigger generation.
On `PurchasesErrorCode.purchaseCancelledError`: silently dismiss.
On other errors: show snackbar with error message.

Add route to `router.dart`:
```dart
GoRoute(
  path: '/paywall',
  builder: (context, state) => const PaywallScreen(),
),
```

### D7 — Create daily limit modal

**Not a screen** — shown as a `showModalBottomSheet` from `PhotoScanScreen` when `GenerationNotifier` error is a `SubscriptionException` with type `dailyLimitReached`.

```dart
void _showDailyLimitSheet(BuildContext context, DateTime? resetsAt) {
  showModalBottomSheet(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_bottom, size: 48),
          const SizedBox(height: 12),
          const Text("You've used all 20 drafts for today.",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          if (resetsAt != null)
            Text("Limit resets at midnight UTC.",
                style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    ),
  );
}
```

### D8 — Wire error handling in `PhotoScanScreen`

Update the `ref.listen` in `PhotoScanScreen.build()` to handle `SubscriptionException`:

```dart
ref.listen<AsyncValue<List<PostDraft>>>(generationProvider, (prev, next) {
  next.whenOrNull(
    data: (drafts) {
      if (drafts.isNotEmpty) context.push('/editor', extra: drafts);
    },
    error: (e, _) {
      if (e is SubscriptionException) {
        switch (e.type) {
          case SubscriptionErrorType.requiresUpgrade:
            context.push('/paywall');
          case SubscriptionErrorType.dailyLimitReached:
            _showDailyLimitSheet(context, e.resetsAt);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generation failed: $e')),
        );
      }
    },
  );
});
```

Also move the navigation from the FAB `onPressed` into this listener — the FAB should only call `generatePosts`, not navigate directly.

---

## File structure after Phase 5

```
lib/
  core/
    models/
      subscription_exception.dart   ← NEW (D1)
    services/
      subscription_service.dart     ← NEW (D4)
    utils/
      go_router_refresh_stream.dart ← NEW (C2)
    router.dart                     ← updated (C3)
  features/
    auth/
      auth_screen.dart              ← NEW (C4)
    subscription/
      paywall_screen.dart           ← NEW (D6)
  main.dart                         ← updated (D5)

supabase/
  functions/
    _shared/
      supabaseClient.ts             ← updated (B1)
    generate-post/
      index.ts                      ← updated (B2)
    revenuecat-webhook/
      index.ts                      ← NEW (B3)
  migrations/
    001_create_subscriptions_...sql  ← leave as-is (superseded)
    002_correct_schema.sql           ← NEW (A1)
    003_increment_usage_fn.sql       ← NEW (B2e)
```

---

## Build sequence

1. Apply DB migrations: `supabase db push`
2. Deploy Edge Functions: `supabase functions deploy generate-post && supabase functions deploy revenuecat-webhook`
3. Uncomment `purchases_flutter` in `pubspec.yaml`, run `flutter pub get`
4. Create utils, models, services (C2, D1, D4)
5. Update `router.dart` with auth guard (C3)
6. Create `AuthScreen` (C4)
7. Update `AppShell` with sign-out (C5)
8. Update `AIService` for subscription errors (D2)
9. Create `PaywallScreen` (D6)
10. Update `PhotoScanScreen` listener (D8)
11. Update `main.dart` with RevenueCat init (D5)
12. Run `flutter analyze` — fix all errors
13. Test sign-up → auto-creates free subscription row (check Supabase dashboard)
14. Test generation → Edge Function checks JWT and usage
15. Test paywall flow → 402 → `/paywall` → purchase → generation succeeds

---

## Verification checklist

- [ ] Unauthenticated launch → `/auth` screen, not `/scan`
- [ ] Sign up → `subscriptions` row auto-created with `tier = 'free'`
- [ ] Sign in → redirected to `/scan` automatically
- [ ] Sign out → redirected to `/auth` automatically
- [ ] Edge Function rejects requests with no/invalid JWT (test with curl)
- [ ] Free tier: 4th generation attempt in a month → 402 → PaywallScreen
- [ ] Pro tier: 21st generation attempt in a day → 429 → daily limit sheet
- [ ] RevenueCat purchase → webhook → `subscriptions.tier` set to `'pro'`
- [ ] `flutter analyze` reports no errors

---

## What is NOT in scope for Phase 5

- Social login (Google / Apple) — post-v1
- Email verification flow — post-v1
- Forgot password UI — add as stretch goal only
- Settings screen with subscription management — post-v1
- Analytics / crash reporting — post-v1
