import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:card_game/features/game/domain/models/deck.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/rank.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpadesRulesEngine.newMatch', () {
    test('deals 13 cards to each of the 4 seats', () {
      final state = SpadesRulesEngine.newMatch(seed: 1);
      for (final seat in Seat.values) {
        expect(state.hands[seat], hasLength(13));
      }
    });

    test('deals no duplicate or missing cards across all hands', () {
      final state = SpadesRulesEngine.newMatch(seed: 1);
      final allCards = state.hands.values.expand((h) => h).toSet();
      expect(allCards, hasLength(52));
    });

    test('opens in the bidding phase with the seat left of dealer to act', () {
      final state = SpadesRulesEngine.newMatch(dealer: Seat.north, seed: 1);
      expect(state.phase, GamePhase.bidding);
      expect(state.turn, Seat.east);
      expect(state.leader, Seat.east);
    });

    test('same seed deals the same hands every time', () {
      final a = SpadesRulesEngine.newMatch(seed: 99);
      final b = SpadesRulesEngine.newMatch(seed: 99);
      expect(a.hands, equals(b.hands));
    });
  });

  group('bidding', () {
    test('only the seat whose turn it is may bid', () {
      final state = SpadesRulesEngine.newMatch(dealer: Seat.north, seed: 1);
      expect(state.turn, Seat.east);
      final wrongSeatBid = BidMove(seat: Seat.south, tricksBid: 3);
      expect(SpadesRulesEngine.isValidMove(state, wrongSeatBid), isFalse);
    });

    test('bids outside 0..13 are invalid', () {
      final state = SpadesRulesEngine.newMatch(seed: 1);
      expect(SpadesRulesEngine.isValidMove(state, BidMove(seat: state.turn, tricksBid: -1)), isFalse);
      expect(SpadesRulesEngine.isValidMove(state, BidMove(seat: state.turn, tricksBid: 14)), isFalse);
      expect(SpadesRulesEngine.isValidMove(state, BidMove(seat: state.turn, tricksBid: 0)), isTrue);
      expect(SpadesRulesEngine.isValidMove(state, BidMove(seat: state.turn, tricksBid: 13)), isTrue);
    });

    test('advances turn clockwise and transitions to playing once all 4 have bid', () {
      var state = SpadesRulesEngine.newMatch(dealer: Seat.north, seed: 1);
      expect(state.turn, Seat.east);

      state = SpadesRulesEngine.applyMove(state, BidMove(seat: Seat.east, tricksBid: 3));
      expect(state.turn, Seat.south);
      expect(state.phase, GamePhase.bidding);

      state = SpadesRulesEngine.applyMove(state, BidMove(seat: Seat.south, tricksBid: 2));
      state = SpadesRulesEngine.applyMove(state, BidMove(seat: Seat.west, tricksBid: 4));
      expect(state.phase, GamePhase.bidding);

      state = SpadesRulesEngine.applyMove(state, BidMove(seat: Seat.north, tricksBid: 1));
      expect(state.phase, GamePhase.playing);
      expect(state.turn, Seat.east); // leader plays first
    });

    test('applyMove throws on an illegal move rather than silently accepting it', () {
      final state = SpadesRulesEngine.newMatch(dealer: Seat.north, seed: 1);
      expect(
        () => SpadesRulesEngine.applyMove(state, BidMove(seat: Seat.south, tricksBid: 3)),
        throwsStateError,
      );
    });
  });

  group('trick play — legality', () {
    test('must follow the suit led if holding that suit', () {
      var state = _biddingComplete(seed: 1);
      final leader = state.turn;
      final leadCard = state.hands[leader]!.first;
      state = SpadesRulesEngine.applyMove(state, PlayCardMove(seat: leader, card: leadCard));

      final nextSeat = state.turn;
      final hand = state.hands[nextSeat]!;
      final hasLedSuit = hand.any((c) => c.suit == leadCard.suit);

      for (final card in hand) {
        final isValid = SpadesRulesEngine.isValidMove(state, PlayCardMove(seat: nextSeat, card: card));
        if (hasLedSuit) {
          expect(isValid, card.suit == leadCard.suit, reason: 'must follow suit when able: $card');
        } else {
          expect(isValid, isTrue, reason: 'void in led suit may play anything: $card');
        }
      }
    });

    test('may not lead spades before they are broken, unless holding only spades', () {
      final state = _biddingComplete(seed: 1);
      final leader = state.turn;
      final hand = state.hands[leader]!;
      final onlyHoldsSpades = hand.every((c) => c.suit == Suit.spades);

      for (final card in hand.where((c) => c.suit == Suit.spades)) {
        final isValid = SpadesRulesEngine.isValidMove(state, PlayCardMove(seat: leader, card: card));
        expect(isValid, onlyHoldsSpades, reason: 'leading a spade unbroken should be illegal unless forced');
      }
    });

    test('a card not in hand is never a legal play', () {
      final state = _biddingComplete(seed: 1);
      final leader = state.turn;
      final hand = state.hands[leader]!.toSet();
      final notInHand = Deck.standard52().cards.firstWhere((c) => !hand.contains(c));
      expect(SpadesRulesEngine.isValidMove(state, PlayCardMove(seat: leader, card: notInHand)), isFalse);
    });
  });

  group('trick resolution (driven through real applyMove calls)', () {
    test('highest card of the led suit wins when no spade is played', () {
      var state = _bareTrickState(
        hands: {
          Seat.east: const [PlayingCard(suit: Suit.hearts, rank: Rank.seven)],
          Seat.south: const [PlayingCard(suit: Suit.hearts, rank: Rank.king)],
          Seat.west: const [PlayingCard(suit: Suit.clubs, rank: Rank.ace)], // off-suit, can't win
          Seat.north: const [PlayingCard(suit: Suit.hearts, rank: Rank.ten)],
        },
      );
      state = _playAllFour(state);
      expect(state.leader, Seat.south);
      expect(state.tricksWonBySeat[Seat.south], 1);
    });

    test('any spade beats every card of the led suit', () {
      var state = _bareTrickState(
        hands: {
          Seat.east: const [PlayingCard(suit: Suit.hearts, rank: Rank.ace)],
          Seat.south: const [PlayingCard(suit: Suit.spades, rank: Rank.two)],
          Seat.west: const [PlayingCard(suit: Suit.hearts, rank: Rank.king)],
          Seat.north: const [PlayingCard(suit: Suit.hearts, rank: Rank.queen)],
        },
      );
      state = _playAllFour(state);
      expect(state.leader, Seat.south);
    });

    test('highest spade wins when multiple spades are played', () {
      var state = _bareTrickState(
        hands: {
          Seat.east: const [PlayingCard(suit: Suit.spades, rank: Rank.four)],
          Seat.south: const [PlayingCard(suit: Suit.spades, rank: Rank.jack)],
          Seat.west: const [PlayingCard(suit: Suit.clubs, rank: Rank.ace)],
          Seat.north: const [PlayingCard(suit: Suit.spades, rank: Rank.nine)],
        },
        spadesBroken: true, // east's spade lead is only legal once broken
      );
      state = _playAllFour(state);
      expect(state.leader, Seat.south);
    });
  });

  group('startNextRound', () {
    test('throws if called before the round has ended', () {
      final state = SpadesRulesEngine.newMatch(seed: 1);
      expect(() => SpadesRulesEngine.startNextRound(state), throwsStateError);
    });

    test('rotates the dealer clockwise and increments the round number', () {
      final midRound = SpadesRulesEngine.newMatch(dealer: Seat.north, seed: 1);
      final roundEndState = midRound.copyWith(phase: GamePhase.roundEnd);
      final next = SpadesRulesEngine.startNextRound(roundEndState, seed: 2);
      expect(next.dealer, Seat.east);
      expect(next.roundNumber, midRound.roundNumber + 1);
      expect(next.phase, GamePhase.bidding);
    });
  });
}

