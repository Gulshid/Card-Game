import 'dart:ui' show ImageFilter;

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
    this.playAgainLabel = 'Play again',
    this.homeLabel = 'Back to home',
  });

  final GameUiState uiState;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  /// Online matches relabel these ("Back to lobby").
  final String playAgainLabel;
  final String homeLabel;

  @override
  State<MatchResultSheet> createState() => _MatchResultSheetState();
}

class _MatchResultSheetState extends State<MatchResultSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
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
    final int us = widget.uiState.game.teamScores[0] ?? 0;
    final int them = widget.uiState.game.teamScores[1] ?? 0;
    final Color accent = humanWon ? AppColors.gold : AppColors.blueSoft;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
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
                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                  padding: EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1C2D55), Color(0xFF0D172E)],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.3),
                    boxShadow: [
                      BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 2),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84.w,
                        height: 84.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: humanWon ? AppColors.goldGradient : null,
                          color: humanWon ? null : Colors.white.withValues(alpha: 0.08),
                          boxShadow: humanWon ? AppShadows.goldGlow(0.45) : null,
                        ),
                        child: Icon(
                          humanWon ? Icons.emoji_events_rounded : Icons.flag_rounded,
                          color: humanWon ? AppColors.navyDeep : Colors.white70,
                          size: 42.sp,
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(humanWon ? 'VICTORY' : 'DEFEAT', style: AppTextStyles.overline(accent)),
                      SizedBox(height: 4.h),
                      Text(
                        humanWon ? 'You won!' : 'They won this one',
                        style: AppTextStyles.display(Colors.white).copyWith(fontSize: 26.sp),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _ScoreBlock(label: 'US', score: us, accent: AppColors.goldLight, strong: humanWon),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                            child: Text('–', style: AppTextStyles.h1(Colors.white38)),
                          ),
                          _ScoreBlock(label: 'THEM', score: them, accent: AppColors.blueSoft, strong: !humanWon),
                        ],
                      ),
                      if (widget.uiState.newlyUnlocked.isNotEmpty) ...[
                        SizedBox(height: AppSpacing.md),
                        for (final Achievement a in widget.uiState.newlyUnlocked)
                          Container(
                            margin: EdgeInsets.only(top: AppSpacing.xs + 2),
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_open_rounded, color: AppColors.gold, size: 16.sp),
                                SizedBox(width: AppSpacing.sm),
                                Flexible(
                                  child: Text(
                                    'Unlocked: ${a.title} — ${a.reward.label} card back',
                                    style: AppTextStyles.caption(AppColors.goldLight).copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                      SizedBox(height: AppSpacing.lg),
                      PrimaryButton(label: widget.playAgainLabel, icon: Icons.replay_rounded, onPressed: widget.onPlayAgain),
                      SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: widget.onHome,
                        child: Text(widget.homeLabel, style: AppTextStyles.bodyStrong(Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.label, required this.score, required this.accent, required this.strong});

  final String label;
  final int score;
  final Color accent;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.overline(accent)),
        SizedBox(height: 4.h),
        Text(
          '$score',
          style: AppTextStyles.numeric(strong ? Colors.white : Colors.white54, size: strong ? 38 : 30),
        ),
      ],
    );
  }
}
