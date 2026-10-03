import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Section title with a small gold accent bar and an optional trailing
/// widget (a count, an action…).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 3.w,
          height: 16.h,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: AppTextStyles.overline(isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
                .copyWith(fontSize: 12.sp),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
