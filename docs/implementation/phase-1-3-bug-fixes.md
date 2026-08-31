# Phase 1–3 Bug Fixes

**Scope:** Correct only what was supposed to be done in Phases 1, 2, and 3. Do not implement Phase 4 or Phase 5 features. Do not refactor working code that is not listed here.

Read the full spec for each area before editing:
- `docs/features/01-photo-scanning.md`
- `docs/features/02-ai-post-generation.md`
- `docs/api/ai-provider-contract.md`

---

## Fix 1 — Remove duplicate `main()` in `app.dart`

**File:** `no_time_media/lib/app.dart`
**Problem:** `app.dart` contains a second `void main()` that runs the app without Supabase initialisation. The real entry point is `main.dart`. Flutter always runs `main.dart`; the stray function in `app.dart` is dead code that will confuse future readers and may cause issues if the entry point ever changes.
**Fix:** Delete lines 4–6 from `app.dart` (the entire `void main() { runApp(const NoTimeMediaApp()); }` block). Leave `NoTimeMediaApp` class intact.

---

## Fix 2 — iOS photo permission string

**File:** `no_time_media/ios/Runner/Info.plist`
**Problem:** `NSPhotoLibraryUsageDescription` is absent. On a real iOS device the OS kills the app before `photo_manager` can show the picker.
**Fix:** Add the following key/string pair inside the root `<dict>` in `Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>No Time Media needs access to your photos to score and select the best ones for your posts.</string>
```

If `NSPhotoLibraryAddUsageDescription` is also absent, add it with the same string.

---

## Fix 3 — Real `dateTaken` from `photo_manager`

**File:** `no_time_media/lib/core/services/photo_service.dart`
**Problem:** Line 47 sets `dateTaken: DateTime.now()`. Every photo gets the same timestamp, making recency scoring meaningless.
**Fix:** Replace the placeholder with the actual asset date.

In `photo_manager` 3.x the property is `asset.createDateTime`. That returns a `DateTime?`; fall back to `DateTime.now()` only if it is null.

```dart
dateTaken: asset.createDateTime ?? DateTime.now(),
```

---

## Fix 4 — Fetch photos sorted newest-first

**File:** `no_time_media/lib/core/services/photo_service.dart`
**Problem:** `PhotoManager.getAssetListRange(start: 0, end: count)` does not guarantee creation-date order. On some devices it returns assets in album order.
**Fix:** Replace the `getAssetListRange` call with `getAssetListPaged` using a `FilterOptionGroup` that sorts by `createDate` descending:

```dart
final albums = await PhotoManager.getAssetPathList(
  type: RequestType.image,
  filterOption: FilterOptionGroup(
    imageOption: const FilterOption(),
    orders: [
      const OrderOption(type: OrderOptionType.createDate, asc: false),
    ],
  ),
);

if (albums.isEmpty) return [];

final assets = await albums.first.getAssetListRange(start: 0, end: count);
```

Use `albums.first` which is the "All Photos" / "Recent" album on both platforms. Keep everything else in `fetchLastPhotos` the same.

---

## Fix 5 — Recency window: 30 days → 72 hours

**File:** `no_time_media/lib/core/services/scoring_service.dart`
**Problem:** `_calculateRecencyScore` uses a 30-day linear window. The spec (`docs/features/01-photo-scanning.md`) defines a 72-hour window.
**Fix:** Replace the body of `_calculateRecencyScore`:

```dart
static double _calculateRecencyScore(DateTime dateTaken) {
  final hours = DateTime.now().difference(dateTaken).inMinutes / 60.0;
  if (hours <= 0) return 1.0;
  if (hours >= 72) return 0.0;
  return 1.0 - (hours / 72.0);
}
```

---

## Fix 6 — Real sharpness + blend into aesthetic

**File:** `no_time_media/lib/core/services/scoring_service.dart`
**Problem A:** `_calculateSharpnessScore` reads and decodes the image but always returns `0.5`.
**Problem B:** `_computeCompositeScore` accepts `sharpness` as a separate parameter but the spec defines:

