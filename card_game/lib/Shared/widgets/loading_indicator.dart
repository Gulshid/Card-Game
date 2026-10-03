import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// App-branded loading spinner — always gold, regardless of theme, so it
/// reads consistently over light, dark and the felt-green table.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.6,
        strokeCap: StrokeCap.round,
        color: AppColors.gold,
        backgroundColor: AppColors.gold.withValues(alpha: 0.18),
      ),
    );
  }
}
