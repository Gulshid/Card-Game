/// Bot skill tiers. Measured head-to-head in simulation (see
/// PHASE_05_06_NOTES.md): Medium beats Easy ~88% of matches, Hard beats
/// Easy ~90% and Hard beats Medium ~64%.
enum AiDifficulty {
  /// Random legal card play, with a deliberately conservative bid.
  easy('Easy'),

  /// Heuristic bidding and card play (never bids Nil).
  medium('Medium'),

  /// Medium's heuristics plus Nil bidding and card tracking.
  hard('Hard');

  const AiDifficulty(this.label);

  final String label;
}
