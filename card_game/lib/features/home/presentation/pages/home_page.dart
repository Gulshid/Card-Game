import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Home shell. This proves the Phase 01 skeleton (routing, theme, DI)
/// works end-to-end. The full home screen — daily reward banner,
/// currency, quick-match shortcuts — is a Phase 05 concern once the
/// engine exists to actually start a match.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
              'The rules engine and table screen land in Phases 03–05. '
              'For now this confirms navigation, theming, and dependency '
              'injection are wired correctly.',
              style: AppTextStyles.body(Theme.of(context).colorScheme.onSurface),
            ),
            SizedBox(height: AppSpacing.xl),
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
