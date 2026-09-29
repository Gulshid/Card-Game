import 'package:card_game/features/game/domain/ai/hard_ai.dart';
import 'package:card_game/features/game/domain/ai/medium_ai.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/rank.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:card_game/features/game/domain/models/trick_card.dart';
import 'package:flutter_test/flutter_test.dart';

const _h = Suit.hearts, _d = Suit.diamonds, _c = Suit.clubs, _s = Suit.spades;
PlayingCard _card(Suit suit, Rank rank) => PlayingCard(suit: suit, rank: rank);

/// Builds a `playing`-phase state with only the cards each seat needs
/// for the scenario at hand — same minimal-fixture style as the Phase 04
/// engine tests.
GameState _state({
  required Seat turn,
  required Map<Seat, List<PlayingCard>> hands,
  required List<TrickCard> trick,
  required Map<Seat, int> bids,
  List<List<TrickCard>> completed = const [],
  bool spadesBroken = true,
}) {
  return GameState(
    phase: GamePhase.playing,
    dealer: Seat.north,
    turn: turn,
    leader: trick.isEmpty ? turn : trick.first.seat,
    hands: hands,
    bids: {for (final s in Seat.values) s: bids[s]},
    currentTrick: trick,
    completedTricks: completed,
    tricksWonBySeat: {for (final s in Seat.values) s: 0},
    spadesBroken: spadesBroken,
    teamScores: const {0: 0, 1: 0},
    teamBags: const {0: 0, 1: 0},
    roundNumber: 1,
  );
}

