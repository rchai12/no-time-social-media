# Phase 8 — Observability, Caption Styles & Content Tools

**Depends on:** Phase 7 shipped to App Store / Play Store.
**Version target:** v1.1.0

This is the first post-launch release. It has four independent tracks that can be implemented in parallel once Phase 7 is complete.

---

## Track A — Crash Reporting & Analytics (Firebase)

### Why first

Without observability you are flying blind after launch. Track A should be merged before any users download the app.

### A1 — Add Firebase packages

Add to `pubspec.yaml` dependencies:

```yaml
firebase_core: ^3.0.0
firebase_analytics: ^11.0.0
firebase_crashlytics: ^4.0.0
```

Run `flutter pub get`.

### A2 — FlutterFire CLI setup

🧑 **Human task — do this once before the agent writes any code:**

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# From the no_time_media/ Flutter project root:
flutterfire configure \
  --project=<your-firebase-project-id> \
  --platforms=ios,android
```

This generates `lib/firebase_options.dart` and places:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Both files contain project config (not secrets) but should still be added to `.gitignore` if the repo is public. For a private repo, committing them is fine.

Also add to `android/build.gradle.kts` (root-level, not app-level):
```kotlin
plugins {
  id("com.google.gms.google-services") version "4.4.2" apply false
  id("com.google.firebase.crashlytics") version "3.0.2" apply false
}
```

And to `android/app/build.gradle.kts`:
```kotlin
plugins {
  id("com.google.gms.google-services")
  id("com.google.firebase.crashlytics")
}
```

### A3 — Initialize Firebase in `main.dart`

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';

// In main(), before runApp:
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// Route all Flutter errors to Crashlytics
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

// Route all async errors in the zone to Crashlytics
// (wrap runApp with a PlatformDispatcher.instance.onError handler instead)
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};

// Disable Crashlytics collection in debug builds
await FirebaseCrashlytics.instance
    .setCrashlyticsCollectionEnabled(kReleaseMode);
```

### A4 — Create `AnalyticsService`

**File:** `no_time_media/lib/core/services/analytics_service.dart`

Define a typed service so event names and parameters are never scattered as raw strings:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final _analytics = FirebaseAnalytics.instance;

  // ── Scan ──────────────────────────────────────────────────────────────────

  static Future<void> scanStarted({required int photoCount}) =>
      _analytics.logEvent(
        name: 'scan_started',
        parameters: {'photo_count': photoCount},
      );

  static Future<void> scoringCompleted({
    required int photoCount,
    required int durationMs,
  }) =>
      _analytics.logEvent(
        name: 'scoring_completed',
        parameters: {
          'photo_count': photoCount,
          'duration_ms': durationMs,
        },
      );

  // ── Generation ────────────────────────────────────────────────────────────

  static Future<void> generationRequested({
    required int selectedCount,
    required String tier,
    required String tone,
  }) =>
      _analytics.logEvent(
        name: 'generation_requested',
        parameters: {
          'selected_count': selectedCount,
          'tier': tier,
          'tone': tone,
        },
      );

  static Future<void> generationSucceeded({required int draftCount}) =>
      _analytics.logEvent(
        name: 'generation_succeeded',
        parameters: {'draft_count': draftCount},
      );

  static Future<void> generationFailed({required String errorType}) =>
      _analytics.logEvent(
        name: 'generation_failed',
        parameters: {'error_type': errorType},
      );

  // ── Editor ────────────────────────────────────────────────────────────────

  static Future<void> draftSaved({required String platform}) =>
      _analytics.logEvent(
        name: 'draft_saved',
        parameters: {'platform': platform},
      );

  static Future<void> captionEdited() =>
      _analytics.logEvent(name: 'caption_edited');

  static Future<void> hashtagsEdited() =>
      _analytics.logEvent(name: 'hashtags_edited');

  static Future<void> platformOverridden({
    required String from,
    required String to,
  }) =>
      _analytics.logEvent(
        name: 'platform_overridden',
        parameters: {'from': from, 'to': to},
      );

  // ── Share ─────────────────────────────────────────────────────────────────

  static Future<void> postShared({required String platform}) =>
      _analytics.logEvent(
        name: 'post_shared',
        parameters: {'platform': platform},
      );

  // ── Subscription ──────────────────────────────────────────────────────────

  static Future<void> paywallViewed({required String trigger}) =>
      _analytics.logEvent(
        name: 'paywall_viewed',
        parameters: {'trigger': trigger}, // 'monthly_limit' | 'daily_limit'
      );

  static Future<void> subscriptionPurchased() =>
      _analytics.logEvent(name: 'subscription_purchased');

  static Future<void> subscriptionRestored() =>
      _analytics.logEvent(name: 'subscription_restored');

  // ── User properties ───────────────────────────────────────────────────────

  static Future<void> setUserTier(String tier) =>
      _analytics.setUserProperty(name: 'subscription_tier', value: tier);
}
```

### A5 — Wire analytics call sites

Add calls at the following locations. These are additive — do not change existing logic:

| File | Where | Call |
|---|---|---|
| `photo_scan_provider.dart` | Start of `build()` | `AnalyticsService.scanStarted(photoCount: count)` |
| `photo_scan_provider.dart` | After `scoreAll` completes | `AnalyticsService.scoringCompleted(photoCount, durationMs)` |
| `generation_provider.dart` | Start of `generatePosts()` | `AnalyticsService.generationRequested(...)` |
| `generation_provider.dart` | On `AsyncData` | `AnalyticsService.generationSucceeded(draftCount: drafts.length)` |
| `generation_provider.dart` | On `AsyncError` | `AnalyticsService.generationFailed(errorType: e.runtimeType.toString())` |
| `post_editor_screen.dart` | Save Draft tapped | `AnalyticsService.draftSaved(platform: draft.platform)` |
| `post_editor_screen.dart` | Caption edited | `AnalyticsService.captionEdited()` |
| `share_service.dart` | After share completes | `AnalyticsService.postShared(platform: draft.platform)` |
| `paywall_screen.dart` | `initState` | `AnalyticsService.paywallViewed(trigger: ...)` |
| `paywall_screen.dart` | After purchase | `AnalyticsService.subscriptionPurchased()` |
| `paywall_screen.dart` | After restore | `AnalyticsService.subscriptionRestored()` |

For `scoringCompleted`, capture the start time before `scoreAll`:
```dart
final stopwatch = Stopwatch()..start();
final scored = await ScoringService.scoreAll(photos);
stopwatch.stop();
await AnalyticsService.scoringCompleted(
  photoCount: photos.length,
  durationMs: stopwatch.elapsedMilliseconds,
);
```

### A6 — Set Firebase user ID on auth

In the auth flow (Phase 5 `AuthScreen`) after successful sign-in/sign-up, set the Firebase Analytics user ID to the Supabase user ID so crash reports and analytics can be correlated:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

await FirebaseAnalytics.instance
    .setUserId(id: Supabase.instance.client.auth.currentUser!.id);
```

