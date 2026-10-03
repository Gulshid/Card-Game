import 'package:card_game/Shared/widgets/app_background.dart';
import 'package:card_game/Shared/widgets/app_surface.dart';
import 'package:card_game/Shared/widgets/fade_slide_in.dart';
import 'package:card_game/Shared/widgets/loading_indicator.dart';
import 'package:card_game/Shared/widgets/section_header.dart';
import 'package:card_game/Shared/widgets/stat_tile.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:card_game/features/Profile/bloc/profile_cubit.dart';
import 'package:card_game/features/Profile/bloc/profile_state.dart';
import 'package:card_game/features/Profile/domain/models/achievements.dart';
import 'package:card_game/features/Profile/domain/models/match_record.dart';
import 'package:card_game/features/Profile/domain/models/player_profile.dart';
import 'package:card_game/features/Profile/presentation/cosmetic_theme.dart';
import 'package:card_game/features/Profile/presentation/widgets/card_back_scope.dart';
import 'package:card_game/features/Profile/presentation/widgets/profile_avatar.dart';
import 'package:card_game/features/game/Presentation/widgets/playing_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Avatar + name, lifetime stats, achievements, card-back picker and
/// recent matches — all bound to [ProfileCubit].
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Profile'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (_) => _confirmReset(context),
              itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Reset progress'))],
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              if (!state.isLoaded) return const Center(child: AppLoadingIndicator());
              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                children: [
                  FadeSlideIn(child: _Header(profile: state.profile, state: state)),
                  SizedBox(height: AppSpacing.lg),
                  FadeSlideIn(delay: const Duration(milliseconds: 80), child: _StatsPanel(state: state)),
                  SizedBox(height: AppSpacing.lg + 4.h),
                  SectionHeader(
                    'Achievements',
                    trailing: _CountChip(text: '${state.unlocked.length}/${Achievement.values.length}'),
                  ),
                  SizedBox(height: AppSpacing.sm + 2),
                  for (final Achievement a in Achievement.values) _AchievementRow(achievement: a, state: state),
                  SizedBox(height: AppSpacing.lg),
                  const SectionHeader('Card backs'),
                  SizedBox(height: AppSpacing.sm + 2),
                  _CardBackPicker(state: state),
                  SizedBox(height: AppSpacing.lg + 4.h),
                  const SectionHeader('Recent matches'),
                  SizedBox(height: AppSpacing.sm + 2),
                  _History(history: state.history),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ProfileCubit cubit = context.read<ProfileCubit>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This clears your stats, match history, achievements and unlocked card backs. '
          'Your name and avatar are kept. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.resetProgress();
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(text, style: AppTextStyles.caption(AppColors.goldText(context)).copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

// ---- Header -------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.state});

  final PlayerProfile profile;
  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AppSurface(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickAvatar(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.goldGradient),
                  child: Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.navyDeep : Colors.white,
                    ),
                    child: ProfileAvatar(avatarId: profile.avatarId, radius: 36),
                  ),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.goldGradient,
                      border: Border.all(color: isDark ? AppColors.navyDeep : Colors.white, width: 2),
                    ),
                    child: Icon(Icons.edit_rounded, size: 12.sp, color: AppColors.navyDeep),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.name, style: AppTextStyles.h1(primary), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4.h),
                Text(
                  '${state.unlocked.length} of ${Achievement.values.length} achievements',
                  style: AppTextStyles.caption(muted),
                ),
                SizedBox(height: 6.h),
                GestureDetector(
                  onTap: () => _editName(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 14.sp, color: AppColors.goldText(context)),
                      SizedBox(width: 4.w),
                      Text(
                        'Edit name',
                        style: AppTextStyles.caption(AppColors.goldText(context)).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final ProfileCubit cubit = context.read<ProfileCubit>();
    final String? result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: profile.name),
    );
    if (result != null) await cubit.updateName(result);
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final ProfileCubit cubit = context.read<ProfileCubit>();
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your avatar', style: AppTextStyles.title(Theme.of(ctx).colorScheme.onSurface)),
              SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (int i = 0; i < kAvatars.length; i++)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => Navigator.of(ctx).pop(i),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == profile.avatarId ? AppColors.gold : Colors.transparent,
                            width: 2.4,
                          ),
                        ),
                        child: ProfileAvatar(avatarId: i, radius: 26),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) await cubit.updateAvatar(picked);
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: PlayerProfile.maxNameLength,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: const Text('Save')),
      ],
    );
  }
}

