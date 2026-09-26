import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// App-branded loading spinner — always gold, regardless of theme,
/// so it reads consistently over both light and dark (and, later,
/// the felt-green table).
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.gold),
    );
  }
}