Also set the subscription tier user property when the subscription state is known:
```dart
await AnalyticsService.setUserTier(isPro ? 'pro' : 'free');
```

---

## Track B — Caption Tone / Style

Users want captions that match their personal brand voice. This surfaces that control without adding complexity to the main generation flow.

### B1 — Add `CaptionTone` enum

**File:** `no_time_media/lib/core/models/caption_tone.dart`

```dart
enum CaptionTone {
  casual,
  professional,
  funny,
  inspirational,
  minimal;

  String get displayName => switch (this) {
    CaptionTone.casual        => 'Casual',
    CaptionTone.professional  => 'Professional',
    CaptionTone.funny         => 'Funny',
    CaptionTone.inspirational => 'Inspirational',
    CaptionTone.minimal       => 'Minimal',
  };

  String get description => switch (this) {
    CaptionTone.casual        => 'Conversational, like texting a friend',
    CaptionTone.professional  => 'Polished, brand-appropriate',
    CaptionTone.funny         => 'Playful with personality and wit',
    CaptionTone.inspirational => 'Uplifting with emotional resonance',
    CaptionTone.minimal       => 'Short and impactful, under 50 words',
  };

  /// Instruction appended to the AI system prompt.
  String get promptInstruction => switch (this) {
    CaptionTone.casual =>
      'Write captions in a casual, conversational tone — like a real person talking to friends. Natural language, no corporate feel.',
    CaptionTone.professional =>
      'Write captions in a professional, polished tone — appropriate for a brand or business. Confident and authoritative.',
    CaptionTone.funny =>
      'Write captions with playful humour and personality. Use wit, wordplay, or light sarcasm where appropriate. Keep it tasteful.',
    CaptionTone.inspirational =>
      'Write captions that are uplifting and emotionally resonant. Focus on meaning, growth, or connection.',
    CaptionTone.minimal =>
      'Write captions that are short and punchy — 50 words maximum. Let the photo do most of the talking.',
  };

  static CaptionTone fromString(String value) =>
      CaptionTone.values.firstWhere(
        (e) => e.name == value,
        orElse: () => CaptionTone.casual,
      );
}
```

