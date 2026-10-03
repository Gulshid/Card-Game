import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A themed, elevated container — the base for every card-like block
/// in the app that is *not* a playing card (stat tiles, settings
/// rows, banners).
///
/// Dark mode: a subtle "glass" gradient with a hairline border.
/// Light mode: a clean white panel with a soft shadow.
/// Set [highlight] for a gold-edged, glowing variant (e.g. "resume").
class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.highlight = false,
    this.gradient,
    this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool highlight;

  /// Overrides the default fill (e.g. a hero gradient).
  final Gradient? gradient;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final BorderRadius br = BorderRadius.circular(radius ?? AppRadius.lg);

    final Gradient? fill = gradient ??
        (isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.075),
                  Colors.white.withValues(alpha: 0.025),
                ],
              )
            : null);

    final Widget inner = Padding(padding: padding ?? EdgeInsets.all(AppSpacing.md), child: child);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark.withValues(alpha: 0.55) : Colors.white,
        gradient: fill,
        borderRadius: br,
        border: Border.all(
          color: highlight
              ? AppColors.gold.withValues(alpha: 0.65)
              : (isDark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.06)),
          width: highlight ? 1.3 : 1,
        ),
        boxShadow: highlight ? AppShadows.goldGlow(0.18) : (isDark ? null : AppShadows.soft(false)),
      ),
      child: onTap == null
          ? inner
          : Material(
              color: Colors.transparent,
              borderRadius: br,
              child: InkWell(
                onTap: onTap,
                borderRadius: br,
                splashColor: AppColors.gold.withValues(alpha: 0.12),
                highlightColor: AppColors.gold.withValues(alpha: 0.06),
                child: inner,
              ),
            ),
    );
  }
}
