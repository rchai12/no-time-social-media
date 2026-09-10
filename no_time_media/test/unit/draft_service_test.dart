import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/services/draft_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ntm_hive_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PostDraftAdapter());
    }
    await Hive.openBox<PostDraft>('drafts');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  PostDraft makeDraft(String id, {required DateTime createdAt}) {
    return PostDraft(
      id: id,
      assetId: 'asset-$id',
      thumbnail: Uint8List.fromList([1, 2, 3]),
      caption: 'Caption $id',
      hashtags: ['one', 'two'],
      platform: 'instagram',
      engagementRationale: 'Looks good',
      createdAt: createdAt,
    );
  }

  test('save, getAll newest-first, delete', () async {
    final older = makeDraft('a', createdAt: DateTime(2026, 1, 1));
    final newer = makeDraft('b', createdAt: DateTime(2026, 8, 31));

    await DraftService.save(older);
    await DraftService.save(newer);

    final all = DraftService.getAll();
    expect(all.map((d) => d.id), ['b', 'a']);

    await DraftService.delete('b');
    expect(DraftService.getAll().map((d) => d.id), ['a']);
  });
}
