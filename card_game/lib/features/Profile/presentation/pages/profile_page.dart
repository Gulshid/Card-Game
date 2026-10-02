import 'package:card_game/Shared/widgets/app_surface.dart';
import 'package:card_game/Shared/widgets/loading_indicator.dart';
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

/// Avatar + name, lifetime stats, achievements, card-back picker and
/// recent matches — all bound to [ProfileCubit].
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _confirmReset(context),
            itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Reset progress'))],
          ),
        ],
      ),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (!state.isLoaded) return const Center(child: AppLoadingIndicator());
          return ListView(
            padding: EdgeInsets.all(AppSpacing.lg),
            children: [
              _Header(profile: state.profile),
              SizedBox(height: AppSpacing.lg),
              _StatsGrid(state: state),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Achievements'),
              SizedBox(height: AppSpacing.sm),
              for (final Achievement a in Achievement.values) _AchievementRow(achievement: a, state: state),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Card backs'),
              SizedBox(height: AppSpacing.sm),
              _CardBackPicker(state: state),
              SizedBox(height: AppSpacing.lg),
              _SectionTitle('Recent matches'),
              SizedBox(height: AppSpacing.sm),
              _History(history: state.history),
            ],
          );
        },
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
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.resetProgress();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.h2(Theme.of(context).colorScheme.onSurface));
  }
}

// ---- Header -------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final Color onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        GestureDetector(
          onTap: () => _pickAvatar(context),
          child: Stack(
            children: [
              ProfileAvatar(avatarId: profile.avatarId, radius: 36),
              const Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.gold,
                  child: Icon(Icons.edit, size: 12, color: AppColors.navy),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(profile.name, style: AppTextStyles.h1(onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          tooltip: 'Edit name',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _editName(context),
        ),
      ],
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
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Wrap(
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
                        width: 2,
                      ),
                    ),
                    child: ProfileAvatar(avatarId: i, radius: 26),
                  ),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.state});

  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final s = state.stats;
    final String winRate = '${(s.winRate * 100).round()}%';

    Widget row(List<(String, String)> items) => Row(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(value: items[i].$1, label: items[i].$2)),
            ],
          ],
        );

    return Column(
      children: [
        row([('${s.gamesPlayed}', 'Played'), ('${s.wins}', 'Wins'), ('${s.losses}', 'Losses')]),
        SizedBox(height: AppSpacing.sm),
        row([(winRate, 'Win rate'), ('${s.currentStreak}', 'Streak'), ('${s.bestStreak}', 'Best streak')]),
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color dim = scheme.onSurface.withValues(alpha: 0.45);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppSurface(
        child: Row(
          children: [
            Icon(unlocked ? achievement.icon : Icons.lock_outline, color: unlocked ? AppColors.gold : dim),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: AppTextStyles.bodyStrong(unlocked ? scheme.onSurface : dim),
                  ),
                  Text(achievement.description, style: AppTextStyles.caption(dim)),
                ],
              ),
            ),
            Text(
              '${achievement.reward.label} back',
              style: AppTextStyles.caption(unlocked ? AppColors.gold : dim),
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
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final CardBackStyle style in CardBackStyle.values)
          _CardBackChoice(
            style: style,
            selected: state.profile.cardBack == style,
            unlocked: state.isCardBackUnlocked(style),
          ),
      ],
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
    final Color onSurface = Theme.of(context).colorScheme.onSurface;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: unlocked ? 1 : 0.35,
                child: CardBackScope(
                  style: style,
                  child: PlayingCardView(card: null, faceDown: true, width: 44, selected: selected),
                ),
              ),
              if (!unlocked) const Icon(Icons.lock, color: Colors.white),
            ],
          ),
          const SizedBox(height: 4),
          Text(style.label, style: AppTextStyles.caption(selected ? AppColors.gold : onSurface)),
        ],
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    if (history.isEmpty) {
      return Text(
        'No matches yet — finish a game and it will show up here.',
        style: AppTextStyles.body(scheme.onSurface.withValues(alpha: 0.6)),
      );
    }

    return Column(
      children: [
        for (final MatchRecord r in history)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppSurface(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (r.won ? AppColors.success : AppColors.danger).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      r.won ? 'WIN' : 'LOSS',
                      style: AppTextStyles.caption(r.won ? AppColors.success : AppColors.danger),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '${r.ourScore} – ${r.theirScore}  ·  ${r.difficulty.label}  ·  ${r.rounds} rounds',
                      style: AppTextStyles.body(scheme.onSurface),
                    ),
                  ),
                  Text(
                    '${_months[r.playedAt.month - 1]} ${r.playedAt.day}',
                    style: AppTextStyles.caption(scheme.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
