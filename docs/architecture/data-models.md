# Data Models — No Time Media

All models use `freezed` for immutability and `json_serializable` for serialization unless noted.

---

## ScoredPhoto

Represents a device photo after on-device ML scoring. Ephemeral — never persisted.

```dart
@freezed
class ScoredPhoto with _$ScoredPhoto {
  const factory ScoredPhoto({
    required String assetId,         // photo_manager AssetEntity.id
    required DateTime dateTaken,
    required double compositeScore,  // 0.0–1.0
    required double recencyScore,
    required double aestheticScore,
    required double noveltyScore,
    required double faceScore,
    required Uint8List thumbnail,    // 256x256 px, used for AI call
    String? localPath,               // full-res path, loaded on demand
  }) = _ScoredPhoto;
}
```

---

## PostDraft

A generated post prototype. Persisted in Isar (local DB) and returned from the AI.

```dart
@freezed
class PostDraft with _$PostDraft {
  const factory PostDraft({
    required String id,                    // UUID
    required String assetId,               // source photo
    required Uint8List thumbnail,          // 256x256 px snapshot
    required String caption,              // editable by user
    required List<String> hashtags,
    required SocialPlatform platform,
    required String engagementRationale,  // AI explanation (shown in UI)
    required DateTime createdAt,
    @Default(false) bool isShared,
    String? userEditedCaption,            // null if user has not edited
  }) = _PostDraft;

  factory PostDraft.fromJson(Map<String, dynamic> json) =>
      _$PostDraftFromJson(json);
}
```

**Isar collection:** `PostDraftCollection` — id is the Isar primary key.

---

## SocialPlatform

```dart
enum SocialPlatform {
  instagram,   // ACTIVE in v1
  twitter,     // STUBBED — not shown in UI yet
  facebook,    // STUBBED — not shown in UI yet
  tiktok,      // STUBBED — not shown in UI yet
}

extension SocialPlatformX on SocialPlatform {
  String get displayName => switch (this) {
    SocialPlatform.instagram => 'Instagram',
    SocialPlatform.twitter   => 'Twitter / X',
    SocialPlatform.facebook  => 'Facebook',
    SocialPlatform.tiktok    => 'TikTok',
  };

  bool get isActive => this == SocialPlatform.instagram;
}
```

---

## AIGenerationRequest

What the Flutter app sends to the Supabase Edge Function.

```dart
@freezed
class AIGenerationRequest with _$AIGenerationRequest {
  const factory AIGenerationRequest({
    required String userId,
    required List<AIPhotoInput> photos,    // thumbnails as base64
    required SocialPlatform targetPlatform,
  }) = _AIGenerationRequest;

  factory AIGenerationRequest.fromJson(Map<String, dynamic> json) =>
      _$AIGenerationRequestFromJson(json);
}

@freezed
class AIPhotoInput with _$AIPhotoInput {
  const factory AIPhotoInput({
    required String assetId,
    required String thumbnailBase64,     // JPEG thumbnail, base64-encoded
    required double compositeScore,      // on-device score provided as context
    required DateTime dateTaken,
  }) = _AIPhotoInput;

  factory AIPhotoInput.fromJson(Map<String, dynamic> json) =>
      _$AIPhotoInputFromJson(json);
}
```

---

## AIGenerationResponse

What the Supabase Edge Function returns after calling the cloud AI.

```dart
@freezed
class AIGenerationResponse with _$AIGenerationResponse {
  const factory AIGenerationResponse({
    required List<AIPhotoResult> selectedPhotos,
  }) = _AIGenerationResponse;

  factory AIGenerationResponse.fromJson(Map<String, dynamic> json) =>
      _$AIGenerationResponseFromJson(json);
}

@freezed
class AIPhotoResult with _$AIPhotoResult {
  const factory AIPhotoResult({
    required String assetId,
    required String caption,
    required List<String> hashtags,
    required SocialPlatform bestPlatform,
    required String engagementRationale,
  }) = _AIPhotoResult;

  factory AIPhotoResult.fromJson(Map<String, dynamic> json) =>
      _$AIPhotoResultFromJson(json);
}
```

---

## UserSubscription

Subscription state fetched from RevenueCat + Supabase. Held in memory via Riverpod.

```dart
@freezed
class UserSubscription with _$UserSubscription {
  const factory UserSubscription({
    required SubscriptionTier tier,
    required int dailyGenerationsUsed,
    required int dailyGenerationLimit,   // 3 for free, 20 for pro
    required DateTime? expiresAt,
  }) = _UserSubscription;
}

enum SubscriptionTier { free, pro }
```

---

## Hive Storage

**Note:** Isar was replaced with Hive due to an Android namespace conflict in Isar 3.x with Android Gradle Plugin ≥8.0.

Two Hive boxes are persisted on device:

### `drafts` box — `Box<PostDraft>`
- Key: `id` (String UUID)
- Sorted by `createdAt` in the UI layer (Hive does not sort; sort in Dart after fetch)

### `prefs` box — `Box<dynamic>` (LazyBox or plain Box)
- Singleton box; use string keys: `'defaultPhotoCount'`, `'preferredAIProvider'`

### PostDraft Hive Annotations

```dart
@HiveType(typeId: 0)
class PostDraft {
  @HiveField(0) final String id;
  @HiveField(1) final String assetId;
  @HiveField(2) final Uint8List thumbnail;
  @HiveField(3) final String caption;
  @HiveField(4) final List<String> hashtags;
  @HiveField(5) final String platform;       // store as string, parse to SocialPlatform
  @HiveField(6) final String engagementRationale;
  @HiveField(7) final DateTime createdAt;
  @HiveField(8) final bool isShared;
  @HiveField(9) final String? userEditedCaption;
}
```

Run `dart run build_runner build` after adding/changing `@HiveField` annotations to regenerate `PostDraftAdapter`.

Initialize in `main.dart`:
```dart
await Hive.initFlutter();
Hive.registerAdapter(PostDraftAdapter());
await Hive.openBox<PostDraft>('drafts');
await Hive.openBox('prefs');
```

### UserPreferencesCollection
- Box name: `'prefs'`
- Stores: `defaultPhotoCount` (int, 10–50), `preferredAIProvider` (String)

---

## JSON Contract — AI Response (raw, from Edge Function)

```json
{
  "selectedPhotos": [
    {
      "assetId": "string",
      "caption": "string",
      "hashtags": ["string"],
      "bestPlatform": "instagram",
      "engagementRationale": "string"
    }
  ]
}
```

The Edge Function validates this schema before returning it to the app. If the AI returns malformed JSON, the Edge Function retries once, then returns a structured error.
