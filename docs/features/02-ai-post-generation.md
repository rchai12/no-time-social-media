# Feature Spec 02 — AI Post Generation

## Purpose

Send on-device scored photo candidates to a cloud AI (via Supabase Edge Function) for two-stage processing:
1. **Curation** — AI selects the best 1–4 photos from the candidates
2. **Generation** — AI writes an Instagram-optimized caption + hashtags for each selected photo

## Two-Stage AI Call (Single Request)

The AI performs curation and generation in one call. The system prompt instructs the model to:
1. Review all provided photos (as thumbnails)
2. Select 1–4 photos that are most suitable for social media based on visual quality, subject interest, and uniqueness
3. For each selected photo, determine the best platform (currently always Instagram for v1)
4. Generate a post prototype for each selected photo

## System Prompt

The Edge Function builds the system prompt dynamically. Below is the template:

```
You are a social media content strategist specialising in high-engagement posts.

You will receive a set of photos taken from a mobile device, scored by on-device ML.
Your job is to:
1. Select the 1–4 best photos for social media from the provided candidates
2. For each selected photo, write an optimised post for the platform specified

PLATFORM RULES — Instagram (active):
- Caption: 150–300 characters, authentic and conversational tone
- Emoji: use 2–5 relevant emojis naturally within the caption
- Hashtags: exactly 5 hashtags; mix of broad (1–2) and niche (3–4)
- Engagement hook: first sentence must create curiosity or emotional resonance
- Do not use generic phrases like "check this out" or "amazing moment"

SELECTION CRITERIA:
- Visual clarity and sharpness (prefer sharp, well-lit photos)
- Subject interest (prefer photos with a clear, interesting subject)
- Uniqueness (avoid selecting visually similar photos)
- Emotional impact (prefer photos that evoke a feeling)

RESPONSE FORMAT — respond ONLY with valid JSON, no markdown, no explanation:
{
  "selectedPhotos": [
    {
      "assetId": "<id from input>",
      "caption": "<caption text without hashtags>",
      "hashtags": ["hashtag1", "hashtag2", "hashtag3", "hashtag4", "hashtag5"],
      "bestPlatform": "instagram",
      "engagementRationale": "<1 sentence explaining why this photo and caption will perform well>"
    }
  ]
}
```

## Edge Function: `generate-post`

**File:** `supabase/functions/generate-post/index.ts`

### Request (from Flutter app)

```typescript
type GeneratePostRequest = {
  userId: string;
  photos: {
    assetId: string;
    thumbnailBase64: string;   // JPEG, 256x256, base64
    compositeScore: number;
    dateTaken: string;         // ISO 8601
  }[];
  targetPlatform: 'instagram'; // expand later
};
```

### Edge Function Logic

```
1. Validate JWT (Supabase auth middleware)
2. Check subscription tier + daily usage in Postgres
   → If usage >= limit: return 429 with { error: 'daily_limit_reached' }
3. Increment daily usage counter (atomic UPDATE ... RETURNING)
4. Build system prompt (see above)
5. Build user message: attach all thumbnails as base64 image content
6. Call configured AI provider (ACTIVE_AI_PROVIDER env var)
7. Parse and validate JSON response
   → On parse failure: retry once with explicit JSON correction prompt
   → On second failure: return 500
8. Return AIGenerationResponse to app
```

### Response

```typescript
type GeneratePostResponse = {
  selectedPhotos: {
    assetId: string;
    caption: string;
    hashtags: string[];
    bestPlatform: string;
    engagementRationale: string;
  }[];
};
```

### Error Responses

| HTTP Status | `error` field | Flutter handling |
|---|---|---|
| 401 | `unauthorized` | Re-authenticate user |
| 402 | `subscription_required` | Show paywall screen |
| 429 | `daily_limit_reached` | Show "come back tomorrow" state |
| 500 | `ai_error` | Show retry option |

## AI Provider Implementations (Edge Function)

Three providers are implemented as TypeScript modules in the Edge Function. Active provider is controlled by env var.

### Claude (Default)

```typescript
import Anthropic from '@anthropic-ai/sdk';
const client = new Anthropic({ apiKey: Deno.env.get('ANTHROPIC_API_KEY') });

const response = await client.messages.create({
  model: 'claude-opus-4-6',
  max_tokens: 2048,
  system: systemPrompt,
  messages: [{
    role: 'user',
    content: photos.map(p => ({
      type: 'image',
      source: { type: 'base64', media_type: 'image/jpeg', data: p.thumbnailBase64 }
    })).concat([{ type: 'text', text: 'Please select and generate posts for these photos.' }])
  }]
});
```

### OpenAI GPT-4o

```typescript
import OpenAI from 'openai';
const client = new OpenAI({ apiKey: Deno.env.get('OPENAI_API_KEY') });

// Use gpt-4o with vision — same structure, image_url with base64
```

### Google Gemini

```typescript
import { GoogleGenerativeAI } from '@google/generative-ai';
const genAI = new GoogleGenerativeAI(Deno.env.get('GOOGLE_API_KEY'));
const model = genAI.getGenerativeModel({ model: 'gemini-1.5-pro' });

// Pass images as inline_data parts
```

## Flutter AI Service

```dart
// lib/core/services/ai_service.dart
class AIService {
  final SupabaseClient _supabase;

  Future<AIGenerationResponse> generatePosts({
    required List<ScoredPhoto> candidates,
    SocialPlatform platform = SocialPlatform.instagram,
  }) async {
    final request = AIGenerationRequest(
      userId: _supabase.auth.currentUser!.id,
      photos: candidates.map((p) => AIPhotoInput(
        assetId: p.assetId,
        thumbnailBase64: base64Encode(p.thumbnail),
        compositeScore: p.compositeScore,
        dateTaken: p.dateTaken,
      )).toList(),
      targetPlatform: platform,
    );

    final response = await _supabase.functions.invoke(
      'generate-post',
      body: request.toJson(),
    );

    if (response.status != 200) {
      throw AIException.fromStatus(response.status, response.data);
    }

    return AIGenerationResponse.fromJson(response.data);
  }
}
```

## Adding a New AI Provider (Future)

1. Add new TypeScript module in `supabase/functions/generate-post/providers/`
2. Register in the provider router switch statement
3. Add the new provider's API key to Supabase secrets
4. Set `ACTIVE_AI_PROVIDER` env var to the new provider name
5. No Flutter app changes required

## Adding a New Platform (Future)

1. Enable the platform in `SocialPlatform.isActive` (Dart)
2. Add a prompt variant block in the Edge Function's system prompt builder
3. Expose the platform option in the UI (settings or generation screen)
4. No structural changes to the Edge Function or Flutter architecture required

## Dependencies

- Supabase Edge Functions (Deno)
- `@anthropic-ai/sdk` (npm, Edge Function)
- `openai` (npm, Edge Function)
- `@google/generative-ai` (npm, Edge Function)
- `supabase_flutter` (Dart)
