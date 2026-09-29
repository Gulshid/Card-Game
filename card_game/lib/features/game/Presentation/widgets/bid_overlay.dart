import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Modal bid picker shown when it becomes the human's turn to bid.
/// A bid of 0 is highlighted separately and labeled "Nil" since it means
/// something different from every other bid.
class BidOverlay extends StatelessWidget {
  const BidOverlay({required this.onBid, super.key});

  final ValueChanged<int> onBid;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        padding: EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('How many tricks?', style: AppTextStyles.h2(Colors.white)),
            SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onBid(0),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.gold),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
                child: const Text('Nil (bid 0)'),
              ),
            ),
            SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                for (int bid = 1; bid <= 13; bid++)
                  SizedBox(
                    width: 42.w,
                    height: 42.w,
                    child: ElevatedButton(
                      onPressed: () => onBid(bid),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceDark,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      ),
                      child: Text('$bid'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
