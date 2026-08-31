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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PhotoResult &&
        other.assetId == assetId &&
        other.caption == caption &&
        other.hashtags == hashtags &&
        other.bestPlatform == bestPlatform &&
        other.engagementRationale == engagementRationale;
  }

  @override
  int get hashCode {
    return Object.hash(
      assetId,
      caption,
      hashtags,
      bestPlatform,
      engagementRationale,
    );
  }
}

class AIGenerationResponse {
  final List<PhotoResult> selectedPhotos;

  AIGenerationResponse({
    required this.selectedPhotos,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AIGenerationResponse &&
        other.selectedPhotos == selectedPhotos;
  }

  @override
  int get hashCode => selectedPhotos.hashCode;
}

class GenerationBundle {
  final AIGenerationResponse response;
  final Map<String, Uint8List> thumbnailsByAssetId;

  GenerationBundle({
    required this.response,
    required this.thumbnailsByAssetId,
  });
}
