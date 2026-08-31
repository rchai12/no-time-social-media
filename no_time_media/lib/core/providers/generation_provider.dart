import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:no_time_media/core/models/post_draft.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/models/social_platform.dart';
import 'package:no_time_media/core/services/ai_service.dart';

const _uuid = Uuid();

final generationProvider =
    AsyncNotifierProvider<GenerationNotifier, List<PostDraft>?>(
  GenerationNotifier.new,
);

class GenerationNotifier extends AsyncNotifier<List<PostDraft>?> {
  @override
  Future<List<PostDraft>?> build() async {
    return null;
  }

  Future<List<PostDraft>> generatePosts(List<ScoredPhoto> photos) async {
    state = const AsyncLoading();
    try {
      final bundle = await AIService.generatePosts(photos);
      final drafts = <PostDraft>[];
      for (final result in bundle.response.selectedPhotos) {
        final thumbnail = bundle.thumbnailsByAssetId[result.assetId];
        if (thumbnail == null) continue;
        drafts.add(
          PostDraft(
            id: _uuid.v4(),
            assetId: result.assetId,
            thumbnail: thumbnail,
            caption: result.caption,
            hashtags: List<String>.from(result.hashtags),
            platform: SocialPlatform.fromString(result.bestPlatform).name,
            engagementRationale: result.engagementRationale,
            createdAt: DateTime.now(),
          ),
        );
      }
      state = AsyncData(drafts);
      return drafts;
    } catch (e, stack) {
      state = AsyncError(e, stack);
      rethrow;
    }
  }
}
