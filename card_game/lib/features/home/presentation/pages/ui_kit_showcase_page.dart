import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_surface.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/settings_toggle_row.dart';
import '../../../../shared/widgets/stat_tile.dart';

/// Internal-only screen (never shipped) that renders every shared
/// widget in both themes for visual QA. This is Phase 02's exit
/// criteria: if everything here looks right in light AND dark mode,
/// the design system is done.
class UiKitShowcasePage extends StatefulWidget {
  const UiKitShowcasePage({super.key});

  @override
  State<UiKitShowcasePage> createState() => _UiKitShowcasePageState();
}

class _UiKitShowcasePageState extends State<UiKitShowcasePage> {
  bool _toggleValue = true;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(title: const Text('UI kit showcase')),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Typography', style: AppTextStyles.h2(onSurface)),
          SizedBox(height: AppSpacing.sm),
          Text('Display', style: AppTextStyles.display(onSurface)),
          Text('Heading 1', style: AppTextStyles.h1(onSurface)),
          Text('Heading 2', style: AppTextStyles.h2(onSurface)),
          Text('Body text sample', style: AppTextStyles.body(onSurface)),
          Text('Caption text sample', style: AppTextStyles.caption(onSurface)),
          SizedBox(height: AppSpacing.xl),

          Text('Buttons', style: AppTextStyles.h2(onSurface)),
          SizedBox(height: AppSpacing.sm),
          const PrimaryButton(label: 'Primary action', onPressed: _noop),
          SizedBox(height: AppSpacing.sm),
          const PrimaryButton(label: 'Loading state', isLoading: true, onPressed: null),
          SizedBox(height: AppSpacing.xl),

          Text('Surfaces', style: AppTextStyles.h2(onSurface)),
          SizedBox(height: AppSpacing.sm),
          AppSurface(
            child: Text('AppSurface with default padding', style: AppTextStyles.body(onSurface)),
          ),
          SizedBox(height: AppSpacing.xl),

          Text('Stat tiles', style: AppTextStyles.h2(onSurface)),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(child: StatTile(value: '184', label: 'Wins')),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(value: '62%', label: 'Win rate')),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(value: '9', label: 'Streak')),
            ],
          ),
          SizedBox(height: AppSpacing.xl),

          Text('Settings row', style: AppTextStyles.h2(onSurface)),
          SizedBox(height: AppSpacing.sm),
          AppSurface(
            child: SettingsToggleRow(
              label: 'Example toggle',
              value: _toggleValue,
              onChanged: (v) => setState(() => _toggleValue = v),
            ),
          ),
          SizedBox(height: AppSpacing.xl),

          Text('Loading indicator', style: AppTextStyles.h2(onSurface)),
          SizedBox(height: AppSpacing.sm),
          const AppLoadingIndicator(),
          SizedBox(height: AppSpacing.xl),

          Text('Color swatches', style: AppTextStyles.h2(onSurface)),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: const [
              _Swatch(color: AppColors.navy, label: 'navy'),
              _Swatch(color: AppColors.gold, label: 'gold'),
              _Swatch(color: AppColors.blue, label: 'blue'),
              _Swatch(color: AppColors.felt, label: 'felt'),
              _Swatch(color: AppColors.success, label: 'success'),
              _Swatch(color: AppColors.danger, label: 'danger'),
            ],
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48.w,
          height: 48.w,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.sm)),
        ),
        SizedBox(height: 4.h),
        Text(label, style: AppTextStyles.caption(Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }
}
