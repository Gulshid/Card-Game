import 'package:card_game/core/audio/audio_service.dart';
import 'package:card_game/core/di/injection_container.dart';
import 'package:card_game/core/services/haptics_service.dart';
import 'package:card_game/features/Profile/domain/models/achievements.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:card_game/features/game/domain/models/saved_match.dart';
import 'package:card_game/features/game/domain/repositories/saved_match_repository.dart';
import 'package:card_game/features/Profile/bloc/profile_cubit.dart';
import 'package:card_game/features/Profile/bloc/profile_state.dart';
import 'package:card_game/features/Profile/presentation/widgets/card_back_scope.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/move.dart';
import 'package:card_game/features/game/domain/models/seat.dart';
import 'package:card_game/features/game/domain/engine/spades_rules_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../bloc/game_cubit.dart';
import '../bloc/game_ui_state.dart';
import '../widgets/bid_overlay.dart';
import '../widgets/deal_animation_overlay.dart';
import '../widgets/match_result_sheet.dart';
import '../widgets/opponent_hand_view.dart';
import '../widgets/player_hand_fan.dart';
import '../widgets/pulse_glow.dart';
import '../widgets/round_summary_sheet.dart';
import '../widgets/trick_area.dart';
import '../widgets/turn_score_hud.dart';

/// The felt game table. Hosts its own [GameCubit] — one match's worth of
/// state — created fresh every time this screen is pushed, and disposed
/// automatically when it's popped (which also stops the table music —
/// see `GameCubit.close`).
///
/// Deliberately **not** wrapped in `ScreenUtilInit`'s scaling like most
/// other screens (see the note in `main.dart`): a card table needs to
/// reflow its fan/arc geometry on unusual aspect ratios, not just scale
/// a fixed design, so this screen uses `LayoutBuilder` + `AspectRatio`
/// directly instead.
///
/// Phase 09: pass [resume] to continue a suspended match. The cubit saves
/// after every move, records the result to the profile when the match
/// ends, and the table draws the card back the player picked.
class GameTablePage extends StatelessWidget {
  const GameTablePage({required this.difficulty, this.resume, super.key});

  final AiDifficulty difficulty;
  final SavedMatch? resume;

  @override
  Widget build(BuildContext context) {
    final ProfileCubit profile = context.read<ProfileCubit>();
    return BlocProvider(
      create: (_) => GameCubit(
        haptics: sl<HapticsService>(),
        audio: sl<AudioService>(),
        difficulty: difficulty,
        savedMatches: sl<SavedMatchRepository>(),
        resume: resume,
        onMatchFinished: profile.recordMatch,
      )..start(),
      child: BlocSelector<ProfileCubit, ProfileState, CardBackStyle>(
        selector: (state) => state.profile.cardBack,
        builder: (context, cardBack) => CardBackScope(
          style: cardBack,
          child: _GameTableView(resumed: resume != null),
        ),
      ),
    );
  }
}

class _GameTableView extends StatefulWidget {
  const _GameTableView({required this.resumed});

  /// A resumed match opens mid-round, so the deal flourish is skipped for
  /// the round it resumes into (later rounds deal normally).
  final bool resumed;

  @override
  State<_GameTableView> createState() => _GameTableViewState();
}

class _GameTableViewState extends State<_GameTableView> {
  int? _lastDealtRound;
  bool _showDealAnimation = false;

  @override
  void initState() {
    super.initState();
    if (widget.resumed) {
      _lastDealtRound = context.read<GameCubit>().state.game.roundNumber;
    }
  }

  /// Shows the deal flourish once per round — including the very first
  /// one — by comparing the round number on every rebuild rather than
  /// hooking into `GameCubit` directly, so this stays a pure
  /// presentation-layer concern (Phase 07 shouldn't need to touch the
  /// cubit's state shape).
  void _maybeTriggerDealAnimation(int roundNumber) {
    if (_lastDealtRound == roundNumber) return;
    _lastDealtRound = roundNumber;
    // Defer the setState to after this build so we don't call it
    // mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _showDealAnimation = true);
    });
  }

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
            _maybeTriggerDealAnimation(state.game.roundNumber);

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
                if (_showDealAnimation)
                  DealAnimationOverlay(
                    key: ValueKey('deal-${state.game.roundNumber}'),
                    humanCards: state.game.hands[kHumanSeat] ?? const [],
                    onComplete: () {
                      if (mounted) setState(() => _showDealAnimation = false);
                    },
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

    // Pulses gently while it's this seat's turn, so the eye is drawn to
    // who's acting without anything jarring — stays static otherwise.
    final label = PulseGlow(
      active: isTurn,
      child: Text(
        isTurn && uiState.isBotThinking ? '$name…' : name,
        style: TextStyle(
          color: isTurn ? const Color(0xFFC79A3D) : Colors.white70,
          fontWeight: isTurn ? FontWeight.w700 : FontWeight.w400,
          fontSize: 11.sp,
        ),
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
