import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Type ramp: **Playfair Display** (an elegant high-contrast serif) for
/// display/headline moments, **Manrope** for everything functional.
///
/// Sizes are `.sp` (ScreenUtil). Built as functions (not const fields)
/// because `.sp` needs `ScreenUtil` initialised first.
abstract class AppTextStyles {
  static TextStyle _sans({
    required double size,
    required FontWeight weight,
    required Color color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle _serif({
    required double size,
    required FontWeight weight,
    required Color color,
    double? letterSpacing,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.15,
    );
  }

  // ---- Core ramp (signatures unchanged) -------------------------------
  static TextStyle display(Color color) => _serif(size: 32.sp, weight: FontWeight.w800, color: color);
  static TextStyle h1(Color color) => _serif(size: 24.sp, weight: FontWeight.w700, color: color);
  static TextStyle h2(Color color) => _sans(size: 17.sp, weight: FontWeight.w700, color: color);
  static TextStyle body(Color color) => _sans(size: 14.sp, weight: FontWeight.w500, color: color, height: 1.4);
  static TextStyle bodyStrong(Color color) => _sans(size: 14.sp, weight: FontWeight.w700, color: color);
  static TextStyle caption(Color color) => _sans(size: 11.5.sp, weight: FontWeight.w500, color: color, height: 1.3);
  static TextStyle button(Color color) =>
      _sans(size: 15.sp, weight: FontWeight.w800, color: color, letterSpacing: 0.3);

  // ---- New -------------------------------------------------------------

  /// Tiny, tracked-out label ("OVERLINE"). Pass the text already uppercased.
  static TextStyle overline(Color color) =>
      _sans(size: 10.5.sp, weight: FontWeight.w800, color: color, letterSpacing: 1.6);

  /// Serif title for cards and sheets.
  static TextStyle title(Color color) => _serif(size: 20.sp, weight: FontWeight.w700, color: color);

  /// Tabular, heavy numerals for scores and stats (digits don't jitter
  /// while they count up).
  static TextStyle numeric(Color color, {double size = 22}) => _sans(
        size: size.sp,
        weight: FontWeight.w800,
        color: color,
        height: 1.1,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  // Convenience shorthand bound to the brand palette, used outside of
  // Theme-aware contexts (e.g. inside the felt-green game table).
  static TextStyle get goldLabel => _sans(size: 12.sp, weight: FontWeight.w700, color: AppColors.gold);
}
