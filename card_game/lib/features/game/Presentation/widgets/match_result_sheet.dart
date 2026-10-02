import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../Profile/domain/models/achievements.dart';
import 'confetti_burst.dart';
import '../bloc/game_ui_state.dart';

/// The final screen of a match: who won, the final score, and options to
/// play again or head back home. Entrance is a quick scale + fade, and
/// a win adds a confetti burst behind the card — both are one-shot,
/// driven by an `AnimationController` that starts the moment this
/// widget mounts (i.e. the moment the match ends).
class MatchResultSheet extends StatefulWidget {
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
  State<MatchResultSheet> createState() => _MatchResultSheetState();
}

class _MatchResultSheetState extends State<MatchResultSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();
  late final Animation<double> _scale = CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack);
  late final Animation<double> _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int? winner = widget.uiState.game.winningTeam;
    final bool humanWon = winner == 0;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (humanWon) const Positioned.fill(child: ConfettiBurst()),
          FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
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
                      '${widget.uiState.game.teamScores[0] ?? 0} – ${widget.uiState.game.teamScores[1] ?? 0}',
                      style: AppTextStyles.body(Colors.white70),
                    ),
                    if (widget.uiState.newlyUnlocked.isNotEmpty) ...[
                      SizedBox(height: AppSpacing.md),
                      for (final Achievement a in widget.uiState.newlyUnlocked)
                        Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_open_rounded, color: AppColors.gold, size: 16.sp),
                              SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  'Unlocked: ${a.title} — ${a.reward.label} card back',
                                  style: AppTextStyles.caption(AppColors.goldLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    SizedBox(height: AppSpacing.lg),
                    PrimaryButton(label: 'Play again', onPressed: widget.onPlayAgain),
                    SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: widget.onHome,
                      child: Text('Back to home', style: AppTextStyles.body(Colors.white70)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
