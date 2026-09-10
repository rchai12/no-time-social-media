import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart'
    hide InputImage;
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image/image.dart' as img;
import 'package:no_time_media/core/models/photo_entity.dart';
import 'package:no_time_media/core/models/scored_photo.dart';

class ScoringService {
  /// Scores the full batch so novelty can compare labels across photos.
  /// Caller sorts the result by composite score.
  static Future<List<ScoredPhoto>> scoreAll(List<PhotoEntity> photos) async {
    if (photos.isEmpty) return [];

    ImageLabeler? labeler;
    FaceDetector? detector;

    try {
      labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.3),
      );
      detector = FaceDetector(
        options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
      );
    } catch (e) {
      debugPrint('ML Kit init failed: $e');
      return _recencyOnly(photos);
    }

    try {
      final pass1 = await _runConcurrent(photos, (photo) async {
        final (labels, faceCount, sharpness) = await (
          _labelPhoto(labeler!, photo),
          _countFaces(detector!, photo),
          _calculateSharpnessScore(photo.path),
        ).wait;
        return _Pass1Result(
          labels: labels,
          faceCount: faceCount,
          sharpness: sharpness,
        );
      });

      final freqMap = _buildFrequencyMap(pass1.map((r) => r.labels).toList());
      final totalPhotos = photos.length;

      return List.generate(photos.length, (i) {
        final photo = photos[i];
        final result = pass1[i];
        final recency = recencyScore(photo.dateTaken);
        final labelConf = labelConfidence(result.labels);
        final aesthetic = (result.sharpness + labelConf) / 2.0;
        final novelty = noveltyScore(result.labels, freqMap, totalPhotos);
        final faces = faceScore(result.faceCount);

        return ScoredPhoto(
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
        );
      });
    } catch (e) {
      debugPrint('ML Kit scoring failed: $e');
      return _recencyOnly(photos);
    } finally {
      try {
        await labeler.close();
      } catch (e) {
        debugPrint('Error closing ImageLabeler: $e');
      }
      try {
        await detector.close();
      } catch (e) {
        debugPrint('Error closing FaceDetector: $e');
      }
    }
  }

  static Future<List<ImageLabel>> _labelPhoto(
    ImageLabeler labeler,
    PhotoEntity photo,
  ) async {
    try {
      final input = InputImage.fromFilePath(photo.path);
      return await labeler.processImage(input);
    } catch (_) {
      return [];
    }
  }

  static Future<int> _countFaces(
    FaceDetector detector,
    PhotoEntity photo,
  ) async {
    try {
      final input = InputImage.fromFilePath(photo.path);
      final faces = await detector.processImage(input);
      return faces.length;
    } catch (_) {
      return 0;
    }
  }

  static Map<String, int> _buildFrequencyMap(List<List<ImageLabel>> allLabels) {
    final freq = <String, int>{};
    for (final labels in allLabels) {
      if (labels.isEmpty) continue;
      final top = labels.reduce(
        (a, b) => a.confidence > b.confidence ? a : b,
      );
      freq[top.label] = (freq[top.label] ?? 0) + 1;
    }
    return freq;
  }

  static List<ScoredPhoto> _recencyOnly(List<PhotoEntity> photos) {
    return photos.map((photo) {
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
  }

  static Future<List<T>> _runConcurrent<T>(
    List<PhotoEntity> photos,
    Future<T> Function(PhotoEntity) task, {
    int concurrency = 4,
  }) async {
    final results = <T>[];
    for (var i = 0; i < photos.length; i += concurrency) {
      final chunk = photos.sublist(i, min(i + concurrency, photos.length));
      results.addAll(await Future.wait(chunk.map(task)));
    }
    return results;
  }

  /// Linear recency over a 72-hour window. Older than 72h → 0.0.
  static double recencyScore(DateTime dateTaken) {
    final hours = DateTime.now().difference(dateTaken).inMinutes / 60.0;
    if (hours <= 0) return 1.0;
    if (hours >= 72) return 0.0;
    return 1.0 - (hours / 72.0);
  }

  static double labelConfidence(List<ImageLabel> labels) {
    if (labels.isEmpty) return 0.5;
    final top3 = (labels.toList()
          ..sort((a, b) => b.confidence.compareTo(a.confidence)))
        .take(3)
        .toList();
    return top3.map((l) => l.confidence).reduce((a, b) => a + b) / top3.length;
  }

  static double noveltyScore(
    List<ImageLabel> labels,
    Map<String, int> freqMap,
    int totalPhotos,
  ) {
    if (labels.isEmpty || totalPhotos <= 0) return 0.5;
    final top = labels.reduce(
      (a, b) => a.confidence > b.confidence ? a : b,
    );
    final frequency = freqMap[top.label] ?? 1;
    return 1.0 - ((frequency - 1) / totalPhotos.toDouble()).clamp(0.0, 1.0);
  }

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
}

class _Pass1Result {
  const _Pass1Result({
    required this.labels,
    required this.faceCount,
    required this.sharpness,
  });

  final List<ImageLabel> labels;
  final int faceCount;
  final double sharpness;
}
