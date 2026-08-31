# Feature Spec 01 — Photo Scanning & On-Device Scoring

## Purpose

Fetch the user's most recent device photos and score them on-device using ML to identify the best candidates for social media, before any cloud call is made.

## User Flow

1. User taps "Scan Photos" on the home screen
2. App requests photo library permission (if not already granted)
3. App fetches the last N photos (default 20; user can set 10–50 in settings)
4. Each photo is scored silently in the background using the scoring pipeline below
5. Top 10–20 scored photos are presented in a grid for the user to review
6. User taps "Generate Posts" to proceed (optional: user can deselect specific photos before proceeding)
7. Selected candidates are passed to the AI generation step

## Permissions

### iOS
- `NSPhotoLibraryUsageDescription` in `Info.plist` — required for read access
- Request via `photo_manager`'s `PhotoManager.requestPermissionExtend()`
- If denied: show permission explanation sheet with link to Settings

### Android
- `READ_MEDIA_IMAGES` (API 33+) or `READ_EXTERNAL_STORAGE` (API 26–32) in `AndroidManifest.xml`
- Handled automatically by `photo_manager`

## Photo Fetch Implementation

```dart
// PhotoService
Future<List<AssetEntity>> fetchRecentPhotos(int count) async {
  final albums = await PhotoManager.getAssetPathList(
    type: RequestType.image,
    filterOption: FilterOptionGroup(
      imageOption: const FilterOption(needTitle: false),
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    ),
  );
  final recent = albums.firstWhere((a) => a.isAll, orElse: () => albums.first);
  return recent.getAssetListRange(start: 0, end: count);
}
```

## Scoring Pipeline

Run per photo, in parallel using `Future.wait` with concurrency capped at 4.

### 1. Recency Score (35%)

```
score = clamp((72h - hoursAgo) / 72h, 0.0, 1.0)
```

Photos taken within 72 hours score 0.0–1.0 linearly. Older than 72 hours score 0.0.

### 2. Aesthetic Score (30%)

Two sub-scores averaged:

**a) Sharpness** — Laplacian variance of grayscale thumbnail
- Load 256x256 thumbnail via `photo_manager` `thumbnailData`
- Convert to grayscale using the `image` Dart package
- Compute Laplacian filter variance
- Normalize: `clamp(variance / 500.0, 0.0, 1.0)` (500 is empirical max for sharp phone photos)

**b) ML Kit label confidence** — run `ImageLabeler` on thumbnail
- Use `ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5))`
- Average confidence of top-3 labels as a proxy for image clarity/recognizability
- Normalize to 0.0–1.0

Aesthetic score = `(sharpness + labelConfidence) / 2`

### 3. Novelty Score (20%)

- Run `ImageLabeler` on thumbnail → extract label strings
- Compare against a rolling window of the last 50 scored photos' label sets (held in memory)
- Novelty = proportion of labels not seen in recent window
- Normalize to 0.0–1.0

### 4. Face Score (15%)

- Run `FaceDetector(options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast))`
- Score = `clamp(faceCount / 3.0, 0.0, 1.0)` (1–3 faces = max score; 0 faces = 0.0)

### Composite Score

```
composite = (recency × 0.35) + (aesthetic × 0.30) + (novelty × 0.20) + (face × 0.15)
```

## Scoring Output

Returns `List<ScoredPhoto>` sorted descending by `compositeScore`. The top 20 are displayed; if fewer than 20 exist, all are shown.

## UI — Scanning Screen

- While scoring: show photo grid with shimmer placeholders + progress indicator
- After scoring: grid shows thumbnails with a subtle score-tier badge (no raw numbers shown to user):
  - Gold star: top 25%
  - Silver star: 25–50%
  - No badge: below 50%
- "Generate Posts" CTA button at bottom, enabled once scoring is complete
- User can long-press a photo to deselect it before generating

## Error States

| Situation | Behaviour |
|---|---|
| Permission denied | Show explanation sheet with "Open Settings" button |
| No photos on device | Show empty state illustration |
| ML Kit init failure | Skip ML scoring, use recency-only ranking, log error |
| Fewer than 5 photos available | Warn user but proceed |

## Dependencies

- `photo_manager: ^3.0.0`
- `google_mlkit_image_labeling: ^0.10.0`
- `google_mlkit_face_detection: ^0.10.0`
- `image: ^4.1.0` (sharpness calculation)
- `riverpod` (scoring state)
