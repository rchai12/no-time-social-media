# Phase 4 — Post Editor, Draft History & Sharing

**Depends on:** Phase 1–3 fixes complete (phase-1-3-bug-fixes.md applied).
**Spec references:** `docs/features/03-post-editor.md`, `docs/features/04-sharing.md`, `docs/architecture/data-models.md`.

Read all three spec documents fully before starting.

---

## Persistence layer: Hive (not Isar)

`docs/features/03-post-editor.md` references Isar. **Ignore those references.** Isar was replaced with Hive due to an AGP ≥8.0 namespace conflict. Use Hive 2.x everywhere persistence is mentioned. The canonical Hive schema is in `docs/architecture/data-models.md` — the "Hive Storage" section.

`pubspec.yaml` already contains `hive: ^2.2.3` and `hive_flutter: ^1.1.0` and `hive_generator` as a dev dependency. Do not add them again.

---

## Step 1 — Delete the old model stubs

Delete the entire `no_time_media/lib/models/` directory and all its files. It contains broken `PostDraft` and `SocialPlatform` stubs with conflicting `@HiveType(typeId: 1)` annotations. The correct models are created below.

---

## Step 2 — Create `PostDraft` Hive model

**File:** `no_time_media/lib/core/models/post_draft.dart`

Do NOT use `@freezed`. Hive generator requires plain classes with `@HiveType` / `@HiveField` annotations and a concrete (non-factory) constructor.

```dart
import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'post_draft.g.dart';

@HiveType(typeId: 0)
class PostDraft extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String assetId;
  @HiveField(2) final Uint8List thumbnail;  // 256×256 JPEG bytes
  @HiveField(3)       String caption;
  @HiveField(4)       List<String> hashtags;
  @HiveField(5) final String platform;          // 'instagram' | 'twitter' | ...
  @HiveField(6) final String engagementRationale;
  @HiveField(7) final DateTime createdAt;
  @HiveField(8)       bool isShared;
  @HiveField(9)       String? userEditedCaption;

  PostDraft({
    required this.id,
    required this.assetId,
    required this.thumbnail,
    required this.caption,
    required this.hashtags,
    required this.platform,
    required this.engagementRationale,
    required this.createdAt,
    this.isShared = false,
    this.userEditedCaption,
  });

  /// The text actually shown to the user (edited takes priority).
  String get effectiveCaption => userEditedCaption ?? caption;
}
```

`caption`, `hashtags`, `isShared`, and `userEditedCaption` are mutable (no `final`) so the editor can update them in-place before saving.

After creating this file, run:
```
dart run build_runner build --delete-conflicting-outputs
```

This generates `post_draft.g.dart` containing `PostDraftAdapter`.

---

## Step 3 — Create `SocialPlatform` enum

**File:** `no_time_media/lib/core/models/social_platform.dart`

Plain Dart enum — no Hive annotation needed (platform is stored as a String in PostDraft).

```dart
enum SocialPlatform {
  instagram,
  twitter,
  facebook,
  tiktok;

  String get displayName => switch (this) {
    SocialPlatform.instagram => 'Instagram',
    SocialPlatform.twitter   => 'Twitter / X',
    SocialPlatform.facebook  => 'Facebook',
    SocialPlatform.tiktok    => 'TikTok',
  };

  bool get isActive => this == SocialPlatform.instagram;

  static SocialPlatform fromString(String value) =>
      SocialPlatform.values.firstWhere(
        (e) => e.name == value,
        orElse: () => SocialPlatform.instagram,
      );
}
```

---

## Step 4 — Hive initialisation in `main.dart`

Add Hive init **after** `Supabase.initialize` and **before** `runApp`:

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:no_time_media/core/models/post_draft.dart';

// Inside main(), after Supabase.initialize:
await Hive.initFlutter();
Hive.registerAdapter(PostDraftAdapter());
await Hive.openBox<PostDraft>('drafts');
await Hive.openBox('prefs');
```

---

## Step 5 — Create `DraftService`

**File:** `no_time_media/lib/core/services/draft_service.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:no_time_media/core/models/post_draft.dart';

class DraftService {
  static Box<PostDraft> get _box => Hive.box<PostDraft>('drafts');

  static Future<void> save(PostDraft draft) async {
    await _box.put(draft.id, draft);
  }

  static Future<void> delete(String id) async {
    await _box.delete(id);
  }

  /// All drafts sorted newest first.
  static List<PostDraft> getAll() {
    final drafts = _box.values.toList();
    drafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return drafts;
  }

