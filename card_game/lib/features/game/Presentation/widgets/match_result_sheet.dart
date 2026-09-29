import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:card_game/Shared/widgets/primary_button.dart';
import '../bloc/game_ui_state.dart';

/// The final screen of a match: who won, the final score, and options to
/// play again or head back home.
class MatchResultSheet extends StatelessWidget {
  const MatchResultSheet({
    required this.uiState,
    required this.onPlayAgain,
    required this.onHome,
    super.key,
  });

  final GameUiState uiState;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final int? winner = uiState.game.winningTeam;
    final bool humanWon = winner == 0;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              humanWon ? Icons.emoji_events : Icons.sentiment_dissatisfied_outlined,
              color: AppColors.gold,
              size: 48.sp,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(humanWon ? 'You won!' : 'They won this one', style: AppTextStyles.h1(Colors.white)),
            SizedBox(height: AppSpacing.xs),
            Text(
              '${uiState.game.teamScores[0] ?? 0} – ${uiState.game.teamScores[1] ?? 0}',
              style: AppTextStyles.body(Colors.white70),
            ),
            SizedBox(height: AppSpacing.lg),
            PrimaryButton(label: 'Play again', onPressed: onPlayAgain),
            SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: onHome,
              child: Text('Back to home', style: AppTextStyles.body(Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
