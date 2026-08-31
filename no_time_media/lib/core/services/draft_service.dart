import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:no_time_media/core/models/post_draft.dart';

class DraftService {
  Box<PostDraft> get _box => Hive.box<PostDraft>('drafts');

  Future<void> save(PostDraft draft) async {
    await _box.put(draft.id, draft);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  List<PostDraft> getAll() {
    final drafts = _box.values.toList();
    drafts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return drafts;
  }

  Stream<List<PostDraft>> watch() async* {
    yield getAll();
    yield* _box.watch().map((_) => getAll());
  }
}

final draftServiceProvider = Provider<DraftService>((ref) => DraftService());
