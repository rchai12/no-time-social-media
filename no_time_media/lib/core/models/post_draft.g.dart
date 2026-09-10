// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_draft.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PostDraftAdapter extends TypeAdapter<PostDraft> {
  @override
  final int typeId = 0;

  @override
  PostDraft read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PostDraft(
      id: fields[0] as String,
      assetId: fields[1] as String,
      thumbnail: fields[2] as Uint8List,
      caption: fields[3] as String,
      hashtags: (fields[4] as List).cast<String>(),
      platform: fields[5] as String,
      engagementRationale: fields[6] as String,
      createdAt: fields[7] as DateTime,
      isShared: fields[8] as bool,
      userEditedCaption: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PostDraft obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.assetId)
      ..writeByte(2)
      ..write(obj.thumbnail)
      ..writeByte(3)
      ..write(obj.caption)
      ..writeByte(4)
      ..write(obj.hashtags)
      ..writeByte(5)
      ..write(obj.platform)
      ..writeByte(6)
      ..write(obj.engagementRationale)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isShared)
      ..writeByte(9)
      ..write(obj.userEditedCaption);
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
