import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Quiet companion to [PrimaryButton]: a glass pill with a gold hairline.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool enabled = onPressed != null;
    final Color fg = (isDark ? AppColors.goldLight : AppColors.navy).withValues(alpha: enabled ? 1 : 0.4);
    final BorderRadius br = BorderRadius.circular(AppRadius.md + 2);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: br,
        border: Border.all(
          color: (isDark ? AppColors.gold : AppColors.navy).withValues(alpha: enabled ? 0.5 : 0.18),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: br,
        child: InkWell(
          onTap: onPressed,
          borderRadius: br,
          splashColor: AppColors.gold.withValues(alpha: 0.14),
          child: SizedBox(
            width: double.infinity,
            height: 50.h,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19.sp, color: fg),
                      SizedBox(width: AppSpacing.sm),
                    ],
                    Text(label, maxLines: 1, softWrap: false, style: AppTextStyles.button(fg)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
