import 'dart:math';

import 'playing_card.dart';
import 'rank.dart';
import 'suit.dart';

/// An immutable, ordered collection of cards. Every operation returns
/// a *new* `Deck` rather than mutating in place — the rules engine
/// (Phase 04) is built as a pure reducer, and an immutable deck is
/// what makes `GameState` safely immutable too.
class Deck {
  const Deck(this.cards);

  /// A complete, unshuffled 52-card deck in a fixed, deterministic
  /// order (suit-major, rank-ascending) — always the same order, so
  /// `Deck.standard52().shuffled(seed: 1)` is reproducible in tests.
  factory Deck.standard52() {
    return Deck(
      List.unmodifiable([
        for (final suit in Suit.values)
          for (final rank in Rank.values) PlayingCard(suit: suit, rank: rank),
      ]),
    );
  }

  final List<PlayingCard> cards;

  int get length => cards.length;
  bool get isEmpty => cards.isEmpty;

  /// Fisher–Yates shuffle. Pass `seed` for a reproducible order (used
  /// by every unit test and, later, by replay/debug tooling); omit it
  /// for a genuinely random game.
  Deck shuffled({int? seed}) {
    final Random rng = seed == null ? Random() : Random(seed);
    final List<PlayingCard> shuffledCards = List.of(cards);
    for (int i = shuffledCards.length - 1; i > 0; i--) {
      final int j = rng.nextInt(i + 1);
      final PlayingCard tmp = shuffledCards[i];
      shuffledCards[i] = shuffledCards[j];
      shuffledCards[j] = tmp;
    }
    return Deck(List.unmodifiable(shuffledCards));
  }

  /// Splits this deck into [playerCount] equal hands, dealt in round-robin
  /// order (one card to each player in turn) the way cards are dealt at
  /// a real table — not sliced into contiguous blocks.
  ///
  /// Throws [ArgumentError] if the deck doesn't divide evenly, which
  /// would indicate a bug upstream (e.g. dealing a non-standard deck)
  /// rather than something callers should silently tolerate.
  List<List<PlayingCard>> dealEqually(int playerCount) {
    if (playerCount <= 0) {
      throw ArgumentError.value(playerCount, 'playerCount', 'must be positive');
    }
    if (cards.length % playerCount != 0) {
      throw ArgumentError(
        'Deck of ${cards.length} cards does not divide evenly among $playerCount players',
      );
    }
    final List<List<PlayingCard>> hands = List.generate(playerCount, (_) => <PlayingCard>[]);
    for (int i = 0; i < cards.length; i++) {
      hands[i % playerCount].add(cards[i]);
    }
    return List.unmodifiable(hands.map(List<PlayingCard>.unmodifiable));
  }
}
