import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/features/game/Presentation/widgets/difficulty_select_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Home shell. Phase 05 adds the one thing this screen actually needs
/// to be useful: a way into a match. The daily-reward banner, currency,
/// and other decoration from the early mockups are still deferred —
/// they depend on persistence (Phase 09), not on the engine.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _startMatch(BuildContext context) async {
    final difficulty = await DifficultySelectSheet.show(context);
    if (difficulty == null || !context.mounted) return;
    context.pushNamed(AppRoute.table, extra: difficulty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spades Royale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(AppRoute.settings),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome back', style: AppTextStyles.h1(AppColors.gold)),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Play a full game of Spades against three bots — pick a '
              'difficulty and jump straight to the table.',
              style: AppTextStyles.body(Theme.of(context).colorScheme.onSurface),
            ),
            SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Play vs Bots',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _startMatch(context),
            ),
            SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: 'View UI kit',
              icon: Icons.palette_outlined,
              onPressed: () => context.pushNamed(AppRoute.uiKit),
            ),
          ],
        ),
      ),
    );
  }
}
