import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:no_time_media/core/models/ai_models.dart';

class AIService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Triggers the edge function to generate AI posts from photos
  static Future<AIGenerationResponse> generatePosts(List<PhotoInfo> photos) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-post',
        body: {
          'photos': photos.map((photo) => {
            'id': photo.id,
            'path': photo.path,
            'dateTaken': photo.dateTaken.toIso8601String(),
            'score': photo.score,
            'components': {
              'recency': photo.components.recency,
              'aesthetic': photo.components.aesthetic,
              'novelty': photo.components.novelty,
              'faces': photo.components.faces,
            }
          }).toList(),
        },
      );

      // Parse the response
      final responseBody = response.data as Map<String, dynamic>;
      final captions = List<String>.from(responseBody['captions'] ?? []);
      final hashtags = List<String>.from(responseBody['hashtags'] ?? []);
      final platformsData = List<dynamic>.from(responseBody['platforms'] ?? []);

      final platforms = platformsData
          .map((data) => PlatformContent(
                platform: data['platform'],
                caption: data['caption'],
                postType: data['post_type'],
              ))
          .toList();

      return AIGenerationResponse(
        captions: captions,
        hashtags: hashtags,
        platforms: platforms,
      );
    } catch (e) {
      debugPrint('Error generating posts: $e');
      rethrow;
    }
  }
}