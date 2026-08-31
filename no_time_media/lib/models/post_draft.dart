import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_flutter/hive_flutter.dart';

part 'post_draft.freezed.dart';
part 'post_draft.g.dart';

@freezed
@HiveType(typeId: 1)
class PostDraft with _$PostDraft {
  const PostDraft._();

  const factory PostDraft({
    @HiveField(0)
    required String id,
    @HiveField(1)
    required String caption,
    @HiveField(2)
    required List<String> hashtags,
    @HiveField(3)
    required String? imageUrl,
    @HiveField(4)
    required String platform,
    @HiveField(5)
    required DateTime createdAt,
    @HiveField(6)
    required DateTime updatedAt,
  }) = _PostDraft;

  factory PostDraft.fromJson(Map<String, dynamic> json) => _$PostDraftFromJson(json);
}