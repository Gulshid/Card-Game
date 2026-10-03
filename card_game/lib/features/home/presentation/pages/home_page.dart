import 'package:card_game/Shared/widgets/app_background.dart';
import 'package:card_game/Shared/widgets/app_surface.dart';
import 'package:card_game/Shared/widgets/fade_slide_in.dart';
import 'package:card_game/Shared/widgets/glass_icon_button.dart';
import 'package:card_game/Shared/widgets/primary_button.dart';
import 'package:card_game/Shared/widgets/section_header.dart';
import 'package:card_game/Shared/widgets/spade_mark.dart';
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
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routes/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Home: greeting + profile shortcut, a "resume" card when a match was
/// left unfinished, the two ways to play, and a live stats strip.
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
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeSlideIn(child: _Header(onSettings: () => context.pushNamed(AppRoute.settings))),
                SizedBox(height: AppSpacing.lg),
                BlocBuilder<ResumeMatchCubit, SavedMatch?>(
                  builder: (context, saved) {
                    if (saved == null) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: _ResumeCard(saved: saved, onResume: () => _resumeMatch(context)),
                      ),
                    );
                  },
                ),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: _HeroCard(onPlay: () => _startMatch(context)),
                ),
                SizedBox(height: AppSpacing.md),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 220),
                  child: _ModeTile(
                    icon: Icons.public_rounded,
                    title: 'Play Online',
                    subtitle: 'Quick match, or a private room with friends',
                    onTap: () => context.pushNamed(AppRoute.onlineLobby),
                  ),
                ),
                SizedBox(height: AppSpacing.lg + 4.h),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: const _StatsStrip(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Header ---------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profile) {
        return Row(
          children: [
            GestureDetector(
              onTap: () => context.pushNamed(AppRoute.profile),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.goldGradient),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppColors.navyDeep : AppColors.surfaceLight,
                  ),
                  child: ProfileAvatar(avatarId: profile.profile.avatarId, radius: 22),
                ),
              ),
            ),
            SizedBox(width: AppSpacing.md - 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WELCOME BACK', style: AppTextStyles.overline(muted)),
                  SizedBox(height: 2.h),
                  Text(
                    profile.profile.name,
                    style: AppTextStyles.h1(primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GlassIconButton(icon: Icons.person_outline_rounded, tooltip: 'Profile', onPressed: () => context.pushNamed(AppRoute.profile)),
            SizedBox(width: AppSpacing.sm),
            GlassIconButton(icon: Icons.settings_outlined, tooltip: 'Settings', onPressed: onSettings),
          ],
        );
      },
    );
  }
}

// ---- Hero / mode cards ------------------------------------------------------

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    // The hero is always a rich navy panel (it is the app's "table"
    // invitation), in both light and dark themes.
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: AppShadows.soft(true),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            // Oversized watermark spade.
            Positioned(
              right: -28.w,
              top: -18.h,
              child: Opacity(
                opacity: 0.10,
                child: Transform.rotate(angle: 0.25, child: SpadeMark(size: 190.w, gradient: AppColors.goldGradient)),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Text('SINGLE PLAYER', style: AppTextStyles.overline(AppColors.goldLight)),
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text('Take a seat at\nthe table', style: AppTextStyles.display(Colors.white)),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'A full game of Spades with a bot partner against two bot opponents. Pick your difficulty and deal in.',
                    style: AppTextStyles.body(Colors.white.withValues(alpha: 0.72)),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  PrimaryButton(label: 'Play vs Bots', icon: Icons.play_arrow_rounded, onPressed: onPlay),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AppSurface(
      onTap: onTap,
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blueSoft.withValues(alpha: 0.9), AppColors.blue],
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 26.sp),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h2(primary)),
                SizedBox(height: 2.h),
                Text(subtitle, style: AppTextStyles.caption(muted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.goldText(context), size: 26.sp),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.saved, required this.onResume});

  final SavedMatch saved;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final int us = saved.game.teamScores[0] ?? 0;
    final int them = saved.game.teamScores[1] ?? 0;

    return AppSurface(
      highlight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_toggle_off_rounded, size: 18.sp, color: AppColors.goldText(context)),
              SizedBox(width: AppSpacing.sm),
              Text('MATCH IN PROGRESS', style: AppTextStyles.overline(AppColors.goldText(context))),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$us', style: AppTextStyles.numeric(primary, size: 34)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('–', style: AppTextStyles.h1(muted)),
              ),
              Text('$them', style: AppTextStyles.numeric(primary, size: 34)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Round ${saved.game.roundNumber}', style: AppTextStyles.bodyStrong(primary)),
                  Text('${saved.difficulty.label} bots', style: AppTextStyles.caption(muted)),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Resume match', icon: Icons.play_circle_outline_rounded, onPressed: onResume),
        ],
      ),
    );
  }
}

// ---- Stats ------------------------------------------------------------------

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, profile) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Your stats'),
            SizedBox(height: AppSpacing.sm + 2),
            Row(
              children: [
                Expanded(
                  child: StatTile(icon: Icons.style_outlined, value: '${profile.stats.gamesPlayed}', label: 'Played'),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(icon: Icons.emoji_events_outlined, value: '${profile.stats.wins}', label: 'Wins'),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatTile(
                    icon: Icons.trending_up_rounded,
                    value: '${(profile.stats.winRate * 100).round()}%',
                    label: 'Win rate',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
