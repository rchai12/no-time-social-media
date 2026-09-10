import 'package:flutter_test/flutter_test.dart';
import 'package:no_time_media/core/utils/score_tier.dart';

void main() {
  test('gold at 0.75+, silver at 0.50–0.74, none below 0.50', () {
    expect(scoreTierForScore(0.75), ScoreTier.gold);
    expect(scoreTierForScore(1.0), ScoreTier.gold);
    expect(scoreTierForScore(0.50), ScoreTier.silver);
    expect(scoreTierForScore(0.74), ScoreTier.silver);
    expect(scoreTierForScore(0.49), ScoreTier.none);
  });
}
