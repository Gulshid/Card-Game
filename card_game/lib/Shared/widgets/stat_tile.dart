import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_surface.dart';

/// Small labeled number, used on the Profile screen (Phase 09) and
/// the UI kit showcase. e.g. "184 / Wins".
class StatTile extends StatelessWidget {
  const StatTile({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AppSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTextStyles.h1(AppColors.gold)),
          Text(
            label,
            style: AppTextStyles.caption(isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}
