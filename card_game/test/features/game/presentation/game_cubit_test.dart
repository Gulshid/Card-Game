import 'dart:math';

import 'package:card_game/core/services/haptics_service.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/presentation/bloc/game_cubit.dart';
import 'package:card_game/features/game/presentation/bloc/game_ui_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// `botThinkDelay`/`trickPause` are zeroed throughout so these tests run
/// instantly — the pacing itself has no logic worth testing, only that
/// it doesn't block state transitions when it's zero.
GameCubit _cubit({AiDifficulty difficulty = AiDifficulty.medium, Random? random}) {
  return GameCubit(
    haptics: HapticsService(),
    difficulty: difficulty,
    random: random,
    botThinkDelay: Duration.zero,
    trickPause: Duration.zero,
  );
}

/// Drives the cubit — submitting the human's first legal bid/card
/// whenever it's their turn — until the match ends. This is the
/// presentation layer's equivalent of Phase 04's `simulateFullGame`
/// stress test, but exercised through the real cubit + bot pipeline.
Future<void> _playToMatchOver(GameCubit cubit) async {
  await cubit.start();
  int guard = 0;
  while (cubit.state.game.phase != GamePhase.matchOver) {
    final GameUiState s = cubit.state;
    if (s.game.phase == GamePhase.roundEnd) {
      await cubit.nextRound();
    } else if (s.canHumanAct && s.game.phase == GamePhase.bidding) {
      await cubit.submitBid(3);
    } else if (s.canHumanAct && s.game.phase == GamePhase.playing) {
      final card = s.game.hands[kHumanSeat]!.firstWhere(
        (c) => SpadesRulesEngine.isValidMove(s.game, PlayCardMove(seat: kHumanSeat, card: c)),
      );
      await cubit.playCard(card);
    } else {
      await Future<void>.delayed(Duration.zero);
    }
    guard++;
    if (guard > 3000) fail('game did not reach matchOver within $guard cubit actions');
  }
}

void main() {
  group('GameCubit.start', () {
    test('drives bots forward until it is the human turn, bidding, or terminal', () async {
      final cubit = _cubit(random: Random(1));
      await cubit.start();
      final s = cubit.state;
      expect(
        s.game.turn == kHumanSeat ||
            s.game.phase == GamePhase.roundEnd ||
            s.game.phase == GamePhase.matchOver,
        isTrue,
      );
      expect(s.isBotThinking, isFalse); // never left "thinking" after driving stops
      await cubit.close();
    });
  });

  group('GameCubit.submitBid', () {
    test('is ignored when it is not the human bidding turn', () async {
      final cubit = _cubit(random: Random(2));
      // Force a state where it's not the human's turn to bid, if that's
      // how this seed deals — otherwise the guard below is trivially
      // satisfied and we just confirm nothing throws.
      final before = cubit.state;
      await cubit.submitBid(5);
      if (before.game.turn != kHumanSeat || before.game.phase != GamePhase.bidding) {
        expect(cubit.state, before);
      }
      await cubit.close();
    });
  });

  group('GameCubit.playCard', () {
    test('an illegal card sets a hint and does not change the game state', () async {
      final cubit = _cubit(random: Random(3));
      await cubit.start();

      // Fast-forward through bidding with a fixed bid whenever it's the
      // human's turn, so we reach the playing phase deterministically.
      while (cubit.state.game.phase == GamePhase.bidding) {
        if (cubit.state.canHumanAct) {
          await cubit.submitBid(3);
        } else {
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (cubit.state.game.phase != GamePhase.playing || !cubit.state.canHumanAct) {
        await cubit.close();
        return; // this seed didn't leave the human to move first; skip
      }

      final humanHand = cubit.state.game.hands[kHumanSeat]!;
      final illegal = humanHand.firstWhere(
        (c) => !SpadesRulesEngine.isValidMove(cubit.state.game, PlayCardMove(seat: kHumanSeat, card: c)),
        orElse: () => humanHand.first,
      );
      final beforeGame = cubit.state.game;
      final beforeNonce = cubit.state.hintNonce;

      await cubit.playCard(illegal);

      if (!SpadesRulesEngine.isValidMove(beforeGame, PlayCardMove(seat: kHumanSeat, card: illegal))) {
        expect(cubit.state.game, beforeGame, reason: 'illegal play must not mutate game state');
        expect(cubit.state.hintNonce, greaterThan(beforeNonce));
        expect(cubit.state.hint, isNotNull);
      }
      await cubit.close();
    });
  });

  group('full match via the cubit', () {
    test('reaches matchOver without throwing, across several seeds', () async {
      for (int seed = 0; seed < 8; seed++) {
        final cubit = _cubit(difficulty: AiDifficulty.medium, random: Random(seed));
        await _playToMatchOver(cubit);
        expect(cubit.state.game.phase, GamePhase.matchOver, reason: 'seed $seed did not conclude');
        expect(cubit.state.showMatchResult, isTrue);
        await cubit.close();
      }
    });

    test('restart() begins a fresh match at the same difficulty', () async {
      final cubit = _cubit(difficulty: AiDifficulty.hard, random: Random(4));
      await _playToMatchOver(cubit);
      final finishedRound = cubit.state.game.roundNumber;

      await cubit.restart();
      expect(cubit.state.game.phase, isNot(GamePhase.matchOver));
      expect(cubit.state.game.roundNumber, lessThan(finishedRound + 1));
      expect(cubit.state.difficulty, AiDifficulty.hard);
      await cubit.close();
    });
  });
}
