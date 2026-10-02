import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// The app's single primary call-to-action button style ("Play",
/// "Confirm bid", "Save"). Secondary/tertiary actions should use a
/// plain `OutlinedButton`/`TextButton` via the theme instead of a new
/// widget — this one is reserved for the one primary action per screen.
///
/// Long labels scale down to fit the button's width instead of
/// overflowing (the content is wrapped in a `FittedBox`).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navy,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.5),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        child: isLoading
            ? SizedBox(
                width: 20.w,
                height: 20.w,
                child: const CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18.sp, color: AppColors.navy),
                      SizedBox(width: AppSpacing.sm),
                    ],
                    Text(label, maxLines: 1, softWrap: false, style: AppTextStyles.button(AppColors.navy)),
                  ],
                ),
              ),
      ),
    );
  }
}