void main() {
  const medium = MediumAi();
  const hard = HardAi();

  group('MediumAi.chooseFollow', () {
    test('partner is winning and we want more tricks: dump the lowest card', () {
      final state = _state(
        turn: Seat.south,
        hands: {
          Seat.north: const [], Seat.east: const [], Seat.west: const [],
          Seat.south: [_card(_h, Rank.nine), _card(_h, Rank.three), _card(_c, Rank.two), _card(_s, Rank.four)],
        },
        trick: [
          TrickCard(seat: Seat.west, card: _card(_h, Rank.five)),
          TrickCard(seat: Seat.north, card: _card(_h, Rank.king)), // partner winning
          TrickCard(seat: Seat.east, card: _card(_h, Rank.seven)),
        ],
        bids: {for (final s in Seat.values) s: 3},
      );
      final move = medium.chooseMove(state) as PlayCardMove;
      expect(move.card, _card(_h, Rank.three));
    });

    test('opponent winning, we want tricks: win as cheaply as possible', () {
      final state = _state(
        turn: Seat.south,
        hands: {
          Seat.north: const [], Seat.east: const [], Seat.west: const [],
          Seat.south: [_card(_h, Rank.queen), _card(_h, Rank.king), _card(_h, Rank.three), _card(_c, Rank.two)],
        },
        trick: [
          TrickCard(seat: Seat.west, card: _card(_h, Rank.nine)),
          TrickCard(seat: Seat.north, card: _card(_h, Rank.six)),
          TrickCard(seat: Seat.east, card: _card(_h, Rank.ten)), // opponent winning
        ],
        bids: {for (final s in Seat.values) s: 3},
      );
      final move = medium.chooseMove(state) as PlayCardMove;
      expect(move.card, _card(_h, Rank.queen)); // cheapest card that still beats the ten
    });

    test('south bid Nil: duck under the winner with the highest safe loser', () {
      final state = _state(
        turn: Seat.south,
        hands: {
          Seat.north: const [], Seat.east: const [], Seat.west: const [],
          Seat.south: [_card(_h, Rank.ten), _card(_h, Rank.two), _card(_h, Rank.queen), _card(_c, Rank.three)],
        },
        trick: [
          TrickCard(seat: Seat.west, card: _card(_h, Rank.nine)),
          TrickCard(seat: Seat.north, card: _card(_h, Rank.four)),
          TrickCard(seat: Seat.east, card: _card(_h, Rank.jack)), // currently winning
        ],
        bids: {Seat.north: 3, Seat.east: 3, Seat.west: 3, Seat.south: 0},
      );
      final move = medium.chooseMove(state) as PlayCardMove;
      expect(move.card, _card(_h, Rank.ten)); // highest heart that still loses to the jack
    });
  });

  group('MediumAi vs HardAi leading', () {
    test('with both diamond honors already played, Medium leads its remaining honor '
        'while Hard leads the master (unbeatable) card instead', () {
      final completed = [
        [
          TrickCard(seat: Seat.east, card: _card(_d, Rank.ace)),
          TrickCard(seat: Seat.south, card: _card(_d, Rank.two)),
          TrickCard(seat: Seat.west, card: _card(_d, Rank.king)),
          TrickCard(seat: Seat.north, card: _card(_d, Rank.three)),
        ],
      ];
      final state = _state(
        turn: Seat.south,
        hands: {
          Seat.north: const [], Seat.east: const [], Seat.west: const [],
          Seat.south: [_card(_h, Rank.king), _card(_d, Rank.queen), _card(_c, Rank.three)],
        },
        trick: const [],
        bids: {for (final s in Seat.values) s: 3},
        completed: completed,
      );

      expect((medium.chooseMove(state) as PlayCardMove).card, _card(_h, Rank.king));
      expect((hard.chooseMove(state) as PlayCardMove).card, _card(_d, Rank.queen));
    });
  });

  group('HardAi bidding', () {
    test('bids Nil on a hand with no Aces/Kings and few spades', () {
      final hand = [
        _card(_c, Rank.two), _card(_c, Rank.three), _card(_c, Rank.four),
        _card(_d, Rank.two), _card(_d, Rank.three), _card(_d, Rank.five),
        _card(_h, Rank.two), _card(_h, Rank.four), _card(_h, Rank.six), _card(_h, Rank.seven),
        _card(_s, Rank.two), _card(_s, Rank.three), _card(_c, Rank.seven),
      ];
      final state = GameState(
        phase: GamePhase.bidding,
        dealer: Seat.north,
        turn: Seat.south,
        leader: Seat.south,
        hands: {Seat.north: const [], Seat.east: const [], Seat.west: const [], Seat.south: hand},
        bids: {for (final s in Seat.values) s: null},
        currentTrick: const [],
        completedTricks: const [],
        tricksWonBySeat: {for (final s in Seat.values) s: 0},
        spadesBroken: false,
        teamScores: const {0: 0, 1: 0},
        teamBags: const {0: 0, 1: 0},
        roundNumber: 1,
      );
      expect((hard.chooseMove(state) as BidMove).tricksBid, 0);
      expect((medium.chooseMove(state) as BidMove).tricksBid, isNot(0)); // Medium never bids Nil
    });
  });

  group('fairness — a strategy may only use its own hand and public info', () {
    test('HardAi.chooseFollow gives the same answer regardless of what the '
        'opponents actually hold, given identical own-hand and public state', () {
      final trick = [
        TrickCard(seat: Seat.west, card: _card(_h, Rank.nine)),
        TrickCard(seat: Seat.north, card: _card(_h, Rank.six)),
        TrickCard(seat: Seat.east, card: _card(_h, Rank.ten)),
      ];
      final ownHand = [_card(_h, Rank.queen), _card(_h, Rank.king), _card(_c, Rank.two)];
      const bids = {Seat.north: 3, Seat.east: 3, Seat.west: 3, Seat.south: 3};

      final stateA = _state(
        turn: Seat.south,
        hands: {
          Seat.north: [_card(_c, Rank.four)], // arbitrary, irrelevant opponent cards
          Seat.east: [_card(_d, Rank.eight)],
          Seat.west: [_card(_s, Rank.five)],
          Seat.south: ownHand,
        },
        trick: trick,
        bids: bids,
      );
      final stateB = _state(
        turn: Seat.south,
        hands: {
          // Completely different (but equally arbitrary) opponent hands —
          // must not change Hard's decision, since it never reads them.
          Seat.north: [_card(_s, Rank.jack), _card(_c, Rank.nine)],
          Seat.east: [_card(_d, Rank.two)],
          Seat.west: [_card(_h, Rank.two), _card(_h, Rank.four)],
          Seat.south: ownHand,
        },
        trick: trick,
        bids: bids,
      );

      final moveA = (hard.chooseMove(stateA) as PlayCardMove).card;
      final moveB = (hard.chooseMove(stateB) as PlayCardMove).card;
      expect(moveA, moveB);
    });
  });
}
