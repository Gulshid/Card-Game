import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/rank.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlayingCard', () {
    test('two cards with the same suit and rank are equal', () {
      const a = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const b = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('cards differing by suit or rank are not equal', () {
      const ace = PlayingCard(suit: Suit.spades, rank: Rank.ace);
      const king = PlayingCard(suit: Suit.spades, rank: Rank.king);
      const aceHearts = PlayingCard(suit: Suit.hearts, rank: Rank.ace);
      expect(ace, isNot(equals(king)));
      expect(ace, isNot(equals(aceHearts)));
    });

    test('rank ordering is strictly increasing 2..Ace', () {
      for (int i = 0; i < Rank.values.length - 1; i++) {
        expect(Rank.values[i].value, lessThan(Rank.values[i + 1].value));
      }
      expect(Rank.ace.value, 14);
      expect(Rank.two.value, 2);
    });

    test('toString renders a compact, readable label', () {
      const card = PlayingCard(suit: Suit.hearts, rank: Rank.queen);
      expect(card.toString(), 'Q♥');
    });
  });
}
