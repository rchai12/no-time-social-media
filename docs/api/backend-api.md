# Backend API — Supabase Edge Functions

## Base URL

```
https://<project-ref>.supabase.co/functions/v1/
```

All endpoints require a valid Supabase JWT in the `Authorization: Bearer <token>` header.

---

## POST /generate-post

Generates AI post prototypes for the provided photos.

### Request

```
POST /functions/v1/generate-post
Authorization: Bearer <supabase_jwt>
Content-Type: application/json
```

```json
{
  "userId": "uuid",
  "photos": [
    {
      "assetId": "string",
      "thumbnailBase64": "string",
      "compositeScore": 0.87,
      "dateTaken": "2026-08-30T14:23:00Z"
    }
  ],
  "targetPlatform": "instagram"
}
```

**Constraints:**
- `photos` array: 1–20 items
- `thumbnailBase64`: JPEG, 256×256 px, base64-encoded
- `targetPlatform`: must be `"instagram"` in v1

### Success Response `200 OK`

```json
{
  "selectedPhotos": [
    {
      "assetId": "string",
      "caption": "string",
      "hashtags": ["string", "string", "string", "string", "string"],
      "bestPlatform": "instagram",
      "engagementRationale": "string"
    }
  ]
}
```

### Error Responses

| Status | Body | Cause |
|---|---|---|
| 400 | `{ "error": "invalid_request", "detail": "..." }` | Malformed request |
| 401 | `{ "error": "unauthorized" }` | Missing/invalid JWT |
| 402 | `{ "error": "subscription_required" }` | Free tier with no remaining monthly generations |
| 429 | `{ "error": "daily_limit_reached", "limit": 20, "resets_at": "2026-09-01T00:00:00Z" }` | Pro tier daily limit hit |
| 500 | `{ "error": "ai_error", "detail": "..." }` | AI provider failure after retry |

### Edge Function Logic (pseudocode)

```
1. Validate JWT
2. Validate request body
3. Fetch user tier from subscriptions table
4. Fetch today's usage from usage_daily table
5. If usage >= limit → return 429 (or 402 for free tier)
6. Atomically increment usage counter
7. Build system prompt for targetPlatform
8. Route to active AI provider
9. Parse and validate AI response JSON
10. On parse failure: retry once
11. Return GenerationResponse or error
```

---

## POST /revenuecat-webhook

Receives purchase events from RevenueCat to sync subscription state.

### Request

```
POST /functions/v1/revenuecat-webhook
Content-Type: application/json
X-RevenueCat-Signature: <hmac-sha256>
```

```json
{
  "event": {
    "type": "INITIAL_PURCHASE",
    "app_user_id": "<supabase_user_id>",
    "expiration_at_ms": 1759363200000
  }
}
```

### Handled Event Types

| Event Type | Action |
|---|---|
| `INITIAL_PURCHASE` | Set `tier = 'pro'`, update `expires_at` |
| `RENEWAL` | Update `expires_at` |
| `PRODUCT_CHANGE` | Update `tier` accordingly |
| `CANCELLATION` | No immediate action (tier stays pro until `expires_at`) |
| `EXPIRATION` | Set `tier = 'free'`, clear `expires_at` |
| `BILLING_ISSUE` | Log, no tier change until `EXPIRATION` |

### Signature Verification

```typescript
const signature = req.headers.get('X-RevenueCat-Signature');
const body = await req.text();
const expected = await hmacSha256(Deno.env.get('REVENUECAT_WEBHOOK_SECRET')!, body);
if (signature !== expected) return new Response('Unauthorized', { status: 401 });
```

### Response

Always returns `200 OK` with `{}`. RevenueCat retries on non-2xx.

---

## Database Schema (Supabase Postgres)

### `subscriptions`

```sql
CREATE TABLE public.subscriptions (
  user_id     UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tier        TEXT NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  expires_at  TIMESTAMPTZ,
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.subscriptions (user_id) VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
```

### `usage_daily`

```sql
CREATE TABLE public.usage_daily (
  user_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date     DATE NOT NULL DEFAULT CURRENT_DATE,
  count    INT NOT NULL DEFAULT 0 CHECK (count >= 0),
  PRIMARY KEY (user_id, date)
);
```

### Row Level Security

```sql
-- Edge Functions run with service_role key (bypasses RLS)
-- Flutter client should never query these tables directly
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE usage_daily ENABLE ROW LEVEL SECURITY;

-- No RLS policies needed — only service_role (Edge Functions) access these tables
```

---

## Supabase Auth Configuration

- Email + password auth for v1
- Social login (Google, Apple) as future enhancement
- Apple Sign-In required by App Store if any other social login is offered

---

## Local Development

```bash
# Install Supabase CLI
npm install -g supabase

# Start local stack
supabase start

# Serve Edge Functions locally
supabase functions serve generate-post --env-file .env.local

# Run DB migrations
supabase db push
```

`.env.local`:
```
ACTIVE_AI_PROVIDER=claude
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
GOOGLE_API_KEY=...
REVENUECAT_WEBHOOK_SECRET=...
```
