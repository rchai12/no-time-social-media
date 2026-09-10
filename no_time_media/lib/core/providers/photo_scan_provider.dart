import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/services/photo_service.dart';
import 'package:no_time_media/core/services/prefs_service.dart';
import 'package:no_time_media/core/services/scoring_service.dart';

final limitedPhotoAccessProvider = StateProvider<bool>((ref) => false);

final photoScanProvider =
    AsyncNotifierProvider<PhotoScanNotifier, List<ScoredPhoto>>(
  PhotoScanNotifier.new,
);

class PhotoScanNotifier extends AsyncNotifier<List<ScoredPhoto>> {
  @override
  Future<List<ScoredPhoto>> build() async {
    final count = PrefsService.photoCount;
    try {
      final result = await PhotoService.fetchLastPhotos(count);
      ref.read(limitedPhotoAccessProvider.notifier).state = result.isLimited;
      if (result.photos.isEmpty) return [];

      final scored = await ScoringService.scoreAll(result.photos);
      scored.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
      return scored;
    } catch (e) {
      ref.read(limitedPhotoAccessProvider.notifier).state = false;
      rethrow;
    }
  }
}
