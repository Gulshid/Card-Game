import 'dart:ui' show ImageFilter;

import 'package:card_game/core/constant/app_dimensions.dart';
import 'package:card_game/core/theme/app_colors.dart';
import 'package:card_game/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Modal bid picker shown when it becomes the human's turn to bid.
/// A bid of 0 is set apart and labeled "Nil" since it means something
/// different from every other bid.
class BidOverlay extends StatelessWidget {
  const BidOverlay({required this.onBid, super.key});

  final ValueChanged<int> onBid;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 20.w),
          padding: EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1A2A50), Color(0xFF0E1830)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.30)),
            boxShadow: AppShadows.soft(true),
          ),
          // Transparent Material so the Ink-based buttons below paint
          // above this card's own gradient instead of being hidden by it.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('YOUR BID', style: AppTextStyles.overline(AppColors.gold)),
              SizedBox(height: 6.h),
              Text('How many tricks?', style: AppTextStyles.title(Colors.white)),
              SizedBox(height: AppSpacing.md),
              _NilButton(onTap: () => onBid(0)),
              SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.10))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
                    child: Text('OR PICK A NUMBER', style: AppTextStyles.overline(Colors.white38)),
                  ),
                  Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.10))),
                ],
              ),
              SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (int bid = 1; bid <= 13; bid++) _BidTile(bid: bid, onTap: () => onBid(bid)),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _NilButton extends StatelessWidget {
  const _NilButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(AppRadius.md);
    return Ink(
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.10),
        borderRadius: br,
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        splashColor: AppColors.gold.withValues(alpha: 0.2),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.block_rounded, color: AppColors.goldLight, size: 22.sp),
              SizedBox(width: AppSpacing.md - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nil', style: AppTextStyles.h2(AppColors.goldLight)),
                    Text('Take no tricks for a big bonus', style: AppTextStyles.caption(Colors.white60)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.gold, size: 22.sp),
            ],
          ),
        ),
      ),
    );
  }
}

class _BidTile extends StatelessWidget {
  const _BidTile({required this.bid, required this.onTap});

  final int bid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(AppRadius.md);
    return Ink(
      width: 46.w,
      height: 46.w,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A3E70), Color(0xFF1B2A52)],
        ),
        borderRadius: br,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        splashColor: AppColors.gold.withValues(alpha: 0.3),
        child: Center(child: Text('$bid', style: AppTextStyles.numeric(Colors.white, size: 18))),
      ),
    );
  }
}
