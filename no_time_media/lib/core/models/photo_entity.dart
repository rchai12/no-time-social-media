import 'package:freezed_annotation/freezed_annotation.dart';

part 'photo_entity.freezed.dart';
part 'photo_entity.g.dart';

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