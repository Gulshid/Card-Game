import 'package:card_game/Shared/widgets/app_background.dart';
import 'package:card_game/Shared/widgets/app_surface.dart';
import 'package:card_game/Shared/widgets/section_header.dart';
import 'package:card_game/Shared/widgets/settings_toggle_row.dart';
import 'package:card_game/Shared/widgets/spade_mark.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../bloc/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Settings')),
        body: SafeArea(
          top: false,
          child: BlocBuilder<SettingsCubit, SettingsState>(
            builder: (context, settings) {
              final ThemeMode themeMode = context.watch<ThemeCubit>().state;
              final SettingsCubit settingsCubit = context.read<SettingsCubit>();
              final ThemeCubit themeCubit = context.read<ThemeCubit>();

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                children: [
                  const SectionHeader('Audio & feel'),
                  SizedBox(height: AppSpacing.sm + 2),
                  AppSurface(
                    child: Column(
                      children: [
                        SettingsToggleRow(
                          icon: Icons.music_note_rounded,
                          label: 'Music',
                          value: settings.musicOn,
                          onChanged: (v) => settingsCubit.setMusicOn(value: v),
                        ),
                        _VolumeSlider(
                          enabled: settings.musicOn,
                          value: settings.musicVolume,
                          onChanged: settingsCubit.setMusicVolume,
                        ),
                        const _Divider(),
                        SettingsToggleRow(
                          icon: Icons.graphic_eq_rounded,
                          label: 'Sound effects',
                          value: settings.sfxOn,
                          onChanged: (v) => settingsCubit.setSfxOn(value: v),
                        ),
                        _VolumeSlider(
                          enabled: settings.sfxOn,
                          value: settings.sfxVolume,
                          onChanged: settingsCubit.setSfxVolume,
                        ),
                        const _Divider(),
                        SettingsToggleRow(
                          icon: Icons.vibration_rounded,
                          label: 'Haptics',
                          subtitle: 'Feel every card you play',
                          value: settings.hapticsOn,
                          onChanged: (v) => settingsCubit.setHapticsOn(value: v),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg),
                  const SectionHeader('Appearance'),
                  SizedBox(height: AppSpacing.sm + 2),
                  Row(
                    children: [
                      Expanded(
                        child: _ThemeChoice(
                          icon: Icons.brightness_auto_rounded,
                          label: 'System',
                          selected: themeMode == ThemeMode.system,
                          onTap: () => themeCubit.setThemeMode(ThemeMode.system),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ThemeChoice(
                          icon: Icons.light_mode_rounded,
                          label: 'Light',
                          selected: themeMode == ThemeMode.light,
                          onTap: () => themeCubit.setThemeMode(ThemeMode.light),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ThemeChoice(
                          icon: Icons.dark_mode_rounded,
                          label: 'Dark',
                          selected: themeMode == ThemeMode.dark,
                          onTap: () => themeCubit.setThemeMode(ThemeMode.dark),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.xl),
                  const _Footer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.symmetric(vertical: 8.h), child: const Divider());
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.enabled, required this.value, required this.onChanged});

  final bool enabled;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Row(
          children: [
            Icon(Icons.volume_down_rounded, size: 18.sp, color: muted),
            Expanded(child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged)),
            SizedBox(
              width: 38.w,
              child: Text(
                '${(value * 100).round()}%',
                textAlign: TextAlign.right,
                style: AppTextStyles.caption(muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return AppSurface(
      onTap: onTap,
      highlight: selected,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Column(
        children: [
          Icon(icon, size: 24.sp, color: selected ? AppColors.goldText(context) : muted),
          SizedBox(height: 8.h),
          Text(label, style: AppTextStyles.bodyStrong(selected ? primary : muted)),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Column(
      children: [
        SpadeMark(size: 22.w, color: muted.withValues(alpha: 0.5)),
        SizedBox(height: 8.h),
        Text('Spades Royale', style: AppTextStyles.bodyStrong(muted)),
        Text('Crafted for card-table nights', style: AppTextStyles.caption(muted.withValues(alpha: 0.7))),
      ],
    );
  }
}
