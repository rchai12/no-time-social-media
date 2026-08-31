// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'photo_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PhotoEntityImpl _$$PhotoEntityImplFromJson(Map<String, dynamic> json) =>
    _$PhotoEntityImpl(
      id: json['id'] as String,
      path: json['path'] as String,
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      dateTaken: DateTime.parse(json['dateTaken'] as String),
      isFavorited: json['isFavorited'] as bool,
      score: (json['score'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$$PhotoEntityImplToJson(_$PhotoEntityImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'path': instance.path,
      'width': instance.width,
      'height': instance.height,
      'dateTaken': instance.dateTaken.toIso8601String(),
      'isFavorited': instance.isFavorited,
      'score': instance.score,
    };