> `aestheticScore = (sharpnessScore + labelConfidence) / 2`
> `compositeScore  = recency×0.35 + aesthetic×0.30 + novelty×0.20 + faces×0.15`
> `sharpness` is not a top-level component — it feeds into `aesthetic`.

**Fix A — Real Laplacian sharpness:**

Replace the return inside `_calculateSharpnessScore` with a real variance-of-Laplacian calculation using the already-imported `package:image/image.dart`:

```dart
static Future<double> _calculateSharpnessScore(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return 0.0;

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return 0.0;

    final gray = img.grayscale(image);
    final w = gray.width;
    final h = gray.height;

    double sum = 0;
    double sumSq = 0;
    int count = 0;

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final center = img.getLuminance(gray.getPixel(x, y));
        final top    = img.getLuminance(gray.getPixel(x, y - 1));
        final bottom = img.getLuminance(gray.getPixel(x, y + 1));
        final left   = img.getLuminance(gray.getPixel(x - 1, y));
        final right  = img.getLuminance(gray.getPixel(x + 1, y));
        final lap = (4 * center - top - bottom - left - right).abs();
        sum   += lap;
        sumSq += lap * lap;
        count++;
      }
    }

    if (count == 0) return 0.0;
    final mean     = sum / count;
    final variance = (sumSq / count) - (mean * mean);

    // Normalize: variance ≥ 500 → sharp (1.0); 0 → blurry (0.0)
    return (variance / 500.0).clamp(0.0, 1.0);
  } catch (e) {
    debugPrint('Error calculating sharpness: $e');
    return 0.0;
  }
}
```

**Fix B — Blend sharpness into aesthetic, remove it from composite:**

1. Change `calculateScores` so that `aestheticScore` is computed as `(sharpnessScore + mockLabelScore) / 2`, where `mockLabelScore` is the current random mock (0.2–1.0 range). Replace the existing `_calculateAestheticScore` call:

```dart
final sharpnessScore  = await _calculateSharpnessScore(photo.path);
final mockLabelScore  = await _calculateAestheticScore(photo.path); // still mocked
final aestheticScore  = (sharpnessScore + mockLabelScore) / 2.0;
```

2. Remove the `sharpness` parameter from `_computeCompositeScore` and update the signature and call site:

```dart
static double _computeCompositeScore(
  double recency,
  double aesthetic,
  double novelty,
  double faces,
) {
  return (recency * 0.35) + (aesthetic * 0.30) + (novelty * 0.20) + (faces * 0.15);
}
```

3. Keep `sharpnessScore` in `ScoredPhoto` as-is (it is useful for debugging). Just stop passing it to the composite calculation.

---

## Fix 7 — AI request: send thumbnails, not file paths

**Problem:** `ai_service.dart` sends `'path': photo.path` — a local filesystem string that the server cannot access. The AI provider (Gemini / Claude / GPT-4o) is a vision model and needs image data.
**Canonical contract:** `docs/api/ai-provider-contract.md` defines `thumbnailBase64: string` (JPEG 256×256).

### 7a — Update `PhotoInfo` in `ai_models.dart`

Replace the `path` field with `thumbnailBase64`:

```dart
class PhotoInfo {
  final String id;           // asset ID — used by server to echo back assetId
  final String thumbnailBase64; // JPEG 256×256 base64-encoded
  final DateTime dateTaken;
  final double score;
  final Components components;
  ...
}
```

Remove all references to `PhotoInfo.path`. Update the constructor, `==`, `hashCode`.

### 7b — Update `AIGenerationResponse` to match canonical spec

The canonical response is `{ selectedPhotos: [{ assetId, caption, hashtags, bestPlatform, engagementRationale }] }`.

Replace the current flat class with:

