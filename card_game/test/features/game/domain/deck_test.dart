import 'package:card_game/features/game/domain/models/deck.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Deck.standard52', () {
    test('has exactly 52 cards', () {
      expect(Deck.standard52().length, 52);
    });

    test('has no duplicate cards', () {
      final deck = Deck.standard52();
      expect(deck.cards.toSet().length, 52);
    });

    test('is in a fixed, deterministic order', () {
      final a = Deck.standard52();
      final b = Deck.standard52();
      expect(a.cards, equals(b.cards));
    });
  });

  group('Deck.shuffled', () {
    test('preserves all 52 cards, just reordered', () {
      final shuffled = Deck.standard52().shuffled(seed: 42);
      expect(shuffled.length, 52);
      expect(shuffled.cards.toSet(), equals(Deck.standard52().cards.toSet()));
    });

    test('same seed produces the same order every time', () {
      final a = Deck.standard52().shuffled(seed: 7);
      final b = Deck.standard52().shuffled(seed: 7);
      expect(a.cards, equals(b.cards));
    });

    test('different seeds produce different orders', () {
      final a = Deck.standard52().shuffled(seed: 1);
      final b = Deck.standard52().shuffled(seed: 2);
      expect(a.cards, isNot(equals(b.cards)));
    });

    test('actually reorders — is not a no-op', () {
      final original = Deck.standard52();
      final shuffled = original.shuffled(seed: 123);
      expect(shuffled.cards, isNot(equals(original.cards)));
    });
  });

  group('Deck.dealEqually', () {
    test('splits 52 cards into 4 hands of 13', () {
      final hands = Deck.standard52().shuffled(seed: 1).dealEqually(4);
      expect(hands.length, 4);
      for (final hand in hands) {
        expect(hand.length, 13);
      }
    });

    test('every card is dealt to exactly one hand', () {
      final hands = Deck.standard52().shuffled(seed: 1).dealEqually(4);
      final allDealt = hands.expand((h) => h).toSet();
      expect(allDealt.length, 52);
      expect(allDealt, equals(Deck.standard52().cards.toSet()));
    });

    test('deals round-robin, not in contiguous blocks', () {
      final deck = Deck.standard52(); // fixed, unshuffled order
      final hands = deck.dealEqually(4);
      // Card 0 -> hand 0, card 1 -> hand 1, card 4 -> hand 0 again.
      expect(hands[0][0], deck.cards[0]);
      expect(hands[1][0], deck.cards[1]);
      expect(hands[0][1], deck.cards[4]);
    });

    test('throws when the deck does not divide evenly', () {
      final deck = Deck.standard52();
      expect(() => deck.dealEqually(5), throwsArgumentError);
    });

    test('throws for a non-positive player count', () {
      expect(() => Deck.standard52().dealEqually(0), throwsArgumentError);
    });

    test('empty deck deals empty hands without error', () {
      const empty = Deck([]);
      final hands = empty.dealEqually(4);
      expect(hands, everyElement(isEmpty));
    });
  });
}
