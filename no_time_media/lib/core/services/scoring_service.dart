import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    hide InputImage;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;
import 'package:no_time_media/core/models/photo_entity.dart';
import 'package:no_time_media/core/models/scored_photo.dart';

class ScoringService {
  static const _mlConcurrency = 4;
  static const _labelConfidenceThreshold = 0.3;

  /// Scores the full batch so novelty can compare labels across photos.
  static Future<List<ScoredPhoto>> scoreAll(List<PhotoEntity> photos) async {
    if (photos.isEmpty) return [];

    ImageLabeler? labeler;
    FaceDetector? detector;
    var mlReady = true;

    try {
      labeler = ImageLabeler(
        options: ImageLabelerOptions(
          confidenceThreshold: _labelConfidenceThreshold,
        ),
      );
      detector = FaceDetector(
        options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
      );
    } catch (e) {
      debugPrint('ML Kit init failed: $e');
      mlReady = false;
    }

    try {
      if (!mlReady || labeler == null || detector == null) {
        return _recencyOnly(photos);
      }

      final pass1 = await _mapLimited(
        photos,
        _mlConcurrency,
        (photo) => _analyzePhoto(photo, labeler!, detector!),
      );

      return _composeScores(photos, pass1);
    } on MissingPluginException catch (e) {
      debugPrint('ML Kit unavailable: $e');
      return _recencyOnly(photos);
    } finally {
      try {
        await labeler?.close();
      } catch (e) {
        debugPrint('Error closing ImageLabeler: $e');
      }
      try {
        await detector?.close();
      } catch (e) {
        debugPrint('Error closing FaceDetector: $e');
      }
    }
  }

  static List<ScoredPhoto> _composeScores(
    List<PhotoEntity> photos,
    List<_Pass1Result> pass1,
  ) {
    final totalPhotos = photos.length;
    final labelFrequency = <String, int>{};
    for (final result in pass1) {
      final label = result.topLabel;
      if (label == null) continue;
      labelFrequency[label] = (labelFrequency[label] ?? 0) + 1;
    }

    final scored = <ScoredPhoto>[];
    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final result = pass1[i];
      final recency = recencyScore(photo.dateTaken);
      final aesthetic = (result.sharpness + result.labelConfidence) / 2.0;
      final novelty = result.topLabel == null
          ? 1.0
          : noveltyScore(labelFrequency[result.topLabel] ?? 1, totalPhotos);
      final faces = faceScore(result.faceCount);
      scored.add(
        ScoredPhoto(
          id: photo.id,
          path: photo.path,
          width: photo.width,
          height: photo.height,
          dateTaken: photo.dateTaken,
          isFavorited: photo.isFavorited,
          compositeScore: compositeScore(recency, aesthetic, novelty, faces),
          recencyScore: recency,
          aestheticScore: aesthetic,
          noveltyScore: novelty,
          facesScore: faces,
          sharpnessScore: result.sharpness,
        ),
      );
    }

    scored.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    return scored;
  }

  static List<ScoredPhoto> _recencyOnly(List<PhotoEntity> photos) {
    final scored = photos.map((photo) {
      final recency = recencyScore(photo.dateTaken);
      return ScoredPhoto(
        id: photo.id,
        path: photo.path,
        width: photo.width,
        height: photo.height,
        dateTaken: photo.dateTaken,
        isFavorited: photo.isFavorited,
        compositeScore: recency,
        recencyScore: recency,
        aestheticScore: 0,
        noveltyScore: 0,
        facesScore: 0,
        sharpnessScore: 0,
      );
    }).toList();
    scored.sort((a, b) => b.compositeScore.compareTo(a.compositeScore));
    return scored;
  }

  static Future<_Pass1Result> _analyzePhoto(
    PhotoEntity photo,
    ImageLabeler labeler,
    FaceDetector detector,
  ) async {
    try {
      final inputImage = InputImage.fromFilePath(photo.path);

      List<ImageLabel> labels = const [];
      try {
        labels = await labeler.processImage(inputImage);
      } on MissingPluginException {
        rethrow;
      } catch (e) {
        debugPrint('Image labeling failed for ${photo.id}: $e');
      }

      labels = [...labels]
        ..sort((a, b) => b.confidence.compareTo(a.confidence));
      final top3 = labels.take(3).toList();
      final labelConfidence = top3.isEmpty
          ? 0.0
          : top3.map((l) => l.confidence).reduce((a, b) => a + b) /
                top3.length;
      final topLabel = labels.isEmpty ? null : labels.first.label;

      var faceCount = 0;
      try {
        final faces = await detector.processImage(inputImage);
        faceCount = faces.length;
      } on MissingPluginException {
        rethrow;
      } catch (e) {
        debugPrint('Face detection failed for ${photo.id}: $e');
      }

      final sharpness = await _calculateSharpnessScore(photo.path);
      return _Pass1Result(
        topLabel: topLabel,
        labelConfidence: labelConfidence,
        faceCount: faceCount,
        sharpness: sharpness,
      );
    } on MissingPluginException {
      rethrow;
    } catch (e) {
      debugPrint('Error analyzing photo ${photo.id}: $e');
      final sharpness = await _calculateSharpnessScore(photo.path);
      return _Pass1Result(
        topLabel: null,
        labelConfidence: 0,
        faceCount: 0,
        sharpness: sharpness,
      );
    }
  }

  /// Linear recency over a 72-hour window. Older than 72h → 0.0.
  static double recencyScore(DateTime dateTaken) {
    final hours = DateTime.now().difference(dateTaken).inMinutes / 60.0;
    if (hours <= 0) return 1.0;
    if (hours >= 72) return 0.0;
    return 1.0 - (hours / 72.0);
  }

  /// Unique top label → 1.0; a label shared by every photo → 1 / totalPhotos.
  static double noveltyScore(int frequency, int totalPhotos) {
    if (totalPhotos <= 0) return 0.0;
    return (1 - ((frequency - 1) / totalPhotos)).clamp(0.0, 1.0);
  }

  /// 1–3 faces approach the max; 0 faces → 0.0.
  static double faceScore(int faceCount) {
    return (faceCount / 3.0).clamp(0.0, 1.0);
  }

  static double compositeScore(
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

  static Future<List<T>> _mapLimited<T, E>(
    List<E> items,
    int maxConcurrent,
    Future<T> Function(E item) mapper,
  ) async {
    if (items.isEmpty) return [];
    final limit = maxConcurrent.clamp(1, items.length);
    final results = List<T?>.filled(items.length, null);
    var nextIndex = 0;

    Future<void> worker() async {
      while (true) {
        final i = nextIndex;
        nextIndex += 1;
        if (i >= items.length) return;
        results[i] = await mapper(items[i]);
      }
    }

    await Future.wait(List.generate(limit, (_) => worker()));
    return results.cast<T>();
  }
}

class _Pass1Result {
  const _Pass1Result({
    required this.topLabel,
    required this.labelConfidence,
    required this.faceCount,
    required this.sharpness,
  });

  final String? topLabel;
  final double labelConfidence;
  final int faceCount;
  final double sharpness;
}
