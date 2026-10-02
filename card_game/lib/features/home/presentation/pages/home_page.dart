import 'package:card_game/Shared/widgets/app_surface.dart';
import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/Shared/widgets/stat_tile.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/features/game/Presentation/widgets/difficulty_select_sheet.dart';
import 'package:card_game/features/game/domain/models/saved_match.dart';
import 'package:card_game/features/home/bloc/resume_match_cubit.dart';
import 'package:card_game/features/Profile/bloc/profile_cubit.dart';
import 'package:card_game/features/Profile/bloc/profile_state.dart';
import 'package:card_game/features/Profile/presentation/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Home. Phase 09 makes it personal and persistent: the player's avatar
/// and name, a live stats strip, a profile shortcut, and — when a match
/// was left unfinished — a "Resume" card that puts it back on the table.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _startMatch(BuildContext context) async {
    final ResumeMatchCubit resume = context.read<ResumeMatchCubit>();

    // Starting fresh would overwrite the suspended match on the first
    // move, so make that a deliberate choice rather than a surprise.
    if (resume.state != null) {
      final bool proceed = await _confirmAbandon(context);
      if (!proceed || !context.mounted) return;
      await resume.abandon();
      if (!context.mounted) return;
    }

    final difficulty = await DifficultySelectSheet.show(context);
    if (difficulty == null || !context.mounted) return;
    await context.pushNamed(AppRoute.table, extra: TableRouteArgs(difficulty: difficulty));
    await resume.refresh();
  }

  Future<void> _resumeMatch(BuildContext context) async {
    final ResumeMatchCubit resume = context.read<ResumeMatchCubit>();
    // Re-read at tap time: the cached copy may be one move behind if the
    // last save was still flushing when the table closed.
    await resume.refresh();
    final SavedMatch? saved = resume.state;
    if (saved == null || !context.mounted) return;
    await context.pushNamed(AppRoute.table, extra: TableRouteArgs(resume: saved));
    await resume.refresh();
  }

  Future<bool> _confirmAbandon(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new match?'),
        content: const Text('You have a match in progress. Starting a new one will discard it.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep it')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final Color onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spades Royale'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.pushNamed(AppRoute.profile),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(AppRoute.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, profile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pushNamed(AppRoute.profile),
                          child: ProfileAvatar(avatarId: profile.profile.avatarId, radius: 22),
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Welcome back, ${profile.profile.name}',
                            style: AppTextStyles.h1(AppColors.gold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(child: StatTile(value: '${profile.stats.gamesPlayed}', label: 'Played')),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(child: StatTile(value: '${profile.stats.wins}', label: 'Wins')),
                        SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: StatTile(value: '${(profile.stats.winRate * 100).round()}%', label: 'Win rate'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: AppSpacing.lg),
            BlocBuilder<ResumeMatchCubit, SavedMatch?>(
              builder: (context, saved) {
                if (saved == null) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.lg),
                  child: AppSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Match in progress', style: AppTextStyles.h2(onSurface)),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'Round ${saved.game.roundNumber}  ·  Us ${saved.game.teamScores[0] ?? 0} – '
                          '${saved.game.teamScores[1] ?? 0} Them  ·  ${saved.difficulty.label}',
                          style: AppTextStyles.body(onSurface.withValues(alpha: 0.7)),
                        ),
                        SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Resume match',
                          icon: Icons.play_circle_outline,
                          onPressed: () => _resumeMatch(context),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            Text(
              'Play a full game of Spades against three bots — pick a '
              'difficulty and jump straight to the table.',
              style: AppTextStyles.body(onSurface),
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
