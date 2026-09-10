enum ScoreTier { gold, silver, none }

/// Rank-based score tiers for a list already sorted by composite score desc.
ScoreTier scoreTierForIndex(int index, int total) {
  if (total <= 0 || index < 0) return ScoreTier.none;
  if (index < total * 0.25) return ScoreTier.gold;
  if (index < total * 0.50) return ScoreTier.silver;
  return ScoreTier.none;
}
