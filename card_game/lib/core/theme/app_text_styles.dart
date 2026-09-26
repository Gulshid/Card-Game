import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type ramp. Sizes are `.sp` (ScreenUtil) so they scale with the
/// design-size bucket the same way spacing does. Built as functions
/// (not const fields) because `.sp` needs `ScreenUtil` to be
/// initialized first, which only happens inside `ScreenUtilInit`.
abstract class AppTextStyles {
  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
  }) {
    return GoogleFonts.manrope(fontSize: size, fontWeight: weight, color: color);
  }

  static TextStyle display(Color color) => _base(size: 30.sp, weight: FontWeight.w700, color: color);
  static TextStyle h1(Color color) => _base(size: 22.sp, weight: FontWeight.w700, color: color);
  static TextStyle h2(Color color) => _base(size: 18.sp, weight: FontWeight.w600, color: color);
  static TextStyle body(Color color) => _base(size: 14.sp, weight: FontWeight.w400, color: color);
  static TextStyle bodyStrong(Color color) => _base(size: 14.sp, weight: FontWeight.w600, color: color);
  static TextStyle caption(Color color) => _base(size: 11.sp, weight: FontWeight.w400, color: color);
  static TextStyle button(Color color) => _base(size: 15.sp, weight: FontWeight.w600, color: color);

  // Convenience shorthands bound to the brand palette, used outside
  // of Theme-aware contexts (e.g. inside the felt-green game table).
  static TextStyle get goldLabel => _base(size: 12.sp, weight: FontWeight.w600, color: AppColors.gold);
}