/// Deals a fresh match and drives it through bidding with a fixed,
/// legal bid sequence so tests can start from `GamePhase.playing`
/// without repeating this boilerplate in every test.
GameState _biddingComplete({required int seed}) {
  var state = SpadesRulesEngine.newMatch(dealer: Seat.north, seed: seed);
  for (int i = 0; i < 4; i++) {
    state = SpadesRulesEngine.applyMove(state, BidMove(seat: state.turn, tricksBid: 3));
  }
  return state;
}

/// Builds a minimal, hand-crafted `playing`-phase state — each seat
/// holding only the single card it will play — so trick-resolution
/// tests can exercise the real `applyMove` path without the
/// boilerplate of a full 13-card deal.
GameState _bareTrickState({
  required Map<Seat, List<PlayingCard>> hands,
  bool spadesBroken = false,
}) {
  return GameState(
    phase: GamePhase.playing,
    dealer: Seat.north,
    turn: Seat.east,
    leader: Seat.east,
    hands: hands,
    bids: {for (final seat in Seat.values) seat: 3},
    currentTrick: const [],
    completedTricks: const [],
    tricksWonBySeat: {for (final seat in Seat.values) seat: 0},
    spadesBroken: spadesBroken,
    teamScores: const {0: 0, 1: 0},
    teamBags: const {0: 0, 1: 0},
    roundNumber: 1,
  );
}

/// Plays each seat's (single, pre-arranged) card in turn order,
/// starting from `state.leader`.
GameState _playAllFour(GameState state) {
  var current = state;
  for (int i = 0; i < 4; i++) {
    final seat = current.turn;
    final card = current.hands[seat]!.first;
    current = SpadesRulesEngine.applyMove(current, PlayCardMove(seat: seat, card: card));
  }
  return current;
}
