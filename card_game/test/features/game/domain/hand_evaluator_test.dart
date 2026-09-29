import 'package:card_game/features/game/domain/ai/hand_evaluator.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/rank.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:flutter_test/flutter_test.dart';

const _hearts = Suit.hearts, _diamonds = Suit.diamonds, _clubs = Suit.clubs, _spades = Suit.spades;
PlayingCard _c(Suit s, Rank r) => PlayingCard(suit: s, rank: r);

void main() {
  group('HandEvaluator.estimateTricks', () {
    test('a weak, spade-less hand estimates close to zero', () {
      final hand = [
        _c(_clubs, Rank.two), _c(_clubs, Rank.three), _c(_clubs, Rank.four),
        _c(_diamonds, Rank.two), _c(_diamonds, Rank.three), _c(_diamonds, Rank.five),
        _c(_hearts, Rank.two), _c(_hearts, Rank.four), _c(_hearts, Rank.six), _c(_hearts, Rank.seven),
        _c(_spades, Rank.two), _c(_spades, Rank.three), _c(_clubs, Rank.seven),
      ];
      expect(HandEvaluator.estimateTricks(hand), closeTo(0.0, 0.01));
    });

    test('a strong hand with top honors in every suit estimates high', () {
      final hand = [
        _c(_spades, Rank.ace), _c(_spades, Rank.king), _c(_spades, Rank.queen),
        _c(_spades, Rank.nine), _c(_spades, Rank.five),
        _c(_hearts, Rank.ace), _c(_hearts, Rank.king), _c(_hearts, Rank.four),
        _c(_diamonds, Rank.ace), _c(_diamonds, Rank.six),
        _c(_clubs, Rank.ace), _c(_clubs, Rank.three), _c(_clubs, Rank.two),
      ];
      expect(HandEvaluator.estimateTricks(hand), closeTo(7.85, 0.01));
    });
  });

  group('HandEvaluator.isNilSafe / chooseBid', () {
    test('a weak hand is Nil-safe; Hard bids 0, Medium (no Nil) bids 1', () {
      final hand = [
        _c(_clubs, Rank.two), _c(_clubs, Rank.three), _c(_clubs, Rank.four),
        _c(_diamonds, Rank.two), _c(_diamonds, Rank.three), _c(_diamonds, Rank.five),
        _c(_hearts, Rank.two), _c(_hearts, Rank.four), _c(_hearts, Rank.six), _c(_hearts, Rank.seven),
        _c(_spades, Rank.two), _c(_spades, Rank.three), _c(_clubs, Rank.seven),
      ];
      expect(HandEvaluator.isNilSafe(hand), isTrue);
      expect(HandEvaluator.chooseBid(hand, allowNil: true), 0);
      expect(HandEvaluator.chooseBid(hand, allowNil: false), 1);
    });

    test('a hand with an Ace is never Nil-safe even if allowNil is true', () {
      final hand = [_c(_hearts, Rank.ace), _c(_clubs, Rank.two), _c(_diamonds, Rank.three)];
      expect(HandEvaluator.isNilSafe(hand), isFalse);
      expect(HandEvaluator.chooseBid(hand, allowNil: true), isNot(0));
    });

    test('chooseBid always clamps to 1..13 even for an empty hand', () {
      expect(HandEvaluator.chooseBid(const [], allowNil: false), 1);
    });
  });
}