  /// Stream that emits a new sorted list whenever the box changes.
  static Stream<List<PostDraft>> watch() {
    return _box.watch().map((_) => getAll());
  }
}
```

---

## Step 6 — Update `GenerationNotifier`

**File:** `no_time_media/lib/core/providers/generation_provider.dart`

The notifier must now:
1. Call `AIService.generatePosts(photos)` — which returns `AIGenerationResponse` and fetched thumbnail bytes.
2. For each `PhotoResult`, look up the thumbnail bytes and construct a `PostDraft`.
3. Expose `List<PostDraft>` as state.

**Problem:** `AIService.generatePosts` currently fetches thumbnails internally and discards the bytes after base64-encoding. The `GenerationNotifier` also needs those bytes to populate `PostDraft.thumbnail`.

**Solution:** Change `AIService.generatePosts` to return a `GenerationBundle` that includes both the `AIGenerationResponse` and a `Map<String, Uint8List>` (assetId → thumbnail bytes).

### 6a — Add `GenerationBundle` to `ai_models.dart`

```dart
import 'dart:typed_data';

class GenerationBundle {
  final AIGenerationResponse response;
  final Map<String, Uint8List> thumbnails; // assetId → bytes

  GenerationBundle({required this.response, required this.thumbnails});
}
```

### 6b — Update `AIService.generatePosts` return type

Change signature: `Future<AIGenerationResponse>` → `Future<GenerationBundle>`

Inside the method, build a parallel `Map<String, Uint8List> thumbnailMap` as you fetch each thumbnail:

```dart
final thumbnailMap = <String, Uint8List>{};

for (final photo in photos) {
  final entity = AssetEntity(id: photo.id, typeInt: 1,
      width: photo.width, height: photo.height);
  final bytes = await entity.thumbnailDataWithSize(
      const ThumbnailSize(256, 256));
  if (bytes == null) continue;
  thumbnailMap[photo.id] = bytes;              // ← store for PostDraft
  photoInputs.add({
    'assetId': photo.id,
    'thumbnailBase64': base64Encode(bytes),
    ...
  });
}

// At the end, return bundle:
return GenerationBundle(
  response: AIGenerationResponse(selectedPhotos: results),
  thumbnails: thumbnailMap,
);
```

### 6c — Rewrite `GenerationNotifier`

```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:no_time_media/core/services/ai_service.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/models/post_draft.dart';

final generationProvider =
    AsyncNotifierProvider<GenerationNotifier, List<PostDraft>>(
  GenerationNotifier.new,
);

class GenerationNotifier extends AsyncNotifier<List<PostDraft>> {
  @override
  Future<List<PostDraft>> build() async => [];

