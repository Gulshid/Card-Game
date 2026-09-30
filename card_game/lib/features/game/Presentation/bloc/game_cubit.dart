import 'dart:async';
import 'dart:math';

import 'package:card_game/core/audio/audio_service.dart';
import 'package:card_game/core/services/haptics_service.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/ai/ai_factory.dart';
import 'package:card_game/features/game/domain/ai/ai_strategy.dart';
import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/models/suit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'game_ui_state.dart';

/// Runs one single-player match: the human plays South, three bots play
/// the other seats. The rules engine (Phase 04) stays the single source
/// of truth — this cubit only feeds it moves and adds pacing plus,
/// since Phase 08, audio/haptic feedback for every game moment.
///
/// Flow: whenever it is a bot's turn, [_drive] waits [botThinkDelay],
/// asks that bot's strategy for a move, applies it, and repeats until it
/// is the human's turn (or the round/match ends). Human input is ignored
/// while a bot is "thinking" or a finished trick is on display.
class GameCubit extends Cubit<GameUiState> {
  GameCubit({
    required HapticsService haptics,
    required AudioService audio,
    AiDifficulty difficulty = AiDifficulty.medium,
    Random? random,
    this.botThinkDelay = const Duration(milliseconds: 750),
    this.trickPause = const Duration(milliseconds: 1200),
  })  : _haptics = haptics,
        _audio = audio,
        _difficulty = difficulty,
        _random = random ?? Random(),
        _strategies = {
          for (final Seat seat in Seat.values)
            if (seat != kHumanSeat) seat: createAiStrategy(difficulty, random: random),
        },
        super(GameUiState.initial(difficulty: difficulty, game: _newGame(random)));

  final HapticsService _haptics;
  final AudioService _audio;
  final AiDifficulty _difficulty;
  final Random _random;
  final Map<Seat, AiStrategy> _strategies;

  /// Delay before a bot moves. `Duration.zero` in tests.
  final Duration botThinkDelay;

  /// How long a completed trick stays on the table. `Duration.zero` in tests.
  final Duration trickPause;

  bool _driving = false;

  static GameState _newGame(Random? random) {
    final Random r = random ?? Random();
    return SpadesRulesEngine.newMatch(dealer: Seat.values[r.nextInt(Seat.values.length)], seed: r.nextInt(0x7fffffff));
  }

  /// Lets the bots act until it is the human's turn. Call once after the
  /// cubit is created — this is also where table music starts, since
  /// it's the single guaranteed entry point every match goes through.
  Future<void> start() async {
    unawaited(_audio.playMusic(MusicTrack.tableAmbience));
    unawaited(_audio.play(SfxCue.cardDeal));
    await _drive();
  }

  /// Human bids [tricks] (0 = Nil).
  Future<void> submitBid(int tricks) async {
    final GameUiState s = state;
    if (!s.canHumanAct || s.game.phase != GamePhase.bidding) return;

    final BidMove move = BidMove(seat: kHumanSeat, tricksBid: tricks);
    if (!SpadesRulesEngine.isValidMove(s.game, move)) return;

    _haptics.selection();
    unawaited(_audio.play(SfxCue.bidConfirm));
    await _applyAndPresent(move);
    await _drive();
  }

  /// Human plays [card]. Illegal plays are rejected with an explanatory hint.
  Future<void> playCard(PlayingCard card) async {
    final GameUiState s = state;
    if (!s.canHumanAct || s.game.phase != GamePhase.playing) return;

    final PlayCardMove move = PlayCardMove(seat: kHumanSeat, card: card);
    if (!SpadesRulesEngine.isValidMove(s.game, move)) {
      _haptics.notification();
      unawaited(_audio.play(SfxCue.invalidMove));
      emit(s.copyWith(hint: _explainIllegalPlay(s.game, card), hintNonce: s.hintNonce + 1));
      return;
    }

    _haptics.light();
    unawaited(_audio.play(SfxCue.cardPlace));
    await _applyAndPresent(move);
    await _drive();
  }

  /// Purely tactile/audio feedback when the human raises a card, before
  /// committing to playing it (e.g. on long-press-to-preview, if the UI
  /// ever adds one). Not currently wired to a gesture.
  void onCardSelected() {
    _haptics.selection();
    unawaited(_audio.play(SfxCue.buttonTap));
  }

