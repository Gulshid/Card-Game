import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:card_game/Shared/widgets/primary_button.dart';
import '../bloc/game_ui_state.dart';

/// Shown between rounds: how many points each team just scored, and the
/// running bag count, before dealing the next hand.
class RoundSummarySheet extends StatelessWidget {
  const RoundSummarySheet({required this.uiState, required this.onContinue, super.key});

  final GameUiState uiState;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Round ${uiState.game.roundNumber} complete', style: AppTextStyles.h2(Colors.white)),
            SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: _RoundRow(label: 'Us', points: uiState.roundPointsFor(0), total: uiState.game.teamScores[0] ?? 0)),
                SizedBox(width: AppSpacing.md),
                Expanded(child: _RoundRow(label: 'Them', points: uiState.roundPointsFor(1), total: uiState.game.teamScores[1] ?? 0)),
              ],
            ),
            SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Next round', onPressed: onContinue),
          ],
        ),
      ),
    );
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({required this.label, required this.points, required this.total});

  final String label;
  final int points;
  final int total;

  @override
  Widget build(BuildContext context) {
    final bool positive = points >= 0;
    return Column(
      children: [
        Text(label, style: AppTextStyles.caption(Colors.white60)),
        SizedBox(height: 4.h),
        Text(
          '${positive ? '+' : ''}$points',
          style: AppTextStyles.h1(positive ? const Color(0xFF1E8E5A) : const Color(0xFFD85A30)),
        ),
        Text('total $total', style: AppTextStyles.caption(Colors.white38)),
      ],
    );
  }
}
