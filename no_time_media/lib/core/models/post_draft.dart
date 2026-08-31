import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:no_time_media/core/models/social_platform.dart';

part 'post_draft.g.dart';

@HiveType(typeId: 0)
class PostDraft extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String assetId;

  @HiveField(2)
  Uint8List thumbnail;

  @HiveField(3)
  String caption;

  @HiveField(4)
  List<String> hashtags;

  @HiveField(5)
  String platform;

  @HiveField(6)
  String engagementRationale;

  @HiveField(7)
  DateTime createdAt;

  @HiveField(8)
  bool isShared;

  @HiveField(9)
  String? userEditedCaption;

  PostDraft({
    required this.id,
    required this.assetId,
    required this.thumbnail,
    required this.caption,
    required this.hashtags,
    required this.platform,
    required this.engagementRationale,
    required this.createdAt,
    this.isShared = false,
    this.userEditedCaption,
  });

  SocialPlatform get socialPlatform => SocialPlatform.fromString(platform);

  String get displayCaption => userEditedCaption ?? caption;
}
