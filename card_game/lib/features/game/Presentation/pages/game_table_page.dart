import 'package:card_game/core/di/injection_container.dart';
import 'package:card_game/core/services/haptics_service.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/playing_card.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../bloc/game_cubit.dart';
import '../bloc/game_ui_state.dart';
import '../widgets/bid_overlay.dart';
import '../widgets/match_result_sheet.dart';
import '../widgets/opponent_hand_view.dart';
import '../widgets/player_hand_fan.dart';
import '../widgets/round_summary_sheet.dart';
import '../widgets/trick_area.dart';
import '../widgets/turn_score_hud.dart';

/// The felt game table. Hosts its own [GameCubit] — one match's worth of
/// state — created fresh every time this screen is pushed, and disposed
/// automatically when it's popped.
///
/// Deliberately **not** wrapped in `ScreenUtilInit`'s scaling like most
/// other screens (see the note in `main.dart`): a card table needs to
/// reflow its fan/arc geometry on unusual aspect ratios, not just scale
/// a fixed design, so this screen uses `LayoutBuilder` + `AspectRatio`
/// directly instead.
class GameTablePage extends StatelessWidget {
  const GameTablePage({required this.difficulty, super.key});

  final AiDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameCubit(haptics: sl<HapticsService>(), difficulty: difficulty)..start(),
      child: const _GameTableView(),
    );
  }
}

class _GameTableView extends StatelessWidget {
  const _GameTableView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D2C), // felt
      body: SafeArea(
        child: BlocConsumer<GameCubit, GameUiState>(
          listenWhen: (prev, curr) => curr.hint != null && curr.hintNonce != prev.hintNonce,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(state.hint!), duration: const Duration(seconds: 2)));
          },
          builder: (context, state) {
            final cubit = context.read<GameCubit>();

            return Stack(
              children: [
                Column(
                  children: [
                    TurnScoreHud(uiState: state),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => _TableFelt(uiState: state),
                      ),
                    ),
                    PlayerHandFan(
                      cards: state.game.hands[kHumanSeat] ?? const [],
                      enabled: state.canHumanAct && state.game.phase == GamePhase.playing,
                      isLegal: (card) => SpadesRulesEngine.isValidMove(
                        state.game,
                        PlayCardMove(seat: kHumanSeat, card: card),
                      ),
                      onCardTap: cubit.playCard,
                    ),
                    SizedBox(height: 8.h),
                  ],
                ),
                if (state.canHumanAct && state.game.phase == GamePhase.bidding)
                  BidOverlay(onBid: cubit.submitBid),
                if (state.showRoundSummary)
                  RoundSummarySheet(uiState: state, onContinue: cubit.nextRound),
                if (state.showMatchResult)
                  MatchResultSheet(
                    uiState: state,
                    onPlayAgain: cubit.restart,
                    onHome: () => context.pop(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// North/East/West opponents and the central trick, laid out with plain
/// `Positioned` widgets against the felt so the arrangement reads as a
/// table regardless of screen size — this is the "reflow, don't just
/// scale" layout `main.dart` calls out.
class _TableFelt extends StatelessWidget {
  const _TableFelt({required this.uiState});

  final GameUiState uiState;

  @override
  Widget build(BuildContext context) {
    final game = uiState.game;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 8.h,
          child: _OpponentSlot(
            seat: Seat.north,
            uiState: uiState,
            vertical: false,
          ),
        ),
        Positioned(
          right: 4.w,
          child: _OpponentSlot(seat: Seat.east, uiState: uiState, vertical: true),
        ),
        Positioned(
          left: 4.w,
          child: _OpponentSlot(seat: Seat.west, uiState: uiState, vertical: true),
        ),
        TrickArea(trick: uiState.displayTrick, winner: uiState.displayWinner),
        if (game.phase == GamePhase.bidding)
          Positioned(
            bottom: 4.h,
            child: _BidBadges(uiState: uiState),
          ),
      ],
    );
  }
}

class _OpponentSlot extends StatelessWidget {
  const _OpponentSlot({required this.seat, required this.uiState, required this.vertical});

  final Seat seat;
  final GameUiState uiState;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final name = uiState.players[seat]?.name ?? seat.name;
    final isTurn = uiState.game.turn == seat;
    final handCount = uiState.game.hands[seat]?.length ?? 0;

    final label = Text(
      isTurn && uiState.isBotThinking ? '$name…' : name,
      style: TextStyle(
        color: isTurn ? const Color(0xFFC79A3D) : Colors.white70,
        fontWeight: isTurn ? FontWeight.w700 : FontWeight.w400,
        fontSize: 11.sp,
      ),
    );

    final fan = OpponentHandView(
      cardCount: handCount,
      vertical: vertical,
      cardWidth: 26,
      isThinking: isTurn && uiState.isBotThinking,
    );

    return vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: [fan, SizedBox(height: 4.h), label])
        : Column(mainAxisSize: MainAxisSize.min, children: [label, SizedBox(height: 4.h), fan]);
  }
}

class _BidBadges extends StatelessWidget {
  const _BidBadges({required this.uiState});

  final GameUiState uiState;

  @override
  Widget build(BuildContext context) {
    final bids = uiState.game.bids;
    return Wrap(
      spacing: 8.w,
      children: [
        for (final seat in Seat.values)
          if (bids[seat] != null)
            Chip(
              label: Text('${uiState.players[seat]?.name ?? seat.name}: ${bids[seat] == 0 ? "Nil" : bids[seat]}'),
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 10),
              visualDensity: VisualDensity.compact,
            ),
      ],
    );
  }
}