### B2 — Add tone to `PrefsService`

```dart
static const _keyCaptionTone = 'captionTone';

static CaptionTone get captionTone =>
    CaptionTone.fromString((_box.get(_keyCaptionTone) as String?) ?? 'casual');

static Future<void> setCaptionTone(CaptionTone tone) =>
    _box.put(_keyCaptionTone, tone.name);
```

### B3 — Add `captionToneProvider`

**File:** `no_time_media/lib/core/providers/settings_provider.dart`

Add alongside the existing `photoCountProvider`:

```dart
final captionToneProvider = NotifierProvider<CaptionToneNotifier, CaptionTone>(
  CaptionToneNotifier.new,
);

class CaptionToneNotifier extends Notifier<CaptionTone> {
  @override
  CaptionTone build() => PrefsService.captionTone;

  Future<void> setTone(CaptionTone tone) async {
    await PrefsService.setCaptionTone(tone);
    state = tone;
  }
}
```

### B4 — Add tone selector to `SettingsScreen`

Add a new section **"Content"** above the Subscription section:

```dart
// Section header
const ListTile(title: Text('Content', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey))),

// Tone tile
Consumer(builder: (context, ref, _) {
  final tone = ref.watch(captionToneProvider);
  return ListTile(
    title: const Text('Caption Style'),
    subtitle: Text(tone.displayName),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => _showToneSheet(context, ref, tone),
  );
}),
```

`_showToneSheet` — modal bottom sheet with a radio list of all five tones:

```dart
void _showToneSheet(BuildContext context, WidgetRef ref, CaptionTone current) {
  showModalBottomSheet(
    context: context,
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Caption Style',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ...CaptionTone.values.map((tone) => RadioListTile<CaptionTone>(
          value: tone,
          groupValue: current,
          title: Text(tone.displayName),
          subtitle: Text(tone.description,
              style: const TextStyle(fontSize: 12)),
          onChanged: (t) {
            if (t != null) {
              ref.read(captionToneProvider.notifier).setTone(t);
              Navigator.pop(context);
            }
          },
        )),
        const SizedBox(height: 16),
      ],
    ),
  );
}
```

### B5 — Pass tone through `AIService` to edge function

**`AIService.generatePosts`:** Add `tone` to the request body:

```dart
import 'package:no_time_media/core/services/prefs_service.dart';
import 'package:no_time_media/core/models/caption_tone.dart';

// Inside generatePosts, alongside other body fields:
final tone = PrefsService.captionTone;

final response = await _supabase.functions.invoke(
  'generate-post',
  body: {
    'photos': photoInputs,
    'targetPlatform': 'instagram',
    'tone': tone.name,              // ← NEW
  },
);
```

### B6 — Use tone in edge function system prompt

**`supabase/functions/generate-post/index.ts`:**

Read `tone` from the request body and append the instruction to the system prompt:

```typescript
const { photos, targetPlatform, tone = 'casual' } = await req.json();

// Map tone name to instruction
const TONE_INSTRUCTIONS: Record<string, string> = {
  casual:        'Write captions in a casual, conversational tone — like a real person talking to friends.',
  professional:  'Write captions in a professional, polished tone — appropriate for a brand or business.',
  funny:         'Write captions with playful humour and personality. Use wit and wordplay.',
  inspirational: 'Write captions that are uplifting and emotionally resonant.',
  minimal:       'Write captions that are short and punchy — 50 words maximum.',
};

const toneInstruction = TONE_INSTRUCTIONS[tone] ?? TONE_INSTRUCTIONS['casual'];

// Append to the SYSTEM_PROMPT:
const fullPrompt = `${SYSTEM_PROMPT}\n\nCaption tone: ${toneInstruction}`;
```

Pass `fullPrompt` instead of `SYSTEM_PROMPT` to the AI provider call.

---

## Track C — Platform Override & Character Limits

Currently `PostDraft.platform` is set by the AI and cannot be changed. Users should be able to override the platform before sharing.

### C1 — Platform limits and hashtag guidance

**File:** `no_time_media/lib/core/models/social_platform.dart`

Add to the `SocialPlatform` extension:

```dart
extension SocialPlatformX on SocialPlatform {
  // ...existing displayName and isActive...

  /// Maximum caption character count for this platform.
  int get captionLimit => switch (this) {
    SocialPlatform.instagram => 2200,
    SocialPlatform.twitter   => 280,
    SocialPlatform.facebook  => 63206,
    SocialPlatform.tiktok    => 2200,
  };

  /// Recommended hashtag count range.
  String get hashtagGuidance => switch (this) {
    SocialPlatform.instagram => '5–10 hashtags recommended',
    SocialPlatform.twitter   => '1–2 hashtags recommended',
    SocialPlatform.facebook  => '1–3 hashtags recommended',
    SocialPlatform.tiktok    => '3–5 hashtags recommended',
  };
}
```

