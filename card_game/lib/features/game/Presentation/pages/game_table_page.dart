import 'package:card_game/core/audio/audio_service.dart';
import 'package:card_game/core/di/injection_container.dart';
import 'package:card_game/core/services/haptics_service.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
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
import '../bloc/table_cubit.dart';
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
///
/// Phase 10: the table itself ([GameTableView]) now depends only on the
/// [TableCubit] contract, so the same screen also renders online matches
/// (see `OnlineGameTablePage`). This page remains the offline-vs-bots entry.
class GameTablePage extends StatelessWidget {
  const GameTablePage({required this.difficulty, this.resume, super.key});

  final AiDifficulty difficulty;
  final SavedMatch? resume;

  @override
  Widget build(BuildContext context) {
    final ProfileCubit profile = context.read<ProfileCubit>();
    return BlocProvider<TableCubit>(
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
          child: GameTableView(resumed: resume != null),
        ),
      ),
    );
  }
}

/// The felt table, driven by whichever [TableCubit] is in scope.
class GameTableView extends StatefulWidget {
  const GameTableView({
    required this.resumed,
    super.key,
    this.onPlayAgain,
    this.onHome,
    this.playAgainLabel = 'Play again',
    this.homeLabel = 'Back to home',
    this.overlay,
  });

  /// A resumed match opens mid-round, so the deal flourish is skipped for
  /// the round it resumes into (later rounds deal normally).
  final bool resumed;

  /// Overrides for the match-result buttons (online: leave the table).
  /// When null: "Play again" restarts the cubit, "Back to home" pops.
  final VoidCallback? onPlayAgain;
  final VoidCallback? onHome;
  final String playAgainLabel;
  final String homeLabel;

  /// Extra widget stacked above the table (online status banner, emotes).
  final Widget? overlay;

  @override
  State<GameTableView> createState() => _GameTableViewState();
}

class _GameTableViewState extends State<GameTableView> {
  int? _lastDealtRound;
  bool _showDealAnimation = false;

  @override
  void initState() {
    super.initState();
    if (widget.resumed) {
      _lastDealtRound = context.read<TableCubit>().state.game.roundNumber;
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
      backgroundColor: AppColors.feltDeep,
      body: Stack(
        children: [
          const Positioned.fill(child: _FeltBackground()),
          SafeArea(
            child: BlocConsumer<TableCubit, GameUiState>(
              listenWhen: (prev, curr) => curr.hint != null && curr.hintNonce != prev.hintNonce,
              listener: (context, state) {
                // Floats above the player's hand instead of covering it.
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(state.hint!, textAlign: TextAlign.center),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.fromLTRB(28.w, 0, 28.w, 170.h),
                    ),
                  );
              },
              builder: (context, state) {
                final cubit = context.read<TableCubit>();
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
                        _SelfBar(uiState: state),
                        PlayerHandFan(
                          cards: state.game.hands[kHumanSeat] ?? const [],
                          enabled: state.canHumanAct && state.game.phase == GamePhase.playing,
                          isLegal: (card) => SpadesRulesEngine.isValidMove(
                            state.game,
                            PlayCardMove(seat: kHumanSeat, card: card),
                          ),
                          onCardTap: cubit.playCard,
                        ),
                        SizedBox(height: 4.h),
                      ],
                    ),
                    if (state.canHumanAct && state.game.phase == GamePhase.bidding)
                      BidOverlay(onBid: cubit.submitBid),
                    if (state.showRoundSummary)
                      RoundSummarySheet(uiState: state, onContinue: cubit.nextRound),
                    if (state.showMatchResult)
                      MatchResultSheet(
                        uiState: state,
                        onPlayAgain: widget.onPlayAgain ?? cubit.restart,
                        onHome: widget.onHome ?? () => context.pop(),
                        playAgainLabel: widget.playAgainLabel,
                        homeLabel: widget.homeLabel,
                      ),
                    if (_showDealAnimation)
                      DealAnimationOverlay(
                        key: ValueKey('deal-${state.game.roundNumber}'),
                        humanCards: state.game.hands[kHumanSeat] ?? const [],
                        onComplete: () {
                          if (mounted) setState(() => _showDealAnimation = false);
                        },
                      ),
                    if (widget.overlay != null) widget.overlay!,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Felt ---------------------------------------------------------------

/// Emerald baize: a lit radial gradient, a faint woven texture and a
/// dark vignette toward the edges. Painted once (RepaintBoundary).
class _FeltBackground extends StatelessWidget {
  const _FeltBackground();

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.feltGradient)),
          CustomPaint(painter: _FeltWeavePainter()),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.15,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.50)],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeltWeavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.white.withValues(alpha: 0.018)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 6.h,
          child: _OpponentSlot(seat: Seat.north, uiState: uiState, vertical: false),
        ),
        Positioned(
          right: 4.w,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _OpponentSlot(seat: Seat.east, uiState: uiState, vertical: true),
          ),
        ),
        Positioned(
          left: 4.w,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _OpponentSlot(seat: Seat.west, uiState: uiState, vertical: true),
          ),
        ),
        TrickArea(trick: uiState.displayTrick, winner: uiState.displayWinner),
      ],
    );
  }
}

