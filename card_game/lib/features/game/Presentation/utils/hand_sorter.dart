import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/suit.dart';

/// Display order for the human's hand: spades, hearts, clubs, diamonds
/// (alternating black/red so suits are easy to tell apart), high to low
/// within each suit.
abstract class HandSorter {
  static const List<Suit> _suitOrder = [Suit.spades, Suit.hearts, Suit.clubs, Suit.diamonds];

  static List<PlayingCard> sorted(Iterable<PlayingCard> cards) {
    final List<PlayingCard> list = cards.toList();
    list.sort((a, b) {
      final int bySuit = _suitOrder.indexOf(a.suit).compareTo(_suitOrder.indexOf(b.suit));
      if (bySuit != 0) return bySuit;
      return b.rank.value.compareTo(a.rank.value);
    });
    return list;
  }
}
