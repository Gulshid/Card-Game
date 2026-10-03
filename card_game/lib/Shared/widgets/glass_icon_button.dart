import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';

/// Round frosted icon button used in headers and over the game table.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
    this.size = 42,
    this.color,
    this.forceDark = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  /// Always draw the dark-glass look (for use over the felt table).
  final bool forceDark;

  @override
  Widget build(BuildContext context) {
    final bool isDark = forceDark || Theme.of(context).brightness == Brightness.dark;
    final Color fg = color ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    final Widget button = Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: forceDark ? Colors.black.withValues(alpha: 0.32) : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06)),
        boxShadow: isDark ? null : AppShadows.soft(false),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Icon(icon, size: (size * 0.48).sp, color: fg),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
