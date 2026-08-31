import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/services/ai_service.dart';
import 'package:no_time_media/core/models/ai_models.dart';
import 'package:no_time_media/core/models/scored_photo.dart';

final generationProvider =
    AsyncNotifierProvider<GenerationNotifier, AIGenerationResponse?>(
  () => GenerationNotifier(),
);

class GenerationNotifier extends AsyncNotifier<AIGenerationResponse?> {
  @override
  Future<AIGenerationResponse?> build() async {
    return null;
  }

  Future<void> generatePosts(List<ScoredPhoto> photos) async {
    state = const AsyncLoading();
    try {
      final result = await AIService.generatePosts(photos);
      state = AsyncData(result);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }
}
