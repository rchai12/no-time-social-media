# Phase 6 — Real ML Scoring, Settings & Permissions Flow

**Depends on:** Phase 5 complete.
**Spec references:** `docs/features/01-photo-scanning.md` (primary), `docs/architecture/data-models.md`.

Read `docs/features/01-photo-scanning.md` fully before starting. It is the canonical spec for everything in Track A and Track C.

---

## Overview

Phase 6 completes three things that the spec requires but the codebase currently stubs:

1. **Track A** — Replace mock scoring with real ML Kit scoring (the core product value)
2. **Track B** — Settings screen (photo count + subscription management)
3. **Track C** — Permission request flow and scan screen UI polish

Tracks are sequential: A must be done before C (C depends on A's new provider signature).

---

## Track A — Real ML Kit Scoring

### What is currently wrong

`scoring_service.dart` calls ML Kit entry points but returns constants and random noise:
- `_calculateAestheticScore` → random number
- `_calculateNoveltyScore` → random number
- `_calculateFacesScore` → random number based on milliseconds
- `_calculateSharpnessScore` → returns 0.5 (fixed after Phase 1–3 fixes; real Laplacian should already be in place)

Novelty cannot be computed per-photo in isolation — it requires comparing labels across the whole batch. This means the existing `calculateScores(PhotoEntity)` signature is architecturally wrong for novelty.

### A1 — Redesign `ScoringService` to score the entire batch

Replace `calculateScores(PhotoEntity)` with a new static method `scoreAll(List<PhotoEntity>)` that processes all photos together. The old per-photo method is deleted.

**New signature:**
```dart
static Future<List<ScoredPhoto>> scoreAll(List<PhotoEntity> photos) async
```

Internal pipeline:
1. Create ML Kit detector instances once (not per photo).
2. Run labeling on all photos in parallel, capped at 4 concurrent.
3. Build a label-frequency map from all results.
4. Score each photo (recency, aesthetic, novelty, faces) using its labels + the frequency map.
5. Close ML Kit instances.
6. Return `List<ScoredPhoto>` — caller sorts.

Wrap the entire method in a try/catch. If any ML Kit step throws during initialisation, fall back to recency-only scoring for all photos and log the error. Do not crash. This implements the spec's "ML Kit init failure → skip ML scoring, use recency-only ranking" requirement.

### A2 — ML Kit setup

**Add the ML Kit plugins to `pubspec.yaml`** (they are already listed in the tech stack but may not be in the file):
```yaml
google_mlkit_image_labeling: ^0.10.0
google_mlkit_face_detection: ^0.10.0
```

**iOS — `ios/Podfile`:** Ensure `platform :ios, '16.0'` (fix from Phase 1–3 — confirm it is applied).

**Android — no extra steps.** `google_mlkit_*` plugins pull in the required dependencies automatically.

### A3 — Implement the scoring pipeline

Create ML Kit instances at the start of `scoreAll`:
```dart
final labeler  = ImageLabeler(
  options: ImageLabelerOptions(confidenceThreshold: 0.3),
);
final detector = FaceDetector(
  options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
);
```

Use a low threshold (0.3) for the labeler so that novelty scoring has enough labels to compare. Only the top-3 highest-confidence labels are used for the aesthetic sub-score.

Always close both after use:
```dart
try {
  // ... scoring ...
} finally {
  await labeler.close();
  await detector.close();
}
```

#### Concurrency cap of 4

Chunk the photos list into groups of 4 and `Future.wait` each group:

```dart
Future<List<T>> _runConcurrent<T>(
  List<PhotoEntity> photos,
  Future<T> Function(PhotoEntity) task, {
  int concurrency = 4,
}) async {
  final results = <T>[];
  for (int i = 0; i < photos.length; i += concurrency) {
    final chunk = photos.sublist(i, min(i + concurrency, photos.length));
    results.addAll(await Future.wait(chunk.map(task)));
  }
  return results;
}
```

#### Pass 1 — Label all photos

```dart
Future<List<ImageLabel>> _labelPhoto(
  ImageLabeler labeler, PhotoEntity photo) async {
  final input = InputImage.fromFilePath(photo.path);
  try {
    return await labeler.processImage(input);
  } catch (_) {
    return [];
  }
}
```

Run via `_runConcurrent`:
```dart
final allLabels = await _runConcurrent(
  photos, (p) => _labelPhoto(labeler, p));
// allLabels[i] corresponds to photos[i]
```

#### Build label-frequency map

```dart
Map<String, int> _buildFrequencyMap(List<List<ImageLabel>> allLabels) {
  final freq = <String, int>{};
  for (final labels in allLabels) {
    // Only use the top label per photo to avoid inflating common words
    if (labels.isNotEmpty) {
      final top = labels.reduce((a, b) => a.confidence > b.confidence ? a : b);
      freq[top.label] = (freq[top.label] ?? 0) + 1;
    }
  }
  return freq;
}
```

#### Aesthetic sub-score from labels

Average the confidence of the top-3 labels (by confidence) for the photo:
```dart
double _labelConfidence(List<ImageLabel> labels) {
  if (labels.isEmpty) return 0.5; // neutral fallback
  final top3 = (labels.toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence)))
    .take(3)
    .toList();
  return top3.map((l) => l.confidence).reduce((a, b) => a + b) / top3.length;
}
```

Aesthetic = `(sharpness + labelConfidence) / 2`
(sharpness is the existing Laplacian implementation from Phase 1–3 fixes)

#### Novelty score

```dart
double _noveltyScore(
  List<ImageLabel> labels,
  Map<String, int> freqMap,
  int totalPhotos,
) {
  if (labels.isEmpty) return 0.5;
  final top = labels.reduce((a, b) => a.confidence > b.confidence ? a : b);
  final frequency = freqMap[top.label] ?? 1;
  // If this photo is the only one with this label → novelty 1.0
  // If all photos share the same label → novelty 0.0
  return 1.0 - ((frequency - 1) / totalPhotos.toDouble()).clamp(0.0, 1.0);
}
```

#### Pass 2 — Run face detection concurrently

```dart
Future<int> _countFaces(FaceDetector detector, PhotoEntity photo) async {
  final input = InputImage.fromFilePath(photo.path);
  try {
    final faces = await detector.processImage(input);
    return faces.length;
  } catch (_) {
    return 0;
  }
}

final faceCounts = await _runConcurrent(
  photos, (p) => _countFaces(detector, p));
```

Face score per spec:
```dart
double _faceScore(int count) => (count / 3.0).clamp(0.0, 1.0);
```
(0 faces = 0.0, 1 face = 0.33, 2 faces = 0.67, 3+ faces = 1.0)

#### Assemble final scores

```dart
final freqMap = _buildFrequencyMap(allLabels);

return List.generate(photos.length, (i) {
  final photo    = photos[i];
  final labels   = allLabels[i];
  final faces    = faceCounts[i];

  final recency    = _recencyScore(photo.dateTaken);
  final sharpness  = /* existing Laplacian result — run in pass 1 if needed */;
  final labelConf  = _labelConfidence(labels);
  final aesthetic  = (sharpness + labelConf) / 2.0;
  final novelty    = _noveltyScore(labels, freqMap, photos.length);
  final faceScore  = _faceScore(faces);

  final composite  = (recency   * 0.35) +
                     (aesthetic * 0.30) +
                     (novelty   * 0.20) +
                     (faceScore * 0.15);

  return ScoredPhoto(
    id:             photo.id,
    path:           photo.path,
    width:          photo.width,
    height:         photo.height,
    dateTaken:      photo.dateTaken,
    isFavorited:    photo.isFavorited,
    compositeScore: composite,
    recencyScore:   recency,
    aestheticScore: aesthetic,
    noveltyScore:   novelty,
    facesScore:     faceScore,
    sharpnessScore: sharpness,
  );
});
```

**Note on sharpness in the two-pass design:** sharpness requires reading the full file and decoding, which is also needed for ML Kit (via `InputImage.fromFilePath`). Run sharpness calculation in a third concurrent pass, or fold it into Pass 1 alongside labeling. Do not read the file three times.

Recommended: run labeling, face detection, and sharpness all from the same `InputImage` in Pass 1 by calling all three in one `Future.wait` per photo within the concurrency cap:

```dart
final (labels, faceCount, sharpness) = await (
  _labelPhoto(labeler, photo),
  _countFaces(detector, photo),
  _sharpnessScore(photo.path),   // existing implementation
).wait;
```

### A4 — Update `photo_scan_provider.dart`

Replace the sequential scoring loop with the new batch method:

```dart
@override
Future<List<ScoredPhoto>> build() async {
  final count = _photoCount(); // from settings (Step B2)
  final photos = await PhotoService.fetchLastPhotos(count);
  if (photos.isEmpty) return [];

  final scored = await ScoringService.scoreAll(photos);
  scored.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
  return scored;
}
```

Remove the `print('Error scoring photo...')` — use `debugPrint` in the service.

### A5 — Recency score: use hours not days

Confirm the `_recencyScore` implementation uses hours (72-hour window). If it still uses `inDays`, fix it:

```dart
static double _recencyScore(DateTime dateTaken) {
  final hours = DateTime.now().difference(dateTaken).inMinutes / 60.0;
  if (hours <= 0)  return 1.0;
  if (hours >= 72) return 0.0;
  return 1.0 - (hours / 72.0);
}
```

---

## Track B — Settings Screen

### B1 — Create `PrefsService`

**File:** `no_time_media/lib/core/services/prefs_service.dart`

Wraps the Hive `prefs` box (already opened in `main.dart`):

```dart
import 'package:hive_flutter/hive_flutter.dart';

class PrefsService {
  static Box get _box => Hive.box('prefs');

  static const _keyPhotoCount = 'defaultPhotoCount';

  static int get photoCount => (_box.get(_keyPhotoCount) as int?) ?? 20;

  static Future<void> setPhotoCount(int count) async {
    await _box.put(_keyPhotoCount, count.clamp(10, 50));
  }
}
```

### B2 — Read photo count from prefs in the provider

In `photo_scan_provider.dart`, replace the hardcoded `20`:

```dart
import 'package:no_time_media/core/services/prefs_service.dart';

// In build():
final count = PrefsService.photoCount;
```

### B3 — Create `settingsProvider`

**File:** `no_time_media/lib/core/providers/settings_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/services/prefs_service.dart';

final photoCountProvider = NotifierProvider<PhotoCountNotifier, int>(
  PhotoCountNotifier.new,
);

class PhotoCountNotifier extends Notifier<int> {
  @override
  int build() => PrefsService.photoCount;

  Future<void> setCount(int count) async {
    await PrefsService.setPhotoCount(count);
    state = count;
  }
}
```

### B4 — Create `SettingsScreen`

**File:** `no_time_media/lib/features/settings/settings_screen.dart`

Accessible from the `AppShell` bottom nav (third tab) — see routing update in B6.

**Layout:**

```
AppBar: "Settings"

Section: "Scanning"
  ListTile:
    title: "Photos to scan"
    subtitle: "20 photos"   ← current value
    trailing: Icon(chevron_right)
    onTap → opens _PhotoCountSheet

Section: "Subscription"
  Consumer reading subscriptionProvider (if Phase 5 is complete;
  if not, read RevenueCat directly via SubscriptionService.isPro()):
    If Free:
      ListTile icon: Icons.star_outline
      title: "Free Plan"
      subtitle: "3 generations per month"
      trailing: [Upgrade] ElevatedButton → context.push('/paywall')
    If Pro:
      ListTile icon: Icons.star (gold colour)
      title: "Pro Plan"
      subtitle: "20 generations per day"
      trailing: Text("Active", style: green)

Section: "Account"
  ListTile: "Sign Out" (red text)
    onTap:
      await Supabase.instance.client.auth.signOut();
      await Purchases.logOut();
      // go_router redirect fires automatically

Section: "Legal"
  ListTile: "Privacy Policy" → launch URL (placeholder for now; open in-app webview or browser)
  ListTile: "Terms of Service" → same
```

#### `_PhotoCountSheet` (modal bottom sheet):

```
"How many photos should the app scan?"
Slider: min 10, max 50, divisions 8, value: currentCount
Label: "Scanning [value] photos"
[Save]
```

On save: `ref.read(photoCountProvider.notifier).setCount(value.toInt())` then `ref.invalidate(photoScanProvider)` to re-trigger scanning with the new count.

### B5 — Create `subscriptionProvider` (if not already done in Phase 5)

**File:** `no_time_media/lib/core/providers/subscription_provider.dart`

If Phase 5 was fully implemented this provider should exist. If not, create a minimal version:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/services/subscription_service.dart';

final subscriptionProvider = FutureProvider<bool>((ref) async {
  return SubscriptionService.isPro();
});
```

### B6 — Add Settings route and bottom nav tab

**`router.dart`:** Add inside the `ShellRoute.routes` list:
```dart
GoRoute(
  path: '/settings',
  builder: (context, state) => const SettingsScreen(),
),
```

**`app_shell.dart`:** Add a third `NavigationDestination`:
```dart
NavigationDestination(
  icon: Icon(Icons.settings_outlined),
  selectedIcon: Icon(Icons.settings),
  label: 'Settings',
),
```

Update the `onDestinationSelected` handler:
```dart
onDestinationSelected: (i) {
  if (i == 0) context.go('/scan');
  if (i == 1) context.go('/drafts');
  if (i == 2) context.go('/settings');
},
```

Update the `index` calculation:
```dart
final index = switch (location) {
  '/drafts'   => 1,
  '/settings' => 2,
  _           => 0,
};
```

---

## Track C — Permission Flow & Scan Screen UI Polish

### C1 — First-launch permission flow

**Problem:** `PhotoService.fetchLastPhotos` throws `Exception('Permission denied')` when the user has not yet granted photo access. The error bubbles up to `photoScanProvider` and shows a generic error widget.

**Fix in `photo_scan_screen.dart`:** Before the `ref.watch(photoScanProvider)`, add a permission-aware pre-check using `photo_manager`'s `requestPermissionExtend()`. Check the result and render different states:

Replace the `photosAsync.when(...)` error handler:

```dart
error: (error, _) {
  final isPermission = error.toString().contains('Permission denied') ||
                       error.toString().contains('denied');
  if (isPermission) {
    return _PermissionDeniedView();
  }
  return Center(
    child: Column(children: [
      const Icon(Icons.error_outline, size: 48),
      Text('Error: $error'),
      ElevatedButton(
        onPressed: () => ref.invalidate(photoScanProvider),
        child: const Text('Retry'),
      ),
    ]),
  );
},
```

Create `_PermissionDeniedView` as a private widget:

```dart
class _PermissionDeniedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Photo Access Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'No Time Media needs access to your photo library to find and score your best photos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              onPressed: () => PhotoManager.openSetting(),
            ),
          ],
        ),
      ),
    );
  }
}
```

### C2 — Score tier badges (replace raw number overlay)

**Problem:** The grid currently shows `photo.compositeScore.toStringAsFixed(2)` as a raw decimal. The spec requires tier badges (gold star, silver star, no badge) — no raw numbers.

In `_buildPhotoThumbnail`, replace the score overlay `Positioned` widget:

```dart
Positioned(
  top: 4,
  right: 4,
  child: _scoreBadge(photo.compositeScore),
),
```

Add the badge builder:

```dart
Widget _scoreBadge(double score) {
  if (score >= 0.75) {
    return const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 20);
  }
  if (score >= 0.50) {
    return const Icon(Icons.star_rounded, color: Color(0xFFC0C0C0), size: 20);
  }
  return const SizedBox.shrink(); // below 50% — no badge
}
```

Remove the black overlay `Container` at the bottom entirely.

### C3 — Loading shimmer during scoring

While `photoScanProvider` is in `AsyncLoading`, show a shimmer grid instead of `CircularProgressIndicator`.

Add `shimmer: ^3.0.0` to `pubspec.yaml`.

Replace the `loading` branch in the `photosAsync.when`:

```dart
loading: () => GridView.builder(
  padding: const EdgeInsets.all(8),
  itemCount: 20,
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4,
  ),
  itemBuilder: (context, _) => Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: Container(color: Colors.white),
  ),
),
```

### C4 — Long-press to deselect photos

The spec says: "User can long-press a photo to deselect it before generating."

Add selection state to `PhotoScanScreen` — convert to `ConsumerStatefulWidget`:

```dart
class PhotoScanScreen extends ConsumerStatefulWidget { ... }

