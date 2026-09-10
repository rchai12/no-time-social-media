import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/services/ai_service.dart';

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
