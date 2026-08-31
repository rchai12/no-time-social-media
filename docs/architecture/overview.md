# System Architecture Overview — No Time Media

## Purpose

No Time Media is a Flutter mobile application for iOS and Android. It automates the most time-consuming part of social media content creation: selecting the right photo and writing a compelling, platform-native caption.

## High-Level Flow

```
Device Gallery
     │
     ▼
┌─────────────────────────┐
│  Photo Fetch            │  photo_manager plugin
│  Last 10–50 photos      │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│  On-Device ML Scoring   │  google_mlkit_image_labeling
│  Composite score:       │  google_mlkit_face_detection
│   Recency       35%     │  + Dart sharpness (Laplacian)
│   Aesthetic     30%     │
│   Novelty       20%     │
│   Faces         15%     │
└─────────┬───────────────┘
          │ Top 10–20 candidates (thumbnails only)
          ▼
┌─────────────────────────┐
│  Subscription Gate      │  RevenueCat entitlement check
│  + Usage Check          │  Supabase daily counter
└─────────┬───────────────┘
          │ Authorized
          ▼
┌─────────────────────────┐
│  Supabase Edge Function │  AI proxy — keys never in app
│  (AI Provider Router)   │  Supports: Claude, GPT-4o, Gemini
└─────────┬───────────────┘
          │ Structured JSON response
          ▼
┌─────────────────────────┐
│  Post Editor Screen     │  Riverpod state
│  • Selected photos      │  Isar draft storage
│  • Caption (editable)   │
│  • Hashtags             │
│  • Platform badge       │
└─────────┬───────────────┘
          │
          ▼
┌─────────────────────────┐
│  Share / Save           │  share_plus (OS share sheet)
│                         │  Isar local draft history
└─────────────────────────┘
```

## Component Map

| Component | Technology | Responsibility |
|---|---|---|
| Mobile app | Flutter (Dart) | All UI, on-device ML, state management |
| Photo access | `photo_manager` | Gallery permissions + asset loading |
| On-device ML | `google_mlkit_image_labeling`, `google_mlkit_face_detection` | Photo scoring pipeline |
| State management | Riverpod | Reactive state, async providers |
| Navigation | go_router | Declarative routing |
| Local DB | Isar | Draft history, user preferences |
| Backend | Supabase | Auth, subscription state, usage tracking |
| AI proxy | Supabase Edge Functions (Deno) | Routes requests to cloud AI; holds API keys |
| Payments | RevenueCat | In-app subscription, App Store + Play Store |
| Sharing | `share_plus` | OS native share sheet |

## Current Platform Scope

**Active:** Instagram only
**Stubbed (not activated):** Twitter/X, Facebook, TikTok

The platform enum and prompt variants for all four platforms exist in the codebase but only Instagram prompts are wired up. Activating another platform = enable its prompt + route in the UI. No structural changes required.

## Security Model

- AI provider API keys (OpenAI, Anthropic, Google) are stored exclusively in Supabase secrets — never bundled in the app
- All AI calls go through the Edge Function proxy, authenticated with the user's Supabase JWT
- RevenueCat entitlement is validated server-side before each generation request
- Daily usage counter is incremented atomically in Postgres to prevent race conditions

## Key Design Principles

1. **On-device first** — ML scoring happens locally; only thumbnails (not full-res) are sent to the AI for curation, preserving privacy and reducing bandwidth
2. **Provider-agnostic** — the `AIProvider` abstract class means the backend can swap or add AI providers without touching the Flutter app
3. **Extensible platforms** — `SocialPlatform` enum + prompt registry pattern means new platforms are additive, not structural
4. **Offline-capable drafts** — generated posts are saved locally in Isar; the user can access draft history without network