```dart
class PhotoResult {
  final String assetId;
  final String caption;
  final List<String> hashtags;   // 5 items, no '#' prefix
  final String bestPlatform;
  final String engagementRationale;
  ...
}

class AIGenerationResponse {
  final List<PhotoResult> selectedPhotos;
  ...
}
```

Remove `PlatformContent` — it is not part of the canonical spec.

### 7c — Update `ai_service.dart` to fetch thumbnails and parse canonical response

Replace the entire `generatePosts` method:

```dart
static Future<AIGenerationResponse> generatePosts(List<ScoredPhoto> photos) async {
  // 1. Fetch 256×256 JPEG thumbnails from photo_manager
  final photoInputs = <Map<String, dynamic>>[];
  for (final photo in photos) {
    final entity = AssetEntity(
      id: photo.id,
      typeInt: 1,
      width: photo.width,
      height: photo.height,
    );
    final bytes = await entity.thumbnailDataWithSize(const ThumbnailSize(256, 256));
    if (bytes == null) continue;
    photoInputs.add({
      'assetId': photo.id,
      'thumbnailBase64': base64Encode(bytes),
      'compositeScore': photo.compositeScore,
      'dateTaken': photo.dateTaken.toIso8601String(),
    });
  }

  if (photoInputs.isEmpty) throw Exception('No thumbnails available');

  // 2. Call edge function
  final response = await _supabase.functions.invoke(
    'generate-post',
    body: {
      'photos': photoInputs,
      'targetPlatform': 'instagram',
    },
  );

  // 3. Parse canonical response
  final body = response.data as Map<String, dynamic>;
  final rawList = List<dynamic>.from(body['selectedPhotos'] ?? []);
  final results = rawList.map((r) => PhotoResult(
    assetId: r['assetId'] as String,
    caption: r['caption'] as String,
    hashtags: List<String>.from(r['hashtags'] ?? []),
    bestPlatform: r['bestPlatform'] as String,
    engagementRationale: r['engagementRationale'] as String? ?? '',
  )).toList();

  return AIGenerationResponse(selectedPhotos: results);
}
```

Required imports to add:
```dart
import 'dart:convert';
import 'package:photo_manager/photo_manager.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
```

Change the method signature from `List<PhotoInfo>` to `List<ScoredPhoto>` so callers no longer need to construct `PhotoInfo` objects manually.

### 7d — Update `photo_scan_screen.dart` FAB to pass `ScoredPhoto` directly

The FAB currently converts `ScoredPhoto → PhotoInfo` before calling `generatePosts`. After 7c, `generatePosts` takes `List<ScoredPhoto>` directly.

Replace the FAB `onPressed` body:

```dart
onPressed: () async {
  final photos = ref.read(photoScanProvider).maybeWhen(
    data: (data) => data,
    orElse: () => <ScoredPhoto>[],
  );
  if (photos.isEmpty) return;
  try {
    await ref.read(generationProvider.notifier).generatePosts(photos);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e')),
      );
    }
  }
},
```

### 7e — Update `GenerationNotifier` signature

Change `generatePosts(List<PhotoInfo> photos)` → `generatePosts(List<ScoredPhoto> photos)` and update the internal `AIService.generatePosts(photos)` call to match.

---

## Fix 8 — Real edge function (replace simulation)

**File:** `supabase/functions/generate-post/index.ts`
**Problem:** The function simulates AI output with string concatenation. No real provider is called.
**Active provider:** `ACTIVE_AI_PROVIDER` env var, defaulting to `gemini`.

Rewrite the function to implement the canonical provider router from `docs/api/ai-provider-contract.md`. Implement at minimum the **Gemini provider** (active). Stub Claude and OpenAI as `throw new Error('not configured')` for now — they are Phase 3 scope but require separate API keys.

**Structure:**

