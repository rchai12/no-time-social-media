import 'package:flutter_test/flutter_test.dart';
import 'package:no_time_media/core/models/photo_entity.dart';
import 'package:no_time_media/core/services/scoring_service.dart';

void main() {
  group('ScoringService formulas', () {
    test('novelty is 1.0 when the top label is unique', () {
      expect(ScoringService.noveltyScore(1, 20), 1.0);
    });

    test('novelty falls as a label is shared across the batch', () {
      expect(ScoringService.noveltyScore(10, 10), closeTo(0.1, 1e-9));
      expect(ScoringService.noveltyScore(5, 10), closeTo(0.6, 1e-9));
    });

    test('face score clamps faceCount / 3 to 0–1', () {
      expect(ScoringService.faceScore(0), 0.0);
      expect(ScoringService.faceScore(1), closeTo(1 / 3, 1e-9));
      expect(ScoringService.faceScore(3), 1.0);
      expect(ScoringService.faceScore(8), 1.0);
    });

    test('recency is 1.0 for now and 0.0 after 72 hours', () {
      expect(ScoringService.recencyScore(DateTime.now()), closeTo(1.0, 0.02));
      expect(
        ScoringService.recencyScore(
          DateTime.now().subtract(const Duration(hours: 80)),
        ),
        0.0,
      );
    });

    test('composite uses spec weights', () {
      expect(
        ScoringService.compositeScore(1, 1, 1, 1),
        closeTo(1.0, 1e-9),
      );
      expect(
        ScoringService.compositeScore(1, 0, 0, 0),
        closeTo(0.35, 1e-9),
      );
    });
  });

  test('scoreAll returns an empty list for no photos', () async {
    expect(await ScoringService.scoreAll(const []), isEmpty);
  });

  test('scoreAll falls back to recency-only when ML Kit is unavailable',
      () async {
    final older = PhotoEntity(
      id: 'old',
      path: '/tmp/missing-old.jpg',
      width: 100,
      height: 100,
      dateTaken: DateTime.now().subtract(const Duration(hours: 48)),
      isFavorited: false,
      score: null,
    );
    final newer = PhotoEntity(
      id: 'new',
      path: '/tmp/missing-new.jpg',
      width: 100,
      height: 100,
      dateTaken: DateTime.now(),
      isFavorited: false,
      score: null,
    );

    final scored = await ScoringService.scoreAll([older, newer]);
    expect(scored.map((p) => p.id), ['new', 'old']);
    expect(scored.first.recencyScore, greaterThan(scored.last.recencyScore));
  });
}