/// An opponent's name plate (team-coloured initial, name, bid progress)
/// with their face-down fan beside/below it. The plate glows and pulses
/// while it is that seat's turn.
class _OpponentSlot extends StatelessWidget {
  const _OpponentSlot({required this.seat, required this.uiState, required this.vertical});

  final Seat seat;
  final GameUiState uiState;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final game = uiState.game;
    final String name = uiState.players[seat]?.name ?? seat.name;
    final bool live = game.phase == GamePhase.bidding || game.phase == GamePhase.playing;
    final bool isTurn = live && game.turn == seat;
    final bool thinking = isTurn && uiState.isBotThinking;
    final int handCount = game.hands[seat]?.length ?? 0;

    final int? bid = game.bids[seat];
    final int won = game.tricksWonBySeat[seat] ?? 0;
    final String? status = bid == null
        ? (game.phase == GamePhase.bidding && isTurn ? 'Bidding…' : null)
        : (bid == 0 ? 'Nil · won $won' : 'Won $won/$bid');

    final bool usTeam = seat.team == 0;
    final String initial = name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase();

    final Widget plate = PulseGlow(
      active: isTurn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: BoxConstraints(maxWidth: 98.w),
        padding: EdgeInsets.fromLTRB(5.w, 4.h, 11.w, 4.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isTurn ? AppColors.gold : Colors.white.withValues(alpha: 0.12),
            width: isTurn ? 1.4 : 1,
          ),
          boxShadow: isTurn ? AppShadows.goldGlow(0.30) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12.r,
              backgroundColor: usTeam ? AppColors.gold : AppColors.blue,
              child: Text(
                initial,
                style: AppTextStyles.caption(usTeam ? AppColors.navyDeep : Colors.white)
                    .copyWith(fontWeight: FontWeight.w800, fontSize: 11.sp),
              ),
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thinking ? '$name…' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption(isTurn ? AppColors.goldLight : Colors.white)
                        .copyWith(fontWeight: FontWeight.w800, fontSize: 11.sp),
                  ),
                  if (status != null)
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption(Colors.white60).copyWith(fontSize: 9.5.sp),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final Widget fan = OpponentHandView(
      cardCount: handCount,
      vertical: vertical,
      cardWidth: 26,
      isThinking: thinking,
    );

    return Column(mainAxisSize: MainAxisSize.min, children: [plate, SizedBox(height: 6.h), fan]);
  }
}

/// A slim status line just above the player's hand: their own bid and
/// tricks won, and whether spades have been broken.
class _SelfBar extends StatelessWidget {
  const _SelfBar({required this.uiState});

  final GameUiState uiState;

  @override
  Widget build(BuildContext context) {
    final game = uiState.game;
    final bool live = game.phase == GamePhase.bidding || game.phase == GamePhase.playing;
    final int? bid = game.bids[kHumanSeat];
    final int won = game.tricksWonBySeat[kHumanSeat] ?? 0;

    Widget pill(String text, {Color? accent}) => Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: (accent ?? Colors.white).withValues(alpha: accent == null ? 0.12 : 0.5)),
          ),
          child: Text(
            text,
            style: AppTextStyles.caption(accent ?? Colors.white70).copyWith(fontWeight: FontWeight.w700),
          ),
        );

    return SizedBox(
      height: 28.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (live && bid != null) pill(bid == 0 ? 'Your bid: Nil · won $won' : 'Your bid: $bid · won $won/$bid'),
          if (live && game.spadesBroken) pill('♠ broken', accent: AppColors.goldLight),
        ],
      ),
    );
  }
}
