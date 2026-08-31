import 'dart:typed_data';

class PhotoResult {
  final String assetId;
  final String caption;
  final List<String> hashtags;
  final String bestPlatform;
  final String engagementRationale;

  PhotoResult({
    required this.assetId,
    required this.caption,
    required this.hashtags,
    required this.bestPlatform,
    required this.engagementRationale,
  });
}

class AIGenerationResponse {
  final List<PhotoResult> selectedPhotos;

  AIGenerationResponse({
    required this.selectedPhotos,
  });
}

class GenerationBundle {
  final AIGenerationResponse response;
  final Map<String, Uint8List> thumbnails;

  GenerationBundle({required this.response, required this.thumbnails});
}
