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

  /// Stream that emits a sorted list immediately, then again whenever the box changes.
  static Stream<List<PostDraft>> watch() async* {
    yield getAll();
    yield* _box.watch().map((_) => getAll());
  }
}
