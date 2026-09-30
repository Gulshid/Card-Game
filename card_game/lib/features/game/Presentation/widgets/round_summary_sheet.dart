import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/game_ui_state.dart';

/// Shown between rounds: how many points each team just scored, and the
/// running bag count, before dealing the next hand. The whole card
/// scales/fades in on mount, and each team's point delta counts up from
/// 0 rather than just appearing — small touches that make the summary
/// feel like a result being revealed, not a static label.
class RoundSummarySheet extends StatefulWidget {
  const RoundSummarySheet({required this.uiState, required this.onContinue, super.key});

  final GameUiState uiState;
  final VoidCallback onContinue;

  @override
  State<RoundSummarySheet> createState() => _RoundSummarySheetState();
}

class _RoundSummarySheetState extends State<RoundSummarySheet> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
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
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
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
                Text('Round ${widget.uiState.game.roundNumber} complete', style: AppTextStyles.h2(Colors.white)),
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _RoundRow(
                        label: 'Us',
                        points: widget.uiState.roundPointsFor(0),
                        total: widget.uiState.game.teamScores[0] ?? 0,
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _RoundRow(
                        label: 'Them',
                        points: widget.uiState.roundPointsFor(1),
                        total: widget.uiState.game.teamScores[1] ?? 0,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),
                PrimaryButton(label: 'Next round', onPressed: widget.onContinue),
              ],
            ),
          ),
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
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: points),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, value, _) => Text(
            '${positive ? '+' : ''}$value',
            style: AppTextStyles.h1(positive ? const Color(0xFF1E8E5A) : const Color(0xFFD85A30)),
          ),
        ),
        Text('total $total', style: AppTextStyles.caption(Colors.white38)),
      ],
    );
  }
}
