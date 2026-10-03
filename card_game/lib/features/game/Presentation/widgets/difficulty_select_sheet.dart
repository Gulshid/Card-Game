import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bottom sheet the Home screen shows before starting a single-player
/// match, so the player picks a bot difficulty up front rather than
/// mid-game.
class DifficultySelectSheet extends StatelessWidget {
  const DifficultySelectSheet({super.key});

  static Future<AiDifficulty?> show(BuildContext context) {
    return showModalBottomSheet<AiDifficulty>(
      context: context,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (_) => const DifficultySelectSheet(),
    );
  }

  static const Map<AiDifficulty, String> _blurbs = {
    AiDifficulty.easy: 'Plays randomly. Good for learning the rules.',
    AiDifficulty.medium: 'Bids and plays sensibly. A fair match.',
    AiDifficulty.hard: 'Bids Nil when safe and tracks played cards.',
  };

  static const Map<AiDifficulty, IconData> _icons = {
    AiDifficulty.easy: Icons.signal_cellular_alt_1_bar_rounded,
    AiDifficulty.medium: Icons.signal_cellular_alt_2_bar_rounded,
    AiDifficulty.hard: Icons.signal_cellular_alt_rounded,
  };

  static const Map<AiDifficulty, Color> _tints = {
    AiDifficulty.easy: AppColors.success,
    AiDifficulty.medium: AppColors.gold,
    AiDifficulty.hard: AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2A50), Color(0xFF0C1429)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.35))),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm + 2, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              Text('DIFFICULTY', style: AppTextStyles.overline(AppColors.gold)),
              SizedBox(height: 4.h),
              Text('Choose your opponents', style: AppTextStyles.title(Colors.white)),
              SizedBox(height: AppSpacing.md),
              for (final difficulty in AiDifficulty.values)
                Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.sm + 2),
                  child: _DifficultyTile(
                    label: difficulty.label,
                    blurb: _blurbs[difficulty]!,
                    icon: _icons[difficulty]!,
                    tint: _tints[difficulty]!,
                    onTap: () => Navigator.of(context).pop(difficulty),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({
    required this.label,
    required this.blurb,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String label;
  final String blurb;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(AppRadius.lg);
    return Ink(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: br,
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        splashColor: tint.withValues(alpha: 0.18),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: tint.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: tint, size: 24.sp),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.h2(Colors.white)),
                    SizedBox(height: 2.h),
                    Text(blurb, style: AppTextStyles.caption(Colors.white60)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.gold, size: 26.sp),
            ],
          ),
        ),
      ),
    );
  }
}
