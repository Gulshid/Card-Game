import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:card_game/features/game/domain/models/game_phase.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/game_ui_state.dart';
import 'pulse_glow.dart';

/// Top bar over the table: both teams' running score and bag count,
/// the round number, and a pill saying whose turn it is. Score changes
/// count up rather than jump, so a round's outcome reads as a change
/// happening, not just a new number appearing.
class TurnScoreHud extends StatelessWidget {
  const TurnScoreHud({required this.uiState, super.key});

  final GameUiState uiState;

  @override
  Widget build(BuildContext context) {
    final GameState game = uiState.game;
    final bool myTurn = game.turn == kHumanSeat &&
        (game.phase == GamePhase.bidding || game.phase == GamePhase.playing);

    final String name = uiState.players[game.turn]?.name ?? game.turn.name;
    final String turnLabel;
    if (myTurn) {
      turnLabel = game.phase == GamePhase.bidding ? 'Your bid' : 'Your turn';
    } else if (game.phase == GamePhase.bidding || game.phase == GamePhase.playing) {
      turnLabel = uiState.isBotThinking ? '$name is thinking…' : "$name's turn";
    } else {
      turnLabel = 'Round over';
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _TeamScore(
            label: 'US',
            accent: AppColors.goldLight,
            score: game.teamScores[0] ?? 0,
            bags: game.teamBags[0] ?? 0,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ROUND ${game.roundNumber}', style: AppTextStyles.overline(Colors.white54)),
                SizedBox(height: 4.h),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey('$turnLabel-$myTurn'),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: myTurn ? AppColors.gold.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: myTurn ? AppShadows.goldGlow(0.25) : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PulseGlow(
                          active: myTurn,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: myTurn ? AppColors.gold : Colors.white38,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              turnLabel,
                              maxLines: 1,
                              style: AppTextStyles.bodyStrong(myTurn ? AppColors.goldLight : Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _TeamScore(
            label: 'THEM',
            accent: AppColors.blueSoft,
            score: game.teamScores[1] ?? 0,
            bags: game.teamBags[1] ?? 0,
            alignEnd: true,
          ),
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({
    required this.label,
    required this.accent,
    required this.score,
    required this.bags,
    this.alignEnd = false,
  });

  final String label;
  final Color accent;
  final int score;
  final int bags;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 74.w),
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.overline(accent)),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: score, end: score),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, _) => Text('$value', style: AppTextStyles.numeric(Colors.white, size: 22)),
          ),
          Text('$bags bags', style: AppTextStyles.caption(Colors.white54).copyWith(fontSize: 10.sp)),
        ],
      ),
    );
  }
}
