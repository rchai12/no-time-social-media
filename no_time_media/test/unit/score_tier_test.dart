import 'package:flutter_test/flutter_test.dart';
import 'package:no_time_media/core/utils/score_tier.dart';

void main() {
  test('top 25% is gold, next 25% is silver, remainder has no badge', () {
    expect(scoreTierForIndex(0, 20), ScoreTier.gold);
    expect(scoreTierForIndex(4, 20), ScoreTier.gold);
    expect(scoreTierForIndex(5, 20), ScoreTier.silver);
    expect(scoreTierForIndex(9, 20), ScoreTier.silver);
    expect(scoreTierForIndex(10, 20), ScoreTier.none);
    expect(scoreTierForIndex(19, 20), ScoreTier.none);
  });
}
