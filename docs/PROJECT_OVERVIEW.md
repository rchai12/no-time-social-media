# No Time Media — Project Overview

## What It Is

No Time Media is a mobile app for iOS and Android that eliminates the most time-consuming part of social media content creation: choosing the right photo and writing a caption worth posting.

The app scans your recent camera roll, automatically scores every photo using on-device machine learning, sends the best candidates to a cloud AI vision model for final curation, and hands you a fully-written, ready-to-post Instagram draft — caption, hashtags, and all — in seconds.

The user's job is reduced to reviewing, tweaking if they want, and tapping Share.

---

## The Problem It Solves

Most people have dozens of great photos sitting on their phone that never get posted — not because the photos aren't good, but because writing a caption is friction. Picking the best shot from a burst, coming up with a hook, finding the right hashtags — it all adds up to time most people don't want to spend.

No Time Media handles the entire pipeline automatically, from raw camera roll to a polished draft, without the user having to think about any of it.

---

## Core Features

### 1 — Automatic Photo Scoring (On-Device)

When the user opens the app, it silently scans the last 10–50 photos from their device gallery and scores each one across four dimensions:

| Dimension | Weight | What it measures |
|---|---|---|
| Recency | 35% | How recently the photo was taken (72-hour window) |
| Aesthetic | 30% | Visual quality — sharpness (Laplacian variance) blended with ML label confidence |
| Novelty | 20% | Subject variety — penalises near-duplicate shots |
| Faces | 15% | Presence and count of people — social content tends to perform better with faces |

Scoring is entirely on-device. No photos leave the phone at this stage.

### 2 — AI-Powered Curation and Post Generation

The top-scoring candidates (up to 20) are sent as 256×256 JPEG thumbnails to a cloud AI vision model. The AI performs two tasks in a single call:

- **Curates**: selects the best 1–4 photos from the candidates based on visual quality, composition, and social media engagement potential
- **Generates**: writes an Instagram caption and 5 relevant hashtags for each selected photo, and explains why it picked that photo

The AI response is structured JSON — no free-form text parsing required. The app receives a list of ready-to-use drafts.

### 3 — Post Editor

Each AI-generated draft is presented in a full-screen editor:

- Full-width photo preview
- Editable caption with 300-character counter and one-tap undo back to the AI version
- Scrollable hashtag chips with an edit sheet for adding, removing, or reordering tags
- Platform badge showing which platform the AI recommends for that photo
- Engagement rationale — a one-sentence explanation from the AI of why it chose this photo
- If multiple photos were curated, the user swipes between them in a PageView

### 4 — Draft History

All saved drafts are stored locally on the device using Hive. The Drafts tab shows a sorted list (newest first) of every saved post with thumbnail preview, truncated caption, and platform badge. Drafts can be re-opened in the editor or swiped to delete. No network required for draft access.

### 5 — Sharing

The Share button triggers the native OS share sheet with the full-resolution photo. The caption and hashtags are simultaneously copied to the clipboard, ready to paste into Instagram (which does not accept text via the share sheet). After sharing, the draft is marked as shared in local history.

### 6 — Subscription Model

| Tier | Price | Generations |
|---|---|---|
| Free | $0 | 3 per month |
| Pro | ~$7.99 / month | 20 per day |

Limits are enforced server-side, not client-side. A paywall screen is shown when the user's generation allowance is exhausted. Subscriptions are managed via RevenueCat, which handles all App Store and Google Play billing complexity.

---

## Architecture

### On-Device (Flutter App)

The app is built in Flutter, running a single Dart codebase on both iOS and Android.

```
Camera Roll
    │
    ▼
photo_manager (gallery access + permissions)
    │
    ▼
On-Device ML Scoring Pipeline
  ├── google_mlkit_image_labeling  → aesthetic + novelty
  ├── google_mlkit_face_detection  → faces score
  └── Dart image package           → Laplacian sharpness
    │
    ▼
Scored + Ranked Photos
    │
    ▼
Subscription Gate (RevenueCat entitlement + Supabase usage counter)
    │
    ▼ (authorized)
Supabase Edge Function (AI Proxy)
    │
    ▼
AI-Generated PostDraft objects
    │
    ├── Post Editor (review + edit)
    └── Hive Local Storage (draft history)
```

### Backend (Supabase)

The backend is entirely Supabase — no custom server required:

