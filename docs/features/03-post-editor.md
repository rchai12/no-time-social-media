# Feature Spec 03 — Post Editor & Draft History

## Purpose

After AI generation, present each prototype post to the user for review. Allow in-line caption editing, regeneration, and saving. Maintain a local draft history the user can return to.

## Post Editor Screen

### Entry Point

After the AI returns results, navigate to `PostEditorScreen` with the list of `PostDraft` objects.

### Layout

```
┌─────────────────────────────────────┐
│  ← Back         No Time Media       │
├─────────────────────────────────────┤
│                                     │
│         [Photo Thumbnail]           │
│           (full-width, 1:1)         │
│                                     │
├─────────────────────────────────────┤
│  Platform badge: 📷 Instagram       │
│  Engagement note: "Natural light... │
│  (collapsible, grey text, 1 line)   │
├─────────────────────────────────────┤
│  Caption (editable text field)      │
│  ┌───────────────────────────────┐  │
│  │ Caption text here...          │  │
│  └───────────────────────────────┘  │
│  Char count: 142/300                │
├─────────────────────────────────────┤
│  Hashtags (horizontal scroll chips) │
│  #travel  #goldenhour  #explore ... │
│  [Edit hashtags]                    │
├─────────────────────────────────────┤
│  [Regenerate]    [Save Draft]  [Share] │
└─────────────────────────────────────┘
```

If the AI returned multiple photos, show them as a horizontal page indicator at the top — user swipes between drafts.

### Caption Editing

- Tapping the caption opens a full-screen text editor (modal bottom sheet)
- Character counter updates in real-time
- "Undo" restores the AI-generated caption
- Edits are stored in `PostDraft.userEditedCaption`

### Hashtag Editing

- Tapping [Edit hashtags] opens a tag editor
- User can add, remove, or reorder hashtags
- Stored in `PostDraft.hashtags` (replaced, not appended)

### Regenerate

- Taps "Regenerate" → re-sends same photos to AI → replaces current draft(s)
- Show loading state during regeneration
- Counts as one additional generation against daily limit

### Save Draft

- Saves `PostDraft` to Isar with current (possibly edited) caption and hashtags
- Toast: "Draft saved"
- `isShared` remains `false`

### Share

- See Feature Spec 04 for share flow
- After successful share, sets `PostDraft.isShared = true` and saves to Isar

## Draft History Screen

Accessible from the home screen navigation bar.

### Layout

- Sorted list of saved drafts, newest first
- Each row: thumbnail + truncated caption + platform badge + date
- Swipe-to-delete with confirmation
- Tap to re-open in Post Editor (read-only unless user taps Edit)
- Empty state: "No saved drafts yet" with illustration

### Isar Queries

```dart
// Fetch all drafts, newest first
final drafts = await isar.postDrafts
  .where()
  .sortByCreatedAtDesc()
  .findAll();

// Delete draft
await isar.writeTxn(() async {
  await isar.postDrafts.delete(draft.isarId);
});
```

## State Management (Riverpod)

```dart
// Provider for current generation result
final generationResultProvider = AsyncNotifierProvider<GenerationNotifier, List<PostDraft>>(
  GenerationNotifier.new,
);

// Provider for draft history
final draftHistoryProvider = StreamProvider<List<PostDraft>>((ref) {
  return isar.postDrafts.where().sortByCreatedAtDesc().watch(fireImmediately: true);
});
```

## Data Persistence

All `PostDraft` objects are saved to Isar. See `/docs/architecture/data-models.md` for the Isar collection schema.

Drafts are **never automatically deleted**. User must manually swipe to delete. No cloud sync in v1.

## Error States

| Situation | Behaviour |
|---|---|
| Regeneration fails (network) | Show error snackbar, keep current draft |
| Save fails (Isar error) | Show error snackbar with retry |
| Daily limit hit on regenerate | Show limit reached sheet with upgrade CTA |

## Dependencies

- `isar: ^3.1.0`
- `flutter_riverpod: ^2.5.0`
- `share_plus: ^9.0.0` (share action, see Spec 04)
