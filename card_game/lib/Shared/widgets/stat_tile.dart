import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'app_surface.dart';

/// Small labeled number — e.g. "184 / WINS". Used on Home, Profile and
/// the online lobby. The value is drawn in a gold gradient on dark
/// themes and a deep gold on light.
class StatTile extends StatelessWidget {
  const StatTile({required this.value, required this.label, super.key, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color muted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final Widget number = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.numeric(isDark ? Colors.white : AppColors.goldOnLight, size: 24),
    );

    return AppSurface(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16.sp, color: AppColors.goldText(context).withValues(alpha: 0.9)),
            SizedBox(height: 6.h),
          ],
          isDark
              ? ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (rect) => AppColors.goldGradient.createShader(rect),
                  child: number,
                )
              : number,
          SizedBox(height: 4.h),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.overline(muted),
          ),
        ],
      ),
    );
  }
}