```
supabase/functions/generate-post/
  index.ts           ← entry point (rewrite)
  providers/
    types.ts         ← PhotoInput, PhotoResult, GenerationResponse, AIProvider interfaces
    parser.ts        ← parseResponse (strip fences, JSON.parse, validate shape)
    gemini.ts        ← GeminiProvider (active)
    claude.ts        ← ClaudeProvider (stub)
    openai.ts        ← OpenAIProvider (stub)
    index.ts         ← getProvider() router
```

Copy the exact TypeScript code from `docs/api/ai-provider-contract.md` for each provider file. The parser and retry logic are also defined there.

**Entry point `index.ts` must:**

1. Accept `{ photos: PhotoInput[], targetPlatform: string }` — match 7c's request shape.
2. Call `getProvider()` to select the provider.
3. Pass a system prompt that instructs the AI to:
   - Curate the best 1–4 photos.
   - For each selected photo return `assetId`, `caption` (no hashtags), `hashtags` (5 items, no `#` prefix), `bestPlatform`, `engagementRationale`.
   - Respond with valid JSON only: `{ "selectedPhotos": [...] }`.
4. Use `generateWithRetry` from the spec for the actual call.
5. Return the `GenerationResponse` as JSON with CORS headers.

**JWT and entitlement checking** are Phase 5. Add a `// TODO(phase-5): verify JWT and check subscription` comment where that check would go.

**Remove** the now-unused `supabaseClient` import from `index.ts`.

**System prompt to embed in `index.ts`:**

```typescript
const SYSTEM_PROMPT = `You are a social media content curator for an Instagram-focused app.

You will receive between 1 and 20 photo thumbnails, each identified by an assetId.

Your tasks:
1. Select the best 1–4 photos based on visual quality, composition, and engagement potential.
2. For each selected photo write a caption (no hashtags) and exactly 5 relevant hashtags (no '#' prefix).
3. Identify the best platform (instagram | twitter | facebook | tiktok) and explain why in one sentence.

Respond ONLY with valid JSON in this exact shape, with no markdown fences:
{
  "selectedPhotos": [
    {
      "assetId": "string",
      "caption": "string",
      "hashtags": ["string","string","string","string","string"],
      "bestPlatform": "instagram",
      "engagementRationale": "string"
    }
  ]
}`;
```

---

## Fix 9 — Remove the unused `lib/models/` directory

**Directory:** `no_time_media/lib/models/`
**Problem:** Contains `post_draft.dart`, `social_platform.dart` and their generated files. These are duplicate model stubs committed by the coding agent that are never imported anywhere. They conflict with the Phase 4 Hive models that will be added later, and both use `@HiveType(typeId: 1)` — a typeId collision.
**Fix:** Delete the entire `lib/models/` directory. The canonical model location is `lib/core/models/`.

---

## Verification checklist

After all fixes, confirm:

- [ ] `flutter analyze` reports no errors (warnings about ML mocks are acceptable).
- [ ] App launches on simulator/device without crashing.
- [ ] Photo grid shows real thumbnails (not grey boxes or X).
- [ ] Thumbnails are ordered newest-first.
- [ ] Photos taken in the last 72 hours show higher recency scores than older photos.
- [ ] Tapping the FAB calls the edge function (check Supabase Edge Function logs — not simulated output).
- [ ] Edge function returns `{ selectedPhotos: [...] }` from a real Gemini call.
- [ ] `flutter test` runs without test-infrastructure errors (counter test can be updated to a smoke test that pumps `NoTimeMediaApp` from `main.dart`).

---

## What is NOT in scope here

Do not implement any of the following — they belong to later phases:

- JWT verification or entitlement check in the edge function (Phase 5)
- Hive initialisation or `PostDraft` persistence (Phase 4)
- Post editor screen (Phase 4)
- Share sheet (Phase 4)
- Auth / sign-in screen (Phase 4)
- RevenueCat or subscription paywall (Phase 5)
- Real ML Kit labels or face detection (deferred — leave aesthetic and faces as mocks)
- Settings screen or photo count selector (Phase 4)
- Database usage tracking (Phase 5)
