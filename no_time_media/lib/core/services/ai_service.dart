import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_time_media/core/models/ai_models.dart';
import 'package:no_time_media/core/models/scored_photo.dart';

class AIService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Triggers the edge function to generate AI posts from scored photos.
  static Future<AIGenerationResponse> generatePosts(
    List<ScoredPhoto> photos,
  ) async {
    try {
      final photoInputs = <Map<String, dynamic>>[];
      for (final photo in photos) {
        final entity = AssetEntity(
          id: photo.id,
          typeInt: 1,
          width: photo.width,
          height: photo.height,
        );
        final bytes =
            await entity.thumbnailDataWithSize(const ThumbnailSize(256, 256));
        if (bytes == null) continue;
        photoInputs.add({
          'assetId': photo.id,
          'thumbnailBase64': base64Encode(bytes),
          'compositeScore': photo.compositeScore,
          'dateTaken': photo.dateTaken.toIso8601String(),
        });
      }

      if (photoInputs.isEmpty) throw Exception('No thumbnails available');

      final response = await _supabase.functions.invoke(
        'generate-post',
        body: {
          'photos': photoInputs,
          'targetPlatform': 'instagram',
        },
      );

      final body = response.data as Map<String, dynamic>;
      final rawList = List<dynamic>.from(body['selectedPhotos'] ?? []);
      final results = rawList
          .map((r) => PhotoResult(
                assetId: r['assetId'] as String,
                caption: r['caption'] as String,
                hashtags: List<String>.from(r['hashtags'] ?? []),
                bestPlatform: r['bestPlatform'] as String,
                engagementRationale:
                    r['engagementRationale'] as String? ?? '',
              ))
          .toList();

      return AIGenerationResponse(selectedPhotos: results);
    } catch (e) {
      debugPrint('Error generating posts: $e');
      rethrow;
    }
  }
}
