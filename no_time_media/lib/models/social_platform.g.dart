// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_platform.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SocialPlatformAdapter extends TypeAdapter<SocialPlatform> {
  @override
  final int typeId = 1;

  @override
  SocialPlatform read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SocialPlatform(
      name: fields[0] as String,
      displayName: fields[1] as String,
      isEnabled: fields[2] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SocialPlatform obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialPlatformAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SocialPlatformImpl _$$SocialPlatformImplFromJson(Map<String, dynamic> json) =>
    _$SocialPlatformImpl(
      name: json['name'] as String,
      displayName: json['displayName'] as String,
      isEnabled: json['isEnabled'] as bool,
    );

Map<String, dynamic> _$$SocialPlatformImplToJson(
        _$SocialPlatformImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'displayName': instance.displayName,
      'isEnabled': instance.isEnabled,
    };