class _PhotoScanScreenState extends ConsumerState<PhotoScanScreen> {
  final Set<String> _deselected = {};
  ...
}
```

In `_buildPhotoThumbnail`, wrap with `GestureDetector.onLongPress`:
```dart
onLongPress: () {
  setState(() {
    if (_deselected.contains(photo.id)) {
      _deselected.remove(photo.id);
    } else {
      _deselected.add(photo.id);
    }
  });
},
```

Apply a grey overlay on deselected photos:
```dart
if (_deselected.contains(photo.id))
  Positioned.fill(
    child: ColoredBox(
      color: Colors.black.withOpacity(0.5),
      child: const Icon(Icons.close, color: Colors.white),
    ),
  ),
```

In the FAB `onPressed`, filter out deselected photos before passing to generation:
```dart
final photos = ref.read(photoScanProvider).maybeWhen(
  data: (data) => data.where((p) => !_deselected.contains(p.id)).toList(),
  orElse: () => <ScoredPhoto>[],
);
```

Reset `_deselected` when `photoScanProvider` is invalidated (refresh):
```dart
// In the refresh button's onPressed:
setState(() => _deselected.clear());
ref.invalidate(photoScanProvider);
```

### C5 — Replace FAB with bottom CTA button

The spec shows "Generate Posts" as a bottom CTA button, not a FAB. This is a small UI change that makes the affordance clearer.

Remove `floatingActionButton` from the `Scaffold`. Add a `bottomNavigationBar` (distinct from the shell nav bar — use `bottomSheet` or wrap body in a `Column` with a sticky bottom):

```dart
// In Scaffold body, replace GridView with:
Column(
  children: [
    Expanded(child: GridView.builder(...)),
    SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Posts'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: photosAsync.hasValue ? _onGenerate : null,
          ),
        ),
      ),
    ),
  ],
),
```

Move the FAB logic into `_onGenerate()`.

---

## File structure after Phase 6

```
lib/
  core/
    providers/
      settings_provider.dart       ← NEW (B3)
      subscription_provider.dart   ← NEW or confirm from Phase 5 (B5)
    services/
      scoring_service.dart         ← REWRITTEN (A3)
      prefs_service.dart           ← NEW (B1)
    providers/
      photo_scan_provider.dart     ← updated (A4, B2)
  features/
    photo_scan/
      photo_scan_screen.dart       ← updated (C2–C5, converted to StatefulWidget)
    settings/
      settings_screen.dart         ← NEW (B4)
  core/
    router.dart                    ← updated (B6)
    widgets/
      app_shell.dart               ← updated (B6)
