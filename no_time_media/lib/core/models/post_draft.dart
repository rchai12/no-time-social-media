import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:no_time_media/core/models/social_platform.dart';

part 'post_draft.g.dart';

@HiveType(typeId: 0)
class PostDraft extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String assetId;

  @HiveField(2)
  final Uint8List thumbnail;

  @HiveField(3)
  String caption;

  @HiveField(4)
  List<String> hashtags;

  @HiveField(5)
  final String platform;

  @HiveField(6)
  final String engagementRationale;

  @HiveField(7)
  final DateTime createdAt;

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

  String get effectiveCaption => userEditedCaption ?? caption;
}