// ---- Stats ----------------------------------------------------------------

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final s = state.stats;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final double rate = s.winRate.clamp(0.0, 1.0);

    Widget line(String label, String value) => Padding(
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppTextStyles.body(muted))),
              Text(value, style: AppTextStyles.numeric(primary, size: 16)),
            ],
          ),
        );

    return Column(
      children: [
        AppSurface(
          padding: EdgeInsets.all(AppSpacing.md + 2),
          child: Row(
            children: [
              // Win-rate ring.
              SizedBox(
                width: 96.w,
                height: 96.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: rate,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        color: AppColors.gold,
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.07),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${(rate * 100).round()}%', style: AppTextStyles.numeric(primary, size: 22)),
                        Text('WIN RATE', style: AppTextStyles.overline(muted).copyWith(fontSize: 8.5.sp)),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  children: [
                    line('Matches played', '${s.gamesPlayed}'),
                    const Divider(),
                    line('Wins', '${s.wins}'),
                    const Divider(),
                    line('Losses', '${s.losses}'),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: StatTile(icon: Icons.local_fire_department_outlined, value: '${s.currentStreak}', label: 'Streak'),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: StatTile(icon: Icons.military_tech_outlined, value: '${s.bestStreak}', label: 'Best streak'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- Achievements ---------------------------------------------------------

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.state});

  final Achievement achievement;
  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = state.unlocked.contains(achievement);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color dim = (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight).withValues(alpha: unlocked ? 1 : 0.7);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppSurface(
        highlight: unlocked,
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md - 2),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: unlocked ? AppColors.goldGradient : null,
                color: unlocked ? null : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06)),
              ),
              child: Icon(
                unlocked ? achievement.icon : Icons.lock_outline_rounded,
                size: 22.sp,
                color: unlocked ? AppColors.navyDeep : dim,
              ),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(achievement.title, style: AppTextStyles.bodyStrong(unlocked ? primary : dim)),
                  SizedBox(height: 2.h),
                  Text(achievement.description, style: AppTextStyles.caption(dim)),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('REWARD', style: AppTextStyles.overline(dim).copyWith(fontSize: 8.5.sp)),
                SizedBox(height: 2.h),
                Text(
                  '${achievement.reward.label} back',
                  style: AppTextStyles.caption(unlocked ? AppColors.goldText(context) : dim).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Card backs -------------------------------------------------------------

class _CardBackPicker extends StatelessWidget {
  const _CardBackPicker({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.md,
        children: [
          for (final CardBackStyle style in CardBackStyle.values)
            _CardBackChoice(
              style: style,
              selected: state.profile.cardBack == style,
              unlocked: state.isCardBackUnlocked(style),
            ),
        ],
      ),
    );
  }
}

class _CardBackChoice extends StatelessWidget {
  const _CardBackChoice({required this.style, required this.selected, required this.unlocked});

  final CardBackStyle style;
  final bool selected;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () {
        if (unlocked) {
          context.read<ProfileCubit>().selectCardBack(style);
        } else {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Unlock by earning "${style.unlockedBy!.title}": ${style.unlockedBy!.description}')),
            );
        }
      },
      child: SizedBox(
        width: 64.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: selected ? AppColors.gold.withValues(alpha: 0.14) : Colors.transparent,
                border: Border.all(color: selected ? AppColors.gold : Colors.transparent, width: 1.5),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: unlocked ? 1 : 0.35,
                    child: CardBackScope(
                      style: style,
                      child: const PlayingCardView(card: null, faceDown: true, width: 44),
                    ),
                  ),
                  if (!unlocked) Icon(Icons.lock_rounded, color: Colors.white, size: 20.sp),
                  if (selected)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
                        child: Icon(Icons.check_rounded, size: 12.sp, color: AppColors.navyDeep),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              style.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption(selected ? AppColors.goldText(context) : muted).copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- History ----------------------------------------------------------------

class _History extends StatelessWidget {
  const _History({required this.history});

  final List<MatchRecord> history;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    if (history.isEmpty) {
      return AppSurface(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(Icons.style_outlined, size: 30.sp, color: muted.withValues(alpha: 0.6)),
            SizedBox(height: AppSpacing.sm),
            Text(
              'No matches yet — finish a game and it will show up here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body(muted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final MatchRecord r in history)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppSurface(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md - 2),
              child: Row(
                children: [
                  Container(
                    width: 52.w,
                    padding: EdgeInsets.symmetric(vertical: 5.h),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (r.won ? AppColors.success : AppColors.danger).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      r.won ? 'WIN' : 'LOSS',
                      style: AppTextStyles.overline(r.won ? AppColors.success : AppColors.danger),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r.ourScore} – ${r.theirScore}', style: AppTextStyles.numeric(primary, size: 16)),
                        Text('${r.difficulty.label} · ${r.rounds} rounds', style: AppTextStyles.caption(muted)),
                      ],
                    ),
                  ),
                  Text(
                    '${_months[r.playedAt.month - 1]} ${r.playedAt.day}',
                    style: AppTextStyles.caption(muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
