import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// The app's single primary call-to-action: a champagne-gold gradient
/// button with a soft glow and a press-down animation. Reserved for the
/// one primary action per screen — use [SecondaryButton] for the rest.
///
/// Long labels scale down to fit the button's width instead of
/// overflowing (the content is wrapped in a `FittedBox`).
class PrimaryButton extends StatefulWidget {
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
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final bool tappable = enabled && !widget.isLoading;
    final BorderRadius br = BorderRadius.circular(AppRadius.md + 2);

    final Widget content = widget.isLoading
        ? SizedBox(
            width: 20.w,
            height: 20.w,
            child: const CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.navyDeep),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 20.sp, color: AppColors.navyDeep),
                  SizedBox(width: AppSpacing.sm),
                ],
                Text(widget.label, maxLines: 1, softWrap: false, style: AppTextStyles.button(AppColors.navyDeep)),
              ],
            ),
          );

    return AnimatedScale(
      scale: _pressed && tappable ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.goldGradient : null,
          color: enabled ? null : AppColors.gold.withValues(alpha: 0.25),
          borderRadius: br,
          boxShadow: enabled ? AppShadows.goldGlow(0.30) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: br,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tappable ? widget.onPressed : null,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            splashColor: Colors.white.withValues(alpha: 0.28),
            highlightColor: Colors.white.withValues(alpha: 0.10),
            child: Stack(
              children: [
                // Glossy top highlight.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 24.h,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: enabled ? 0.30 : 0.0),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Center(child: content),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
