# Data Models — No Time Media

## PhotoEntity
Represents a photo asset from the device gallery.

```dart
@freezed
class PhotoEntity with _$PhotoEntity {
  const PhotoEntity._();
  
  const factory PhotoEntity({
    required String id,
    required String path,
    required int width,
    required int height,
    required DateTime dateTaken,
    required bool isFavorited,
    required double? score,
  }) = _PhotoEntity;

  factory PhotoEntity.fromJson(Map<String, dynamic> json) => _$PhotoEntityFromJson(json);
}
```

## ScoredPhoto
Represents a photo with computed scores for various aspects.

```dart
@freezed
class ScoredPhoto with _$ScoredPhoto {
  const ScoredPhoto._();
  
  const factory ScoredPhoto({
    required String id,
    required String path,
    required int width,
    required int height,
    required DateTime dateTaken,
    required bool isFavorited,
    required double compositeScore,
    required double recencyScore,
    required double aestheticScore,
    required double noveltyScore,
    required double facesScore,
    required double sharpnessScore,
  }) = _ScoredPhoto;

  factory ScoredPhoto.fromJson(Map<String, dynamic> json) => _$ScoredPhotoFromJson(json);
}
```

## Scoring Components

The scoring system calculates a composite score based on:

1. **Recency** (35%): How recently the photo was taken
2. **Aesthetic** (30%): Visual appeal of the image  
3. **Novelty** (20%): Uniqueness or originality in appearance
4. **Faces** (15%): Presence and quality of faces detected
5. **Sharpness** (included as additional component): Image clarity measured by Laplacian variance

Each component is scored between 0.0 and 1.0, and combined into a composite score.