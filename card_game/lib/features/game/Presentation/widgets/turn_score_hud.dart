import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:card_game/features/game/domain/models/game_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/game_ui_state.dart';

/// Top bar over the table: round number, both teams' running score and
/// bag count, and whose turn it is. Score changes count up rather than
/// jump, so a round's outcome reads as a change happening, not just a
/// new number appearing.
class TurnScoreHud extends StatelessWidget {
  const TurnScoreHud({required this.uiState, super.key});

  final GameUiState uiState;

  @override
  Widget build(BuildContext context) {
    final GameState game = uiState.game;
    final String turnLabel = uiState.players[game.turn]?.name ?? game.turn.name;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      child: Row(
        children: [
          _TeamScore(label: 'Us', score: game.teamScores[0] ?? 0, bags: game.teamBags[0] ?? 0),
          const Spacer(),
          Column(
            children: [
              Text('Round ${game.roundNumber}', style: AppTextStyles.caption(Colors.white70)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  uiState.isBotThinking ? '$turnLabel is thinking…' : "$turnLabel's turn",
                  key: ValueKey('$turnLabel-${uiState.isBotThinking}'),
                  style: AppTextStyles.bodyStrong(Colors.white),
                ),
              ),
            ],
          ),
          const Spacer(),
          _TeamScore(label: 'Them', score: game.teamScores[1] ?? 0, bags: game.teamBags[1] ?? 0, alignEnd: true),
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({required this.label, required this.score, required this.bags, this.alignEnd = false});

  final String label;
  final int score;
  final int bags;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption(Colors.white60)),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: score, end: score),
          duration: const Duration(milliseconds: 500),
          builder: (context, value, _) => Text('$value', style: AppTextStyles.h2(const Color(0xFFC79A3D))),
        ),
        Text('$bags bags', style: AppTextStyles.caption(Colors.white38)),
      ],
    );
  }
}