```

---

## pubspec.yaml additions

```yaml
dependencies:
  google_mlkit_image_labeling: ^0.10.0
  google_mlkit_face_detection: ^0.10.0
  shimmer: ^3.0.0
```

Run `flutter pub get` after adding.

---

## Build sequence

1. Add ML Kit and shimmer packages, run `flutter pub get`.
2. Rewrite `ScoringService.scoreAll()` (A3).
3. Update `photo_scan_provider.dart` to call `scoreAll` and read photo count (A4, B2).
4. Create `PrefsService` and `settingsProvider` (B1, B3).
5. Create `SettingsScreen` (B4) and update routing + `AppShell` (B6).
6. Update `PhotoScanScreen` — convert to `StatefulWidget`, add badges, shimmer, deselect, CTA button, permission error view (C1–C5).
7. Run `flutter analyze`.
8. Run on a physical device (ML Kit does not work on simulators without real photos).

---

## Verification checklist

- [ ] `flutter analyze` reports no errors.
- [ ] Photos in the grid display real thumbnails (from Phase 1–3 fixes).
- [ ] Shimmer grid appears while scoring is in progress.
- [ ] After scoring: gold/silver star badges appear (no raw score numbers).
- [ ] Long-press a photo → grey overlay + ✕ shown; long-press again → deselected.
- [ ] Deselected photos are excluded from "Generate Posts".
- [ ] Settings screen reachable via bottom nav tab 3.
- [ ] Changing photo count in settings and refreshing re-scans with new count.
- [ ] Photo permission denied → explanation screen with "Open Settings" button (not crash).
- [ ] ML Kit scores vary meaningfully across photos (not all the same score).

---

## What is NOT in scope for Phase 6

- App icons, splash screen, store metadata (Phase 7)
- Privacy policy / terms of service content (Phase 7)
- Android package name change (Phase 7)
- iOS deployment target change (Phase 7 — though confirm it is 16.0 after Phase 1–3 fixes)
- Analytics or crash reporting (post-v1)
- Localisation (English only for v1)
- Multi-language caption generation (post-v1)
