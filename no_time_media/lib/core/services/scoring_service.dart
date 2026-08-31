import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:no_time_media/core/models/photo_entity.dart';
import 'package:no_time_media/core/models/scored_photo.dart';

class ScoringService {
  /// Calculates a composite score for the photo based on:
  /// - Recency (35%)
  /// - Aesthetic (30%) — sharpness + mock label confidence, averaged
  /// - Novelty (20%)
  /// - Faces (15%)
  static Future<ScoredPhoto> calculateScores(PhotoEntity photo) async {
    try {
      final recencyScore = _calculateRecencyScore(photo.dateTaken);

      final sharpnessScore = await _calculateSharpnessScore(photo.path);
      final mockLabelScore = await _calculateAestheticScore(photo.path);
      final aestheticScore = (sharpnessScore + mockLabelScore) / 2.0;

      final noveltyScore = await _calculateNoveltyScore(photo.path);
      final facesScore = await _calculateFacesScore(photo.path);

      final compositeScore = _computeCompositeScore(
        recencyScore,
        aestheticScore,
        noveltyScore,
        facesScore,
      );

      return ScoredPhoto(
        id: photo.id,
        path: photo.path,
        width: photo.width,
        height: photo.height,
        dateTaken: photo.dateTaken,
        isFavorited: photo.isFavorited,
        compositeScore: compositeScore,
        recencyScore: recencyScore,
        aestheticScore: aestheticScore,
        noveltyScore: noveltyScore,
        facesScore: facesScore,
        sharpnessScore: sharpnessScore,
      );
    } catch (e) {
      debugPrint('Error in calculateScores: $e');
      rethrow;
    }
  }

  /// Linear recency over a 72-hour window. Older than 72h → 0.0.
  static double _calculateRecencyScore(DateTime dateTaken) {
    final hours = DateTime.now().difference(dateTaken).inMinutes / 60.0;
    if (hours <= 0) return 1.0;
    if (hours >= 72) return 0.0;
    return 1.0 - (hours / 72.0);
  }

  /// Mock ML Kit label confidence (real labeling is deferred).
  static Future<double> _calculateAestheticScore(String path) async {
    return (0.2 + (DateTime.now().millisecondsSinceEpoch % 800) / 1000.0);
  }

  /// Mock novelty (real labeling is deferred).
  static Future<double> _calculateNoveltyScore(String path) async {
    return (0.1 + (DateTime.now().millisecondsSinceEpoch % 900) / 1000.0);
  }

  /// Mock face detection (real ML Kit is deferred).
  static Future<double> _calculateFacesScore(String path) async {
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    if (random < 300) return 0.0;
    if (random > 800) {
      return 0.8;
    } else {
      return 0.2 + (random - 300) / 500.0;
    }
  }

  /// Laplacian variance of a 256×256 grayscale thumbnail, normalized by 500.
  static Future<double> _calculateSharpnessScore(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return 0.0;

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return 0.0;

      var gray = img.grayscale(image);
      if (gray.width > 256 || gray.height > 256) {
        gray = img.copyResize(gray, width: 256, height: 256);
      }

      final w = gray.width;
      final h = gray.height;

      double sum = 0;
      double sumSq = 0;
      int count = 0;

      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          final center = img.getLuminance(gray.getPixel(x, y));
          final top = img.getLuminance(gray.getPixel(x, y - 1));
          final bottom = img.getLuminance(gray.getPixel(x, y + 1));
          final left = img.getLuminance(gray.getPixel(x - 1, y));
          final right = img.getLuminance(gray.getPixel(x + 1, y));
          final lap = (4 * center - top - bottom - left - right).abs();
          sum += lap;
          sumSq += lap * lap;
          count++;
        }
      }

      if (count == 0) return 0.0;
      final mean = sum / count;
      final variance = (sumSq / count) - (mean * mean);

      return (variance / 500.0).clamp(0.0, 1.0);
    } catch (e) {
      debugPrint('Error calculating sharpness: $e');
      return 0.0;
    }
  }

  static double _computeCompositeScore(
    double recency,
    double aesthetic,
    double novelty,
    double faces,
  ) {
    return (recency * 0.35) +
        (aesthetic * 0.30) +
        (novelty * 0.20) +
        (faces * 0.15);
  }
}
