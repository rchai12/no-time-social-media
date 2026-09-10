import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_time_media/core/models/ai_models.dart';
import 'package:no_time_media/core/models/scored_photo.dart';
import 'package:no_time_media/core/models/subscription_exception.dart';

class AIService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<GenerationBundle> generatePosts(
    List<ScoredPhoto> photos,
  ) async {
    try {
      final photoInputs = <Map<String, dynamic>>[];
      final thumbnailMap = <String, Uint8List>{};

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
        thumbnailMap[photo.id] = bytes;
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

      _throwIfSubscriptionError(response.data);

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

      return GenerationBundle(
        response: AIGenerationResponse(selectedPhotos: results),
        thumbnails: thumbnailMap,
      );
    } on SubscriptionException {
      rethrow;
    } on FunctionException catch (e) {
      if (e.status == 401) {
        throw Exception('Session expired — please sign in again');
      }
      _throwIfSubscriptionError(e.details);
      debugPrint('Error generating posts: $e');
      rethrow;
    } catch (e) {
      debugPrint('Error generating posts: $e');
      rethrow;
    }
  }

  static void _throwIfSubscriptionError(dynamic body) {
    if (body is! Map) return;
    final error = body['error'] as String?;
    if (error == 'subscription_required') {
      throw const SubscriptionException(SubscriptionErrorType.requiresUpgrade);
    }
    if (error == 'daily_limit_reached') {
      final resetsAt = body['resets_at'] != null
          ? DateTime.parse(body['resets_at'] as String)
          : null;
      throw SubscriptionException(
        SubscriptionErrorType.dailyLimitReached,
        resetsAt: resetsAt,
      );
    }
  }
}
