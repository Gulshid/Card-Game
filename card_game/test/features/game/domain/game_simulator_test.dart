import 'package:card_game/features/game/domain/engine/game_simulator.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('simulateFullGame', () {
    test('a single random-legal-move game always reaches matchOver', () {
      final result = simulateFullGame(seed: 1);
      expect(result.phase, GamePhase.matchOver);
    });

    test('the winning team actually has the higher (or equal, tie) score', () {
      final result = simulateFullGame(seed: 1);
      expect(result.winningTeam, isNotNull);
      final winnerScore = result.teamScores[result.winningTeam]!;
      final otherTeam = result.winningTeam == 0 ? 1 : 0;
      expect(winnerScore, greaterThanOrEqualTo(result.teamScores[otherTeam]!));
      expect(winnerScore, greaterThanOrEqualTo(500));
    });

    test('50 different seeds all reach a valid conclusion without throwing', () {
      // The real point of this test: if the rules engine ever allows
      // an illegal state transition, `applyMove`'s internal
      // `isValidMove` re-check will throw — so "doesn't throw across
      // 50 independent random games" is a meaningful correctness
      // signal, not just a smoke test.
      for (int seed = 0; seed < 50; seed++) {
        final result = simulateFullGame(seed: seed);
        expect(result.phase, GamePhase.matchOver, reason: 'seed $seed did not conclude');
      }
    });

    test('every hand is empty at the moment the match ends', () {
      // Regression guard: catches any bug where a round could be
      // closed out with cards still left in a hand.
      final result = simulateFullGame(seed: 5);
      for (final hand in result.hands.values) {
        expect(hand, isEmpty);
      }
    });
  });
}
