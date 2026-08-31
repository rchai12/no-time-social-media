// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_draft.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PostDraftAdapter extends TypeAdapter<PostDraft> {
  @override
  final int typeId = 1;

  @override
  PostDraft read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PostDraft(
      id: fields[0] as String,
      caption: fields[1] as String,
      hashtags: (fields[2] as List).cast<String>(),
      imageUrl: fields[3] as String?,
      platform: fields[4] as String,
      createdAt: fields[5] as DateTime,
      updatedAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, PostDraft obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.caption)
      ..writeByte(2)
      ..write(obj.hashtags)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.platform)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostDraftAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$PostDraftImpl _$$PostDraftImplFromJson(Map<String, dynamic> json) =>
    _$PostDraftImpl(
      id: json['id'] as String,
      caption: json['caption'] as String,
      hashtags:
          (json['hashtags'] as List<dynamic>).map((e) => e as String).toList(),
      imageUrl: json['imageUrl'] as String?,
      platform: json['platform'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$PostDraftImplToJson(_$PostDraftImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'caption': instance.caption,
      'hashtags': instance.hashtags,
      'imageUrl': instance.imageUrl,
      'platform': instance.platform,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
