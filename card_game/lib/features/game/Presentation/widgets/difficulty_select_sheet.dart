import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:card_game/features/game/domain/ai/ai_difficulty.dart';
import 'package:flutter/material.dart';

/// Bottom sheet the Home screen shows before starting a single-player
/// match, so the player picks a bot difficulty up front rather than
/// mid-game.
class DifficultySelectSheet extends StatelessWidget {
  const DifficultySelectSheet({super.key});

  static Future<AiDifficulty?> show(BuildContext context) {
    return showModalBottomSheet<AiDifficulty>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const DifficultySelectSheet(),
    );
  }

  static const Map<AiDifficulty, String> _blurbs = {
    AiDifficulty.easy: 'Plays randomly. Good for learning the rules.',
    AiDifficulty.medium: 'Bids and plays sensibly. A fair match.',
    AiDifficulty.hard: 'Bids Nil when safe and tracks played cards.',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose your opponents', style: AppTextStyles.h2(Colors.white)),
            SizedBox(height: AppSpacing.md),
            for (final difficulty in AiDifficulty.values)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  onTap: () => Navigator.of(context).pop(difficulty),
                  tileColor: AppColors.navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  title: Text(difficulty.label, style: AppTextStyles.bodyStrong(Colors.white)),
                  subtitle: Text(_blurbs[difficulty]!, style: AppTextStyles.caption(Colors.white60)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.gold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
