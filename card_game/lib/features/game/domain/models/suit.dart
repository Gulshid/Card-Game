/// The four suits. Declared in a fixed, meaningful order (not
/// alphabetical) because `index` is used for stable sort/display
/// ordering elsewhere (e.g. grouping a hand by suit in the UI, Phase 05).
enum Suit {
  clubs,
  diamonds,
  spades,
  hearts;

  bool get isSpades => this == Suit.spades;

  /// Unicode glyph, used by debug `toString()` and directly by simple
  /// UI in early phases before a custom icon set exists.
  String get symbol {
    switch (this) {
      case Suit.clubs:
        return '♣';
      case Suit.diamonds:
        return '♦';
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
    }
  }

  /// Whether this suit is conventionally rendered in red ink.
  bool get isRed => this == Suit.diamonds || this == Suit.hearts;
}
