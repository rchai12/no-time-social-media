import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:no_time_media/core/models/photo_entity.dart';
import 'package:no_time_media/core/models/scored_photo.dart';

class ScoringService {
  /// Calculates a composite score for the photo based on:
  /// - Recency (35%)
  /// - Aesthetic (30%)
  /// - Novelty (20%)  
  /// - Faces (15%)
  /// - Sharpness (additional component)
  static Future<ScoredPhoto> calculateScores(PhotoEntity photo) async {
    try {
      // Recency score (how recent the photo was taken)
      final recencyScore = _calculateRecencyScore(photo.dateTaken);
      
      // Aesthetic score (based on image labeling results)
      final aestheticScore = await _calculateAestheticScore(photo.path);
      
      // Novelty score (based on image labeling results)
      final noveltyScore = await _calculateNoveltyScore(photo.path);
      
      // Faces score (detecting faces in the photo)
      final facesScore = await _calculateFacesScore(photo.path);
      
      // Sharpness score (using Laplacian variance - simplified approach with correct API)
      final sharpnessScore = await _calculateSharpnessScore(photo.path);
      
      // Compute composite score
      final compositeScore = _computeCompositeScore(
        recencyScore,
        aestheticScore, 
        noveltyScore,
        facesScore,
        sharpnessScore,
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
  
  /// Calculates recency score based on how recent the photo was taken
  static double _calculateRecencyScore(DateTime dateTaken) {
    final now = DateTime.now();
    final duration = now.difference(dateTaken);
    final daysAgo = duration.inDays;
    
    // Score: 1.0 for most recent, 0.0 for very old (older than 30 days)
    if (daysAgo < 0) return 1.0; // Future date - unexpected but safe
    if (daysAgo > 30) return 0.0;
    
    // Linear scoring from 1.0 (today) to 0.0 (30 days ago)
    return 1.0 - (daysAgo / 30.0);
  }
  
  /// Calculate aesthetic score using ML model (mock implementation)
  static Future<double> _calculateAestheticScore(String path) async {
    // This would use google_mlkit_image_labeling for actual implementation
    // For now, we return a mock value
    
    // In real implementation, would analyze image labels and 
    // correlate with aesthetic scoring from ML models
    
    // Mock: Return random score between 0.2 and 1.0
    return (0.2 + (DateTime.now().millisecondsSinceEpoch % 800) / 1000.0);
  }
  
  /// Calculate novelty score using ML model (mock implementation)
  static Future<double> _calculateNoveltyScore(String path) async {
    // This would use google_mlkit_image_labeling for actual implementation
    // For now, we return a mock value
    
    // In real implementation, would analyze image labels and 
    // correlate with novelty scoring from ML models
    
    // Mock: Return random score between 0.1 and 1.0
    return (0.1 + (DateTime.now().millisecondsSinceEpoch % 900) / 1000.0);
  }
  
  /// Calculate face score using ML model (mock implementation)
  static Future<double> _calculateFacesScore(String path) async {
    // This would use google_mlkit_face_detection for actual implementation
    // For now, we return a mock value
    
    // In real implementation, would detect number of faces and calculate score
    // Score is higher if faces are detected but in reasonable numbers
    
    // Mock: Return random score between 0.0 and 1.0 based on presence of faces
    final random = DateTime.now().millisecondsSinceEpoch % 1000;
    if (random < 300) return 0.0; // No faces detected
    if (random > 800) {
      return 0.8; // Multiple faces
    } else {
      return 0.2 + (random - 300) / 500.0; // Single face with some variation
    }
  }
  
  /// Calculate sharpness score using approximation (avoiding incompatible image APIs)
  static Future<double> _calculateSharpnessScore(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        return 0.0;
      }
      
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        return 0.0;
      }
      
      // Simplified approach to sharpness calculation that avoids problematic APIs
      // Just returns a mock value as the actual API is incompatible with this version
      // In production, this would use real image processing
      return 0.5; // Returning a fixed midpoint value for now
    } catch (e) {
      debugPrint('Error calculating sharpness: $e');
      return 0.0;
    }
  }
  
  /// Computes the weighted composite score
  static double _computeCompositeScore(
    double recency,
    double aesthetic, 
    double novelty,
    double faces,
    double sharpness,
  ) {
    // Weighting: Recency 35%, Aesthetic 30%, Novelty 20%, Faces 15%
    return (recency * 0.35) + 
           (aesthetic * 0.30) + 
           (novelty * 0.20) + 
           (faces * 0.15);
  }
}