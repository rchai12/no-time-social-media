import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/providers/photo_count_provider.dart';
import 'package:no_time_media/core/services/photo_service.dart';
import 'package:no_time_media/core/services/scoring_service.dart';

final photoScanProvider =
    AsyncNotifierProvider<PhotoScanNotifier, List<ScoredPhoto>>(
  PhotoScanNotifier.new,
);

class PhotoScanNotifier extends AsyncNotifier<List<ScoredPhoto>> {
  @override
  Future<List<ScoredPhoto>> build() async {
    final count = ref.read(photoCountProvider);
    final photos = await PhotoService.fetchLastPhotos(count);
    return ScoringService.scoreAll(photos);
  }
}
