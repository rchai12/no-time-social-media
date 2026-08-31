# Tech Stack — No Time Media

## Mobile App

### Flutter (Dart)
**Version:** Latest stable (≥3.19)
**Why:** Single codebase for iOS and Android, strong plugin ecosystem for camera/gallery/ML, good performance for image-heavy UI.

### Key Flutter Plugins

| Plugin | Version | Purpose |
|---|---|---|
| `photo_manager` | ≥3.0 | Access device gallery, load AssetEntity, handle permissions |
| `google_mlkit_image_labeling` | ≥0.10 | On-device image labeling for aesthetic + novelty scoring |
| `google_mlkit_face_detection` | ≥0.10 | On-device face detection for face scoring |
| `riverpod` / `flutter_riverpod` | ≥2.5 | State management — use `AsyncNotifierProvider` for AI calls |
| `go_router` | ≥13.0 | Declarative navigation |
| `hive` + `hive_flutter` | ≥2.2 | Local key-value DB for drafts and preferences (replaces Isar — Isar 3.x has Android namespace conflict with AGP ≥8.0) |
| `share_plus` | ≥9.0 | OS native share sheet |
| `supabase_flutter` | ≥2.3 | Supabase client (auth + DB queries) |
| `purchases_flutter` | ≥7.0 | RevenueCat SDK for subscription management |
| `cached_network_image` | ≥3.3 | Thumbnail caching |
| `image` (Dart) | ≥4.1 | Dart image processing for Laplacian sharpness calculation |

## Backend

### Supabase
**Why:** Managed Postgres + Auth + Edge Functions in one service. Eliminates the need to run a separate server. Edge Functions (Deno/TypeScript) proxy AI calls and hold secret API keys.

**Schema overview** (full spec in `/docs/api/backend-api.md`):
- `users` — managed by Supabase Auth
- `subscriptions` — synced from RevenueCat webhooks
- `usage_daily` — generation count per user per UTC date

### Supabase Edge Functions (Deno + TypeScript)
- `generate-post` — receives photo data + platform, routes to configured AI provider, returns structured JSON
- `revenuecat-webhook` — updates `subscriptions` table on purchase/renewal/expiry events

## Payments

### RevenueCat
**Why:** Handles App Store and Google Play subscription complexity, receipt validation, entitlement management, and webhooks — without building all of this from scratch.

**Products:**
- `no_time_media_pro_monthly` — Pro tier, monthly billing

## AI Providers

All calls are made server-side from the Supabase Edge Function. The app never calls AI APIs directly.

| Provider | Model | Notes |
|---|---|---|
| Anthropic Claude | `claude-opus-4-6` | Primary default; best instruction following for structured JSON |
| OpenAI | `gpt-4o` | Alternative; strong vision capabilities |
| Google Gemini | `gemini-1.5-pro` | Alternative; native multimodal, cost-effective |

Active provider is configured in Supabase environment variables (`ACTIVE_AI_PROVIDER`). Changing providers requires no app update.

## Project Structure (Flutter)

```
lib/
  main.dart
  app.dart                    ← MaterialApp + go_router setup
  core/
    models/                   ← Dart data classes (PostDraft, ScoredPhoto, etc.)
    providers/                ← Riverpod providers
    services/
      photo_service.dart      ← photo_manager wrapper
      scoring_service.dart    ← on-device ML scoring pipeline
      ai_service.dart         ← calls Supabase Edge Function
      subscription_service.dart ← RevenueCat + usage check
      share_service.dart      ← share_plus wrapper
    router.dart               ← go_router config
  features/
    photo_scan/               ← screens + widgets for scanning flow
    post_editor/              ← screens + widgets for editing/reviewing posts
    draft_history/            ← draft list screen
    settings/                 ← subscription management, preferences
  l10n/                       ← localization (English only for v1)

assets/
  images/
  fonts/

test/
  unit/
  widget/
  integration/
```

## Code Style & Conventions

- Use `freezed` for immutable data classes (generates `copyWith`, `==`, `hashCode`)
- Use `json_serializable` for JSON encode/decode
- Providers named `<feature>Provider` (e.g., `scoredPhotosProvider`)
- Services are plain Dart classes injected via Riverpod `Provider`
- No direct `BuildContext` usage in services
- All async operations use `AsyncValue` from Riverpod, never raw `FutureBuilder`

## Flutter Project Initialization

```bash
flutter create no_time_media --org com.notimemedia --platforms ios,android
```

Minimum OS targets:
- iOS: 16.0
- Android: API 26 (Android 8.0)
