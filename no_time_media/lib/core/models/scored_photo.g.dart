// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scored_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScoredPhotoImpl _$$ScoredPhotoImplFromJson(Map<String, dynamic> json) =>
    _$ScoredPhotoImpl(
      id: json['id'] as String,
      path: json['path'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      dateTaken: DateTime.parse(json['dateTaken'] as String),
      isFavorited: json['isFavorited'] as bool,
      compositeScore: (json['compositeScore'] as num).toDouble(),
      recencyScore: (json['recencyScore'] as num).toDouble(),
      aestheticScore: (json['aestheticScore'] as num).toDouble(),
      noveltyScore: (json['noveltyScore'] as num).toDouble(),
      facesScore: (json['facesScore'] as num).toDouble(),
      sharpnessScore: (json['sharpnessScore'] as num).toDouble(),
    );

Map<String, dynamic> _$$ScoredPhotoImplToJson(_$ScoredPhotoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'path': instance.path,
      'width': instance.width,
      'height': instance.height,
      'dateTaken': instance.dateTaken.toIso8601String(),
      'isFavorited': instance.isFavorited,
      'compositeScore': instance.compositeScore,
      'recencyScore': instance.recencyScore,
      'aestheticScore': instance.aestheticScore,
      'noveltyScore': instance.noveltyScore,
      'facesScore': instance.facesScore,
      'sharpnessScore': instance.sharpnessScore,
    };