  Future<void> generatePosts(List<ScoredPhoto> photos) async {
    state = const AsyncLoading();
    try {
      final bundle = await AIService.generatePosts(photos);
      final drafts = bundle.response.selectedPhotos.map((result) {
        final thumb = bundle.thumbnails[result.assetId] ?? Uint8List(0);
        return PostDraft(
          id: const Uuid().v4(),
          assetId: result.assetId,
          thumbnail: thumb,
          caption: result.caption,
          hashtags: result.hashtags,
          platform: result.bestPlatform,
          engagementRationale: result.engagementRationale,
          createdAt: DateTime.now(),
        );
      }).toList();
      state = AsyncData(drafts);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
```

`uuid` package — add to `pubspec.yaml` if not present: `uuid: ^4.0.0`.

---

## Step 7 — Navigate to editor after generation

**File:** `no_time_media/lib/features/photo_scan/photo_scan_screen.dart`

In the FAB `onPressed`, after `await ref.read(generationProvider.notifier).generatePosts(photos)` completes, check the state and navigate:

```dart
final result = ref.read(generationProvider);
result.whenData((drafts) {
  if (drafts.isNotEmpty && context.mounted) {
    context.push('/editor', extra: drafts);
  }
});
```

Also add a `ref.listen` to watch for generation errors and show a snackbar:

```dart
ref.listen<AsyncValue<List<PostDraft>>>(generationProvider, (prev, next) {
  next.whenOrNull(
    error: (e, _) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Generation failed: $e')));
      }
    },
  );
});
```

Put the `ref.listen` call inside `build()`, before the `return Scaffold(...)`.

---

## Step 8 — Create `PostEditorScreen`

**File:** `no_time_media/lib/features/post_editor/post_editor_screen.dart`

Takes `List<PostDraft> drafts` via go_router `extra`. Supports swiping between drafts with a `PageView`.

### Minimal required layout (match `docs/features/03-post-editor.md`):

```
AppBar: "← Back  |  No Time Media  |  1/3 (page indicator)"
Body:
  PageView (one page per draft):
    - Photo thumbnail (Image.memory, aspect 1:1, full width)
    - Platform badge (e.g. "📷 Instagram")
    - Engagement rationale (collapsible grey text, 1 line by default)
    - Caption TextField (multiline, char counter 0/300, editable in-place)
    - Hashtag chips row (horizontal scroll, each chip has an ×)
    - [Edit Hashtags] button → opens hashtag editor bottom sheet
Bottom bar:
  [Regenerate]  [Save Draft]  [Share ↗]
```

### Caption editing:

- `caption` edits update `draft.userEditedCaption` immediately.
- "Undo" icon resets `draft.userEditedCaption = null` (restores AI caption).
- No modal bottom sheet needed for caption — edit directly in the `TextField`.
- Character limit enforced via `inputFormatters: [LengthLimitingTextInputFormatter(300)]`.

### Hashtag editor bottom sheet:

- `showModalBottomSheet` with a `TextField` for adding tags and a `Wrap` of dismissible chips.
- On close, update `draft.hashtags` with the new list.

### Save Draft button:

```dart
await DraftService.save(draft);
ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(content: Text('Draft saved')));
```

### Regenerate button:

```dart
await ref.read(generationProvider.notifier).generatePosts(originalPhotos);
// Replace current drafts from the updated provider state.
// originalPhotos must be passed in from the scan screen — see routing below.
```

**Regenerate** counts as a new generation. For Phase 4 the daily limit check is not enforced (that is Phase 5). Simply make the call.

### Share button:

See Step 9 below. After the share sheet returns, show "Did you share it?" dialog. On confirm → `draft.isShared = true; DraftService.save(draft)`.

---

## Step 9 — Create `ShareService`

**File:** `no_time_media/lib/core/services/share_service.dart`

```dart
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:no_time_media/core/models/post_draft.dart';

class ShareService {
  static Future<void> sharePost(PostDraft draft) async {
    // 1. Compose full caption text
    final hashtagString = draft.hashtags.map((h) => '#$h').join(' ');
    final fullCaption =
        '${draft.effectiveCaption}\n\n$hashtagString';

    // 2. Copy caption to clipboard (Instagram doesn't accept text from share sheet)
    await Clipboard.setData(ClipboardData(text: fullCaption));

    // 3. Get full-resolution photo file
    final entity = AssetEntity(
      id: draft.assetId,
      typeInt: 1,
      width: 0,
      height: 0,
    );
    final file = await entity.file;
    if (file == null) throw Exception('Could not access photo file');

    // 4. Trigger OS share sheet
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: fullCaption,
      ),
    );
  }
}
```

`share_plus` is already in `pubspec.yaml`. Do not add it again.

After calling `ShareService.sharePost(draft)`, show the "Did you share it?" dialog in `PostEditorScreen`.

---

## Step 10 — Create `DraftHistoryScreen`

**File:** `no_time_media/lib/features/draft_history/draft_history_screen.dart`

```dart
// Provider
final draftHistoryProvider = StreamProvider<List<PostDraft>>((ref) {
  return DraftService.watch();
});
```

### Layout:

- `ListView.builder` over `drafts` list.
- Each `ListTile`:
  - `leading`: `Image.memory(draft.thumbnail, width: 56, height: 56, fit: BoxFit.cover)`
  - `title`: `draft.effectiveCaption` (max 2 lines, overflow ellipsis)
  - `subtitle`: `"${draft.platform} · ${_formatDate(draft.createdAt)}"`
  - `trailing`: share badge if `draft.isShared`
- `Dismissible` wrapping each tile, direction `DismissDirection.endToStart`, on dismiss:
  ```dart
  showDialog(/* confirm */).then((confirmed) {
    if (confirmed == true) DraftService.delete(draft.id);
  });
  ```
- Tapping a tile: `context.push('/editor', extra: [draft])` (opens editor in single-draft view).
- Empty state: `Center(child: Column(children: [Icon(Icons.drafts_outlined), Text('No saved drafts yet')]))`.

Put the `draftHistoryProvider` in `no_time_media/lib/core/providers/draft_history_provider.dart` (not inside the screen file).

---

## Step 11 — Update routing and add bottom navigation

### 11a — Update `router.dart`

```dart
import 'package:go_router/go_router.dart';
import 'package:no_time_media/features/photo_scan/photo_scan_screen.dart';
import 'package:no_time_media/features/post_editor/post_editor_screen.dart';
import 'package:no_time_media/features/draft_history/draft_history_screen.dart';
import 'package:no_time_media/core/models/post_draft.dart';

