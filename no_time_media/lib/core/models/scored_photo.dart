import 'package:freezed_annotation/freezed_annotation.dart';

part 'scored_photo.freezed.dart';
part 'scored_photo.g.dart';

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