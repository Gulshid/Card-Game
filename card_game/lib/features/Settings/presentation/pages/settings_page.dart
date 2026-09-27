import 'package:card_game/Shared/widgets/app_surface.dart';
import 'package:card_game/Shared/widgets/settings_toggle_row.dart';
import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../bloc/settings_cubit.dart';
import '../../bloc/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settings) {
            final ThemeMode themeMode = context.watch<ThemeCubit>().state;
            final settingsCubit = context.read<SettingsCubit>();
            final themeCubit = context.read<ThemeCubit>();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Audio', style: AppTextStyles.h2(Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: AppSpacing.sm),
                AppSurface(
                  child: Column(
                    children: [
                      SettingsToggleRow(
                        label: 'Music',
                        value: settings.musicOn,
                        onChanged: (v) => settingsCubit.setMusicOn(value: v),
                      ),
                      SettingsToggleRow(
                        label: 'Sound effects',
                        value: settings.sfxOn,
                        onChanged: (v) => settingsCubit.setSfxOn(value: v),
                      ),
                      SettingsToggleRow(
                        label: 'Haptics',
                        value: settings.hapticsOn,
                        onChanged: (v) => settingsCubit.setHapticsOn(value: v),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.lg),
                Text('Appearance', style: AppTextStyles.h2(Theme.of(context).colorScheme.onSurface)),
                SizedBox(height: AppSpacing.sm),
                AppSurface(
                  child: SettingsToggleRow(
                    label: 'Dark theme',
                    value: themeMode == ThemeMode.dark,
                    onChanged: (v) => themeCubit.setThemeMode(v ? ThemeMode.dark : ThemeMode.light),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
