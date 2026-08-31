# Feature Spec 04 — Sharing

## Purpose

Allow the user to share a completed post draft to Instagram (and, in future, other platforms) via the OS native share sheet.

## Share Flow

1. User taps "Share" in the Post Editor screen
2. App composes the share payload: photo + caption + hashtags
3. OS native share sheet appears
4. User selects target app (Instagram, Notes, Messages, etc.)
5. On return from share sheet, app marks draft `isShared = true`

## Share Payload Construction

```dart
// ShareService
Future<void> sharePost(PostDraft draft, AssetEntity photo) async {
  // 1. Get full-resolution photo file
  final file = await photo.file;

  // 2. Compose caption string
  final hashtagString = draft.hashtags.map((h) => '#$h').join(' ');
  final fullCaption = '${draft.userEditedCaption ?? draft.caption}\n\n$hashtagString';

  // 3. Share via OS sheet
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file!.path)],
      text: fullCaption,
    ),
  );
}
```

## Instagram-Specific Behaviour

The iOS/Android Instagram app accepts images from the share sheet but **does not** auto-populate the caption from the shared text. The caption text is copied to the clipboard automatically before triggering the share sheet, and a tooltip is shown:

> "Caption copied to clipboard — paste it in Instagram"

```dart
await Clipboard.setData(ClipboardData(text: fullCaption));
// Then trigger share sheet
```

## Deep-Link Sharing (Instagram, Future Platforms)

For a smoother Instagram experience (no share sheet friction), the app can use the Instagram URL scheme:

```
instagram://camera
```

This opens the Instagram camera/story composer. However, this only works on iOS, requires Instagram to be installed, and does not pre-populate the caption. Use OS share sheet as primary mechanism; deep links are a future enhancement.

## v1 Scope

- OS share sheet only (`share_plus`)
- Clipboard copy of caption before share
- No direct Instagram API integration
- No Twitter/Facebook/TikTok direct share (share sheet covers all)

## After Share

After the share sheet is dismissed (regardless of whether the user actually posted):

1. Show a "Did you share it?" confirmation dialog
2. If user confirms → `draft.isShared = true`, save to Isar, show success animation
3. If user cancels → no state change

## Dependencies

- `share_plus: ^9.0.0`
- `flutter/services.dart` (Clipboard)
- `photo_manager` (to access full-res photo file)
