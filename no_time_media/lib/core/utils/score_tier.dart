enum ScoreTier { gold, silver, none }

/// Absolute composite-score badges from the Phase 6 scan-screen spec.
ScoreTier scoreTierForScore(double score) {
  if (score >= 0.75) return ScoreTier.gold;
  if (score >= 0.50) return ScoreTier.silver;
  return ScoreTier.none;
}
