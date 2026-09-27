/// Card ranks, ordered low to high so `Rank.values[i].value` and
/// enum declaration order always agree — a deliberate invariant the
/// rules engine leans on when comparing cards.
enum Rank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  const Rank(this.value);

  /// Numeric strength, 2–14 (Ace high). Used for every trick comparison.
  final int value;

  /// Short label for compact UI (card face) and debug output.
  String get label {
    switch (this) {
      case Rank.jack:
        return 'J';
      case Rank.queen:
        return 'Q';
      case Rank.king:
        return 'K';
      case Rank.ace:
        return 'A';
      default:
        return value.toString();
    }
  }
}