### C2 — Platform chip selector in `PostEditorScreen`

Replace the static platform badge `Text` widget with an interactive chip row.

Add a mutable `_activePlatform` local state field to `_PostEditorScreenState`:

```dart
late SocialPlatform _activePlatform;

@override
void initState() {
  super.initState();
  _activePlatform = SocialPlatform.fromString(widget.drafts.first.platform);
}
```

Replace the platform badge `Widget` with:

```dart
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  child: Row(
    children: SocialPlatform.values.map((platform) {
      final isSelected = platform == _activePlatform;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(platform.displayName),
          selected: isSelected,
          onSelected: (_) {
            final prev = _activePlatform;
            setState(() => _activePlatform = platform);
            if (prev != platform) {
              AnalyticsService.platformOverridden(
                from: prev.name, to: platform.name);
            }
          },
        ),
      );
    }).toList(),
  ),
),
```

### C3 — Dynamic character counter respecting platform limit

The caption `TextField` already has a 300-char counter. Replace the hardcoded limit with the platform-aware limit:

```dart
// Character counter below caption field:
Consumer(builder: (context, ref, _) {
  final limit  = _activePlatform.captionLimit;
  final length = _captionController.text.length;
  final isOver = length > limit;
  return Text(
    '$length / $limit',
    style: TextStyle(
      fontSize: 12,
      color: isOver ? Colors.red : Colors.grey,
    ),
  );
}),
```

Add `_captionController.addListener(() => setState(() {}))` in `initState` so the counter updates in real-time.

### C4 — Hashtag guidance below hashtag chips

Add a small grey helper text beneath the hashtag row:

```dart
Text(
  _activePlatform.hashtagGuidance,
  style: const TextStyle(fontSize: 11, color: Colors.grey),
),
```

### C5 — Persist platform override to `PostDraft` on save

When user saves, use `_activePlatform.name` instead of the original `draft.platform`:

```dart
draft.platform = _activePlatform.name;
await DraftService.save(draft);
```

---

## Track D — Saved Hashtag Sets

Users reuse hashtag groups ("travel photos", "coffee content", "work announcements"). A hashtag library removes the repetitive typing.

### D1 — Create `HashtagSet` Hive model

**File:** `no_time_media/lib/core/models/hashtag_set.dart`

```dart
import 'package:hive/hive.dart';

part 'hashtag_set.g.dart';

@HiveType(typeId: 1)
class HashtagSet extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1)       String name;
  @HiveField(2)       List<String> hashtags;
  @HiveField(3) final DateTime createdAt;

  HashtagSet({
    required this.id,
    required this.name,
    required this.hashtags,
    required this.createdAt,
  });
}
```

Run `dart run build_runner build --delete-conflicting-outputs` to generate `HashtagSetAdapter`.

Register and open the box in `main.dart`:

```dart
Hive.registerAdapter(HashtagSetAdapter());
await Hive.openBox<HashtagSet>('hashtagSets');
```

### D2 — Create `HashtagSetService`

**File:** `no_time_media/lib/core/services/hashtag_set_service.dart`

```dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:no_time_media/core/models/hashtag_set.dart';

class HashtagSetService {
  static Box<HashtagSet> get _box => Hive.box<HashtagSet>('hashtagSets');

  static List<HashtagSet> getAll() {
    final sets = _box.values.toList();
    sets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sets;
  }

  static Future<void> save(HashtagSet set) =>
      _box.put(set.id, set);

  static Future<void> delete(String id) =>
      _box.delete(id);
}
```

### D3 — Add hashtag set UI to the hashtag editor bottom sheet

The hashtag editor bottom sheet (in `PostEditorScreen`) already exists from Phase 4. Extend it with two new sections:

**Section 1 — Saved sets (above the current tag list):**

```dart
if (HashtagSetService.getAll().isNotEmpty) ...[
  const Text('Saved Sets',
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
  const SizedBox(height: 8),
  SizedBox(
    height: 36,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: HashtagSetService.getAll().map((set) =>
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(set.name),
            onPressed: () {
              setState(() {
                // Replace current hashtags with set
                editableHashtags
                  ..clear()
                  ..addAll(set.hashtags);
              });
            },
          ),
        ),
      ).toList(),
    ),
  ),
  const Divider(),
],
```

