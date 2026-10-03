import 'dart:ui' show ImageFilter;

import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../bloc/game_ui_state.dart';

/// Shown between rounds: how many points each team just scored, and the
/// running totals, before dealing the next hand. The whole card
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
    duration: const Duration(milliseconds: 300),
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
    final int usPoints = widget.uiState.roundPointsFor(0);
    final int themPoints = widget.uiState.roundPointsFor(1);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: FadeTransition(
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
                  colors: [Color(0xFF1A2A50), Color(0xFF0E1830)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
                boxShadow: AppShadows.soft(true),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ROUND ${widget.uiState.game.roundNumber}', style: AppTextStyles.overline(AppColors.gold)),
                  SizedBox(height: 4.h),
                  Text('Round complete', style: AppTextStyles.title(Colors.white)),
                  SizedBox(height: AppSpacing.lg),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _RoundColumn(
                            label: 'US',
                            accent: AppColors.goldLight,
                            points: usPoints,
                            total: widget.uiState.game.teamScores[0] ?? 0,
                            bags: widget.uiState.game.teamBags[0] ?? 0,
                            leading: usPoints >= themPoints,
                          ),
                        ),
                        VerticalDivider(color: Colors.white.withValues(alpha: 0.10), width: AppSpacing.md),
                        Expanded(
                          child: _RoundColumn(
                            label: 'THEM',
                            accent: AppColors.blueSoft,
                            points: themPoints,
                            total: widget.uiState.game.teamScores[1] ?? 0,
                            bags: widget.uiState.game.teamBags[1] ?? 0,
                            leading: themPoints > usPoints,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: 'Next round',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: widget.onContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({
    required this.label,
    required this.accent,
    required this.points,
    required this.total,
    required this.bags,
    required this.leading,
  });

  final String label;
  final Color accent;
  final int points;
  final int total;
  final int bags;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final bool positive = points >= 0;
    return Column(
      children: [
        Text(label, style: AppTextStyles.overline(accent)),
        SizedBox(height: 8.h),
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: points),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (context, value, _) => Text(
            '${positive ? '+' : ''}$value',
            style: AppTextStyles.numeric(positive ? AppColors.success : AppColors.danger, size: 34),
          ),
        ),
        SizedBox(height: 8.h),
        Text('Total', style: AppTextStyles.caption(Colors.white38)),
        Text('$total', style: AppTextStyles.numeric(leading ? Colors.white : Colors.white70, size: 18)),
        SizedBox(height: 4.h),
        Text('$bags bags', style: AppTextStyles.caption(Colors.white38)),
      ],
    );
  }
}
