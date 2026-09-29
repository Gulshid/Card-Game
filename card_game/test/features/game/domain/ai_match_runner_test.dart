import 'dart:math';

import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/ai/ai_factory.dart';
import 'package:card_game/features/game/domain/ai/ai_match_runner.dart';
import 'package:card_game/features/game/domain/ai/ai_strategy.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:flutter_test/flutter_test.dart';

/// The strongest signal that a bot never proposes an illegal move: every
/// move a strategy returns goes through `SpadesRulesEngine.applyMove`
/// inside `playMatchWithStrategies`, which throws on anything illegal.
/// So "doesn't throw across many seeds and difficulty combinations" is a
/// meaningful correctness check, not just a smoke test.
void main() {
  Map<Seat, AiStrategy> allFour(AiDifficulty difficulty, Random rng) {
    return {for (final seat in Seat.values) seat: createAiStrategy(difficulty, random: rng)};
  }

  group('every bot only ever proposes legal moves', () {
    for (final difficulty in AiDifficulty.values) {
      test('${difficulty.name} vs ${difficulty.name}: 30 seeds, none throw', () {
        for (int seed = 0; seed < 30; seed++) {
          final result = playMatchWithStrategies(
            allFour(difficulty, Random(seed)),
            seed: seed,
            maxRounds: 400,
          );
          expect(result.phase, GamePhase.matchOver, reason: 'seed $seed ($difficulty) did not conclude');
        }
      });
    }

    test('mixed difficulties per seat: 20 seeds, none throw', () {
      for (int seed = 0; seed < 20; seed++) {
        final rng = Random(seed);
        final strategies = {
          Seat.north: createAiStrategy(AiDifficulty.hard, random: rng),
          Seat.south: createAiStrategy(AiDifficulty.medium, random: rng),
          Seat.east: createAiStrategy(AiDifficulty.easy, random: rng),
          Seat.west: createAiStrategy(AiDifficulty.hard, random: rng),
        };
        final result = playMatchWithStrategies(strategies, seed: seed, maxRounds: 400);
        expect(result.phase, GamePhase.matchOver, reason: 'seed $seed did not conclude');
      }
    });
  });

  group('difficulty actually matters', () {
    test('Hard beats Easy in most matches over a reasonable sample', () {
      // Not a tight statistical claim — just confirms Hard is not weaker
      // than Easy, which would indicate a bug in the heuristics.
      int hardWins = 0;
      const int matches = 40;
      for (int seed = 0; seed < matches; seed++) {
        final rng = Random(seed);
        final hardIsTeamZero = seed.isEven;
        final strategies = {
          Seat.north: createAiStrategy(hardIsTeamZero ? AiDifficulty.hard : AiDifficulty.easy, random: rng),
          Seat.south: createAiStrategy(hardIsTeamZero ? AiDifficulty.hard : AiDifficulty.easy, random: rng),
          Seat.east: createAiStrategy(hardIsTeamZero ? AiDifficulty.easy : AiDifficulty.hard, random: rng),
          Seat.west: createAiStrategy(hardIsTeamZero ? AiDifficulty.easy : AiDifficulty.hard, random: rng),
        };
        final result = playMatchWithStrategies(strategies, seed: seed, maxRounds: 400);
        final int hardTeam = hardIsTeamZero ? 0 : 1;
        if (result.winningTeam == hardTeam) hardWins++;
      }
      expect(hardWins, greaterThan(matches ~/ 2), reason: 'Hard should win the majority of matches against Easy');
    });
  });
}
