import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Light + dark themes. Almost every stock Material widget the app uses
/// (dialogs, sheets, inputs, snackbars, menus, sliders, switches) is
/// styled here so screens don't have to restyle them one by one.
abstract class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;

    final Color onSurface = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color onSurfaceMuted = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final Color accent = isDark ? AppColors.gold : AppColors.navy;
    final Color hairline = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final Color sheetColor = isDark ? AppColors.surfaceDark : Colors.white;

    final ColorScheme scheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: AppColors.navyDeep,
            secondary: AppColors.blue,
            onSecondary: Colors.white,
            surface: AppColors.cardSurfaceDark,
            onSurface: AppColors.textPrimaryDark,
            error: AppColors.danger,
            outline: Color(0x1FFFFFFF),
          )
        : const ColorScheme.light(
            primary: AppColors.navy,
            onPrimary: Colors.white,
            secondary: AppColors.gold,
            onSecondary: AppColors.navyDeep,
            surface: AppColors.cardSurfaceLight,
            onSurface: AppColors.textPrimaryLight,
            error: AppColors.danger,
            outline: Color(0x14000000),
          );

    final ThemeData base = ThemeData(useMaterial3: true, brightness: brightness);
    final TextTheme textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    );

    final RoundedRectangleBorder rounded14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      scaffoldBackgroundColor: isDark ? AppColors.navyDeep : AppColors.surfaceLight,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerColor: hairline,
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: onSurface),

      // Transparent app bars: pages sit on AppBackground, which paints
      // the gradient behind them.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
      ),

      // Buttons ------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDeep,
          elevation: 0,
          shape: rounded14,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDeep,
          disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.25),
          shape: rounded14,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.goldLight : AppColors.navy,
          side: BorderSide(color: isDark ? AppColors.gold.withValues(alpha: 0.55) : AppColors.navy.withValues(alpha: 0.35)),
          shape: rounded14,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.gold : AppColors.navy,
          shape: rounded14,
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: onSurface),
      ),

      // Inputs -------------------------------------------------------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.manrope(color: onSurfaceMuted.withValues(alpha: 0.7)),
        border: inputBorder(hairline),
        enabledBorder: inputBorder(hairline),
        focusedBorder: inputBorder(AppColors.gold, 1.6),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, 1.6),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.gold,
        selectionHandleColor: AppColors.gold,
        selectionColor: AppColors.gold.withValues(alpha: 0.3),
      ),

      // Overlays -----------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: sheetColor,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: isDark ? AppColors.gold.withValues(alpha: 0.18) : hairline),
        ),
        titleTextStyle: GoogleFonts.playfairDisplay(fontSize: 21, fontWeight: FontWeight.w700, color: onSurface),
        contentTextStyle: GoogleFonts.manrope(fontSize: 14, height: 1.45, color: onSurfaceMuted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: sheetColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: onSurfaceMuted.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.surfaceDarkHigh : AppColors.navy,
        contentTextStyle: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.surfaceDarkHigh : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: hairline)),
        textStyle: GoogleFonts.manrope(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.manrope(fontSize: 12, color: Colors.white),
      ),

      // Controls -----------------------------------------------------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.navyDeep : (isDark ? Colors.white70 : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.gold
              : (isDark ? Colors.white.withValues(alpha: 0.14) : Colors.black.withValues(alpha: 0.18)),
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.10),
        thumbColor: AppColors.goldLight,
        overlayColor: AppColors.gold.withValues(alpha: 0.16),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.gold,
        linearTrackColor: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
        circularTrackColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
        side: BorderSide(color: hairline),
        labelStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
        shape: const StadiumBorder(),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
