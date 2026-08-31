import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:no_time_media/core/services/photo_service.dart';
import 'package:no_time_media/core/services/scoring_service.dart';
import 'package:no_time_media/core/models/scored_photo.dart';

final photoScanProvider = AsyncNotifierProvider<PhotoScanNotifier, List<ScoredPhoto>>(() {
  return PhotoScanNotifier();
});

class PhotoScanNotifier extends AsyncNotifier<List<ScoredPhoto>> {
  @override
  Future<List<ScoredPhoto>> build() async {
    // For now, we'll fetch some photos and score them
    // In a real implementation this would be more sophisticated
    
    final photos = await PhotoService.fetchLastPhotos(20);
    
    // Score each photo
    final scoredPhotos = <ScoredPhoto>[];
    
    for (final photo in photos) {
      try {
        final scoredPhoto = await ScoringService.calculateScores(photo);
        scoredPhotos.add(scoredPhoto);
      } catch (e) {
        // Skip photos that fail scoring, but log the error
        // In a real app this would be more robust
        print('Error scoring photo ${photo.id}: $e');
      }
    }
    
    // Sort by composite score descending (highest scoring first)
    scoredPhotos.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    
    return scoredPhotos;
  }
}