**Section 2 — Save current tags button (below the tag list):**

```dart
TextButton.icon(
  icon: const Icon(Icons.bookmark_add_outlined, size: 16),
  label: const Text('Save as Hashtag Set'),
  onPressed: () => _showSaveSetDialog(context, editableHashtags),
),
```

`_showSaveSetDialog` shows an `AlertDialog` with a name `TextField`. On confirm:

```dart
final set = HashtagSet(
  id: const Uuid().v4(),
  name: nameController.text.trim(),
  hashtags: List.from(editableHashtags),
  createdAt: DateTime.now(),
);
await HashtagSetService.save(set);
```

### D4 — Hashtag set management in Settings

Add a "Hashtag Library" `ListTile` to the Settings Content section that navigates to a management screen:

**File:** `no_time_media/lib/features/settings/hashtag_library_screen.dart`

Simple `ListView` of all saved sets. Each row:
- Leading: `#` icon
- Title: set name
- Subtitle: tags joined with spaces (first 3 + "..." if more)
- `Dismissible` swipe-to-delete with confirmation

```dart
GoRoute(
  path: '/settings/hashtag-library',
  builder: (context, state) => const HashtagLibraryScreen(),
),
```

---

## File structure after Phase 8

```
lib/
  core/
    models/
      caption_tone.dart          ← NEW (B1)
      hashtag_set.dart           ← NEW (D1)
      hashtag_set.g.dart         ← generated (D1)
    providers/
      settings_provider.dart     ← updated: captionToneProvider (B3)
    services/
      analytics_service.dart     ← NEW (A4)
      hashtag_set_service.dart   ← NEW (D2)
      prefs_service.dart         ← updated: tone getter/setter (B2)
      ai_service.dart            ← updated: tone in request (B5)
  features/
    post_editor/
      post_editor_screen.dart    ← updated: platform chips, char counter (C2–C4)
    settings/
      settings_screen.dart       ← updated: tone selector, hashtag library (B4)
      hashtag_library_screen.dart ← NEW (D4)
  firebase_options.dart          ← generated by FlutterFire CLI (A2)
  main.dart                      ← updated: Firebase init (A3), HashtagSetAdapter (D1)

supabase/
  functions/
    generate-post/
      index.ts                   ← updated: tone in system prompt (B6)
```

---

## pubspec.yaml additions

```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_analytics: ^11.0.0
  firebase_crashlytics: ^4.0.0
```

Run `flutter pub get`.

---

## Build sequence

1. 🧑 Human: create Firebase project + run `flutterfire configure` (A2).
2. Add Firebase packages, run `flutter pub get` (A1).
3. Initialize Firebase + Crashlytics in `main.dart` (A3).
4. Create `AnalyticsService` and wire call sites (A4, A5).
5. Create `CaptionTone` enum + prefs + provider + Settings UI (B1–B4).
6. Update `AIService` to send tone + update edge function (B5, B6).
7. Add platform chips + character limits + hashtag guidance to editor (C1–C4).
8. Create `HashtagSet` model → run `build_runner` → register adapter (D1).
9. Create `HashtagSetService` (D2).
10. Extend hashtag editor with saved sets UI (D3).
11. Create `HashtagLibraryScreen` + Settings link (D4).
12. Run `flutter analyze` — zero errors.
13. Bump `version` in `pubspec.yaml` to `1.1.0+2`.

---

## Verification checklist

- [ ] App crash → appears in Firebase Crashlytics dashboard within 5 minutes
- [ ] Generation event → appears in Firebase Analytics `DebugView`
- [ ] Changing Caption Style in Settings → next generation uses new tone (verify in Supabase Edge Function logs)
- [ ] Switching platform in editor → character counter updates limit; turns red when over
- [ ] Switching platform in editor → hashtag guidance text updates
- [ ] Saving a hashtag set → appears as chip in next hashtag editor open
- [ ] Applying a hashtag set → replaces current hashtags
- [ ] Deleting a hashtag set in library → removed from all editors
- [ ] `flutter analyze` — zero errors
- [ ] `flutter build ipa --release` and `flutter build appbundle --release` both succeed

---

## What is NOT in scope for Phase 8

- Push notifications / re-engagement (Phase 9)
- Cloud draft sync across devices (Phase 9)
- Social login — Google / Apple Sign-In (Phase 9)
- Twitter / TikTok platform-specific AI prompts (the edge function still generates one caption; platform override is a UI-only character limit enforcement for now)
- Draft export as image card (Phase 9)
- A/B testing caption variants (Phase 9)
