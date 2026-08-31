import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'social_platform.freezed.dart';
part 'social_platform.g.dart';

@freezed
@HiveType(typeId: 1)
class SocialPlatform with _$SocialPlatform {
  const SocialPlatform._();

  const factory SocialPlatform({
    @HiveField(0)
    required String name,
    @HiveField(1)
    required String displayName,
    @HiveField(2)
    required bool isEnabled,
  }) = _SocialPlatform;

  factory SocialPlatform.fromJson(Map<String, dynamic> json) => _$SocialPlatformFromJson(json);
}