final appRouter = GoRouter(
  initialLocation: '/scan',
  routes: [
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

The `/editor` route is outside the `ShellRoute` so it has no bottom nav bar (full-screen).

### 11b — Create `AppShell`

**File:** `no_time_media/lib/core/widgets/app_shell.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = location == '/drafts' ? 1 : 0;

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i == 0) context.go('/scan');
          if (i == 1) context.go('/drafts');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo_library), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.drafts),        label: 'Drafts'),
        ],
      ),
    );
  }
}
```

Remove the duplicate `GoRoute(path: '/')` from router — `initialLocation: '/scan'` replaces it.

---

## Step 12 — Pass `originalPhotos` through to Regenerate

The Regenerate button in `PostEditorScreen` must re-call `generatePosts(originalPhotos)`. The original `List<ScoredPhoto>` is available in `photoScanProvider`. Pass it from the scan screen to the editor either:

- As a second field in the `extra` object (use a record or a small plain class `EditorArgs{drafts, photos}`), or
- By reading it from `ref.read(photoScanProvider).requireValue` inside the editor (simpler — the provider is still live).

**Use the simpler approach:** read `photoScanProvider` inside `PostEditorScreen` with `ref.read`. No extra argument needed.

`PostEditorScreen` must be a `ConsumerStatefulWidget` so it can use both `ref` and local `PageController` state.

---

## Step 13 — Wire `ai_models.dart` import cleanup

After Step 6b, `ai_models.dart` should contain:
- `PhotoResult`
- `AIGenerationResponse`
- `GenerationBundle`

Remove `PhotoInfo`, `Components`, and `PlatformContent` if they still exist — they are replaced by the new flow.

---

## File structure after Phase 4

```
lib/
  core/
    models/
      photo_entity.dart      (existing)
      scored_photo.dart      (existing)
      post_draft.dart        ← NEW (Step 2)
      post_draft.g.dart      ← generated
      social_platform.dart   ← NEW (Step 3)
      ai_models.dart         (updated: GenerationBundle added)
    providers/
      photo_scan_provider.dart   (existing)
      generation_provider.dart   (updated: Step 6c)
      draft_history_provider.dart ← NEW (Step 10)
    services/
      photo_service.dart     (existing)
      scoring_service.dart   (existing)
      ai_service.dart        (updated: Step 6b)
      draft_service.dart     ← NEW (Step 5)
      share_service.dart     ← NEW (Step 9)
    router.dart              (updated: Step 11a)
    widgets/
      app_shell.dart         ← NEW (Step 11b)
  features/
    photo_scan/
      photo_scan_screen.dart (updated: Step 7)
    post_editor/
      post_editor_screen.dart ← NEW (Step 8)
    draft_history/
      draft_history_screen.dart ← NEW (Step 10)
  main.dart                  (updated: Step 4)
  app.dart                   (existing, clean)
```

---

## Build sequence

1. Delete `lib/models/` (Step 1).
2. Create `PostDraft`, `SocialPlatform`, `GenerationBundle` models (Steps 2, 3, 13).
3. Run `dart run build_runner build --delete-conflicting-outputs` to generate `PostDraftAdapter`.
4. Add Hive init to `main.dart` (Step 4).
5. Create services: `DraftService`, `ShareService` (Steps 5, 9).
6. Update `AIService` and `GenerationNotifier` (Steps 6a–c).
7. Create screens: `PostEditorScreen`, `DraftHistoryScreen` (Steps 8, 10).
8. Update routing + add `AppShell` (Step 11).
9. Update `PhotoScanScreen` FAB navigation (Step 7).
10. Run `flutter analyze` — fix all errors before running.
11. Run app on device/simulator and verify:
    - FAB → editor opens with photo and caption.
    - Caption editable; char count updates.
    - Hashtag chips scrollable; edit sheet works.
    - Save Draft → appears in Drafts tab.
    - Swipe to delete in Drafts tab works.
    - Share button opens OS share sheet.

---

## What is NOT in scope for Phase 4

- Subscription / paywall gating (Phase 5)
- Daily generation limit enforcement (Phase 5)
- Auth / user sign-in (Phase 5)
- RevenueCat integration (Phase 5)
- Usage tracking in Supabase (Phase 5)
- Settings screen (Phase 5)
- Twitter / Facebook / TikTok platform-specific share logic (post-v1)