- **Postgres** stores subscription state (`subscriptions` table) and per-user daily generation counts (`usage_daily` table)
- **Auth** manages user accounts (email/password)
- **Edge Functions** (Deno/TypeScript) act as a secure proxy between the app and the cloud AI providers. API keys never touch the app binary.

### AI Provider Layer

The Edge Function implements a provider-agnostic router. The active provider is set via a single Supabase environment variable (`ACTIVE_AI_PROVIDER`). Switching AI providers requires no app update and no redeployment:

```bash
supabase secrets set ACTIVE_AI_PROVIDER=claude   # → Anthropic Claude Haiku
supabase secrets set ACTIVE_AI_PROVIDER=gemini   # → Google Gemini 1.5 Flash
supabase secrets set ACTIVE_AI_PROVIDER=openai   # → OpenAI GPT-4o mini
```

All three providers implement the same `AIProvider` TypeScript interface so the Edge Function logic is identical regardless of which model is active.

**Provider selection rationale:**

| Provider | Model | Role |
|---|---|---|
| Gemini 1.5 Flash | Google | Production default — lowest cost per call, strong vision |
| Claude Haiku 4.5 | Anthropic | Alternative — reliable structured JSON output, competitive cost |
| GPT-4o mini | OpenAI | Alternative — strong vision, mid-range cost |

Google AI Studio free tier is used during development and testing only (rate limits too low for production).

### Payments (RevenueCat)

RevenueCat sits between the app and the App Store / Google Play, handling:
- Purchase flow and receipt validation
- Subscription renewals and grace periods
- Webhook events that update the Supabase `subscriptions` table
- Entitlement checking (`pro` entitlement gates 20/day usage)

---

## Technology Stack

### Mobile App

| Layer | Technology | Version |
|---|---|---|
| Framework | Flutter / Dart | ≥3.19 stable |
| Gallery access | `photo_manager` | ≥3.0 |
| On-device ML | `google_mlkit_image_labeling`, `google_mlkit_face_detection` | ≥0.10 |
| Image processing | `image` (Dart) | ≥4.1 |
| State management | `flutter_riverpod` + `riverpod_annotation` | ≥2.5 |
| Navigation | `go_router` | ≥13.0 |
| Local storage | `hive` + `hive_flutter` | ≥2.2 |
| Backend client | `supabase_flutter` | ≥2.3 |
| Subscriptions | `purchases_flutter` (RevenueCat) | ≥7.0 |
| Sharing | `share_plus` | ≥9.0 |
| Code generation | `freezed`, `json_serializable`, `hive_generator` | dev deps |

### Backend

| Layer | Technology |
|---|---|
| Database | Supabase Postgres (managed) |
| Auth | Supabase Auth (email/password) |
| AI proxy | Supabase Edge Functions (Deno + TypeScript) |
| Payments | RevenueCat (webhooks → Supabase) |

### Supported Platforms

- **iOS** — minimum iOS 16.0
- **Android** — minimum API 26 (Android 8.0)

---

## Key Design Decisions

**Privacy first.** Only 256×256 thumbnails are sent to the AI. Full-resolution photos never leave the device. All initial scoring is done on-device via ML Kit.

**Offline-capable drafts.** Generated posts are saved to local Hive storage immediately. The user can browse and edit draft history with no network connection.

**No vendor lock-in.** The AI provider can be swapped in minutes via an environment variable. The `AIProvider` TypeScript interface means adding a new model (e.g., Gemini 2.0, Claude Opus) is a new file, not a refactor.

**Platform-ready architecture.** The codebase contains enum values and prompt variants for Instagram, Twitter/X, Facebook, and TikTok. Only Instagram is active in v1. Activating a new platform is a UI flag and a prompt — no structural changes required.

**Server-side limits.** Usage limits are enforced in the Edge Function with an atomic SQL upsert. Client-side checks are UI-only. A user cannot bypass limits by modifying the app.

---

## Current Development Status

| Phase | Scope | Status |
|---|---|---|
| Phase 1 | Flutter scaffold, routing, project structure | ✅ Complete |
| Phase 2 | Photo scanning, on-device scoring pipeline | ✅ Complete |
| Phase 3 | AI service, Supabase Edge Function, AI provider router | ✅ Complete |
| Phase 4 | Post editor, draft history, share flow, bottom navigation | ✅ Complete |
| Phase 5 | Auth, RevenueCat subscriptions, paywall, usage enforcement | Pending |
