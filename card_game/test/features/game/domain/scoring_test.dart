import 'package:card_game/features/game/domain/engine/scoring.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scoring.scoreTeam', () {
    test('team makes bid exactly: 10 points per bid, no bags', () {
      final result = Scoring.scoreTeam(
        team: 0,
        bids: {Seat.north: 4, Seat.south: 3, Seat.east: 2, Seat.west: 4},
        tricksWonBySeat: {Seat.north: 4, Seat.south: 3, Seat.east: 2, Seat.west: 4},
        existingBags: 0,
      );
      expect(result.madeBid, isTrue);
      expect(result.scoreDelta, 70); // 10 * (4 + 3)
      expect(result.bagsDelta, 0);
    });

    test('team exceeds bid: scores the bid, banks the overtricks as bags', () {
      final result = Scoring.scoreTeam(
        team: 0,
        bids: {Seat.north: 4, Seat.south: 2, Seat.east: 0, Seat.west: 0},
        tricksWonBySeat: {Seat.north: 5, Seat.south: 3, Seat.east: 0, Seat.west: 0},
        existingBags: 0,
      );
      expect(result.madeBid, isTrue);
      expect(result.scoreDelta, 60); // 10 * (4 + 2)
      expect(result.bagsDelta, 2); // 8 tricks won - 6 bid
    });

    test('team fails bid: negative score, no bags awarded', () {
      final result = Scoring.scoreTeam(
        team: 0,
        bids: {Seat.north: 5, Seat.south: 3, Seat.east: 0, Seat.west: 0},
        tricksWonBySeat: {Seat.north: 4, Seat.south: 3, Seat.east: 0, Seat.west: 0},
        existingBags: 0,
      );
      expect(result.madeBid, isFalse);
      expect(result.scoreDelta, -80); // -10 * (5 + 3)
      expect(result.bagsDelta, 0);
    });

    test('nil made: +100 bonus, partner scored independently', () {
      final result = Scoring.scoreTeam(
        team: 0,
        bids: {Seat.north: 0, Seat.south: 6, Seat.east: 0, Seat.west: 0},
        tricksWonBySeat: {Seat.north: 0, Seat.south: 6, Seat.east: 0, Seat.west: 0},
        existingBags: 0,
      );
      expect(result.madeBid, isTrue); // south's 6 tricks vs a 6-trick target
      expect(result.scoreDelta, 160); // 10*6 + 100 nil bonus
    });

    test('nil failed: -100 penalty applies even if partner makes their bid', () {
      final result = Scoring.scoreTeam(
        team: 0,
        bids: {Seat.north: 0, Seat.south: 6, Seat.east: 0, Seat.west: 0},
        tricksWonBySeat: {Seat.north: 1, Seat.south: 6, Seat.east: 0, Seat.west: 0},
        existingBags: 0,
      );
      // Team trick target is 6 (nil contributes 0); team won 7 tricks
      // total, so the bid is still made — but the nil itself failed.
      expect(result.madeBid, isTrue);
      expect(result.scoreDelta, -40); // 10*6 (=60) - 100 nil penalty + 1 bag
      expect(result.bagsDelta, 1);
    });

    test('crossing 10 accumulated bags applies a -100 penalty and wraps the counter', () {
      final result = Scoring.scoreTeam(
        team: 0,
        bids: {Seat.north: 2, Seat.south: 1, Seat.east: 0, Seat.west: 0},
        tricksWonBySeat: {Seat.north: 5, Seat.south: 1, Seat.east: 0, Seat.west: 0},
        existingBags: 8, // 8 existing + 3 new bags this round = 11
      );
      expect(result.bagPenaltyApplied, isTrue);
      expect(result.bagsDelta, -7); // existingBags(8) -> newCount(1): delta -7
      expect(result.scoreDelta, 30 - 100); // 10*(2+1) bid, minus the bag penalty
    });

    test('exactly 10 bags triggers the penalty (boundary, not just over)', () {
      final result = Scoring.scoreTeam(
        team: 0,
        bids: {Seat.north: 2, Seat.south: 1, Seat.east: 0, Seat.west: 0},
        tricksWonBySeat: {Seat.north: 4, Seat.south: 1, Seat.east: 0, Seat.west: 0},
        existingBags: 8, // 8 + 2 = 10 exactly
      );
      expect(result.bagPenaltyApplied, isTrue);
      expect(result.bagsDelta, -8); // wraps to 0
    });
  });
}