  /// Deals the next round once the summary has been dismissed.
  Future<void> nextRound() async {
    final GameUiState s = state;
    if (s.game.phase != GamePhase.roundEnd || s.isBusy) return;

    final GameState next = SpadesRulesEngine.startNextRound(s.game, seed: _random.nextInt(0x7fffffff));
    unawaited(_audio.play(SfxCue.cardDeal));
    emit(
      s.copyWith(
        game: next,
        displayTrick: const [],
        clearDisplayWinner: true,
        roundStartScores: next.teamScores,
        roundStartBags: next.teamBags,
      ),
    );
    await _drive();
  }

  /// Starts a brand-new match at the same difficulty.
  Future<void> restart() async {
    if (state.isBusy) return;
    unawaited(_audio.play(SfxCue.cardDeal));
    emit(GameUiState.initial(difficulty: _difficulty, game: _newGame(_random)));
    await _drive();
  }

  @override
  Future<void> close() async {
    await _audio.stopMusic();
    return super.close();
  }

  // ---- internals --------------------------------------------------------

  Future<void> _drive() async {
    if (_driving) return;
    _driving = true;
    try {
      while (!isClosed) {
        final GameState game = state.game;
        if (game.phase == GamePhase.roundEnd || game.phase == GamePhase.matchOver) break;
        if (game.turn == kHumanSeat) break;

        emit(state.copyWith(isBotThinking: true));
        await _wait(botThinkDelay);
        if (isClosed) return;

        final Move move = _strategies[game.turn]!.chooseMove(game);
        await _applyAndPresent(move);
      }
    } finally {
      _driving = false;
      if (!isClosed && state.isBotThinking) {
        emit(state.copyWith(isBotThinking: false));
      }
    }
  }

  /// Applies [move], updates what the table shows, and fires the audio
  /// cue for whatever just happened — a completed trick, a round
  /// closing, or the match ending. When the move completes a trick, the
  /// finished trick stays visible (input locked) for [trickPause]
  /// before the table clears.
  Future<void> _applyAndPresent(Move move) async {
    final GameUiState before = state;
    final GameState after = SpadesRulesEngine.applyMove(before.game, move);
    final bool trickCompleted = after.completedTricks.length > before.game.completedTricks.length;

    if (!trickCompleted) {
      emit(
        before.copyWith(
          game: after,
          displayTrick: after.currentTrick,
          clearDisplayWinner: true,
          isBotThinking: false,
        ),
      );
      return;
    }

    unawaited(_audio.play(SfxCue.trickWin));
    emit(
      before.copyWith(
        game: after,
        displayTrick: after.completedTricks.last,
        displayWinner: after.leader,
        isBotThinking: false,
        isResolvingTrick: true,
      ),
    );
    await _wait(trickPause);
    if (isClosed) return;

    _playRoundOrMatchCue(before, after);
    emit(state.copyWith(displayTrick: const [], clearDisplayWinner: true, isResolvingTrick: false));
  }

  /// Fires the appropriate cue when a trick's resolution also closed
  /// out the round or the whole match. `before.roundStartScores` is
  /// this round's opening score, so the human team's delta tells us
  /// whether to play a "win" or "lose" cue for the round.
  void _playRoundOrMatchCue(GameUiState before, GameState after) {
    if (after.phase == GamePhase.matchOver) {
      _haptics.notification();
      unawaited(_audio.play(after.winningTeam == 0 ? SfxCue.matchWin : SfxCue.matchLose));
      return;
    }
    if (after.phase == GamePhase.roundEnd) {
      final int humanDelta = (after.teamScores[0] ?? 0) - (before.roundStartScores[0] ?? 0);
      final int opponentDelta = (after.teamScores[1] ?? 0) - (before.roundStartScores[1] ?? 0);
      _haptics.medium();
      unawaited(_audio.play(humanDelta >= opponentDelta ? SfxCue.roundWin : SfxCue.roundLose));
    }
  }

  Future<void> _wait(Duration duration) async {
    if (duration > Duration.zero) {
      await Future<void>.delayed(duration);
    }
  }

  String _explainIllegalPlay(GameState game, PlayingCard card) {
    final List<PlayingCard> hand = game.hands[kHumanSeat] ?? const [];
    if (!hand.contains(card)) return 'That card is not in your hand.';
    if (game.currentTrick.isEmpty) {
      if (card.suit == Suit.spades && !game.spadesBroken) {
        return 'Spades are not broken yet — lead another suit.';
      }
      return 'You cannot play that card now.';
    }
    final Suit led = game.currentTrick.first.card.suit;
    return 'You must follow suit (${led.symbol}).';
  }
}
