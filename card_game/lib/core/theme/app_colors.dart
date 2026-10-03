import 'package:flutter/material.dart';

/// Central color palette — "Royal Noir".
///
/// Deep midnight blues, a warm champagne-gold accent, and an emerald
/// baize for the card table. Every screen pulls from here; feature code
/// never uses a raw hex literal.
///
/// All names from the previous palette are kept (their values were
/// refined), so existing call sites keep compiling.
abstract class AppColors {
  // ---- Brand ---------------------------------------------------------
  static const Color navy = Color(0xFF111C33);
  static const Color navyDeep = Color(0xFF070B14);
  static const Color midnight = Color(0xFF0C1424);
  static const Color blue = Color(0xFF3B6FE0);
  static const Color blueSoft = Color(0xFF6C93F0);

  static const Color gold = Color(0xFFD4A94F);
  static const Color goldLight = Color(0xFFF2D58B);
  static const Color goldDeep = Color(0xFF9C7425);

  // ---- Table baize (the card table) -----------------------------------
  static const Color felt = Color(0xFF0E4A36);
  static const Color feltLight = Color(0xFF176B4D);
  static const Color feltDeep = Color(0xFF05201A);

  // ---- Surfaces -------------------------------------------------------
  static const Color surfaceLight = Color(0xFFF3F4F9);
  static const Color surfaceDark = Color(0xFF16233F);
  static const Color surfaceDarkHigh = Color(0xFF1E2E52);
  static const Color cardSurfaceLight = Colors.white;
  static const Color cardSurfaceDark = Color(0xFF16233F);

  // ---- Text -----------------------------------------------------------
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF5B6575);
  static const Color textPrimaryDark = Color(0xFFF4F6FB);
  static const Color textSecondaryDark = Color(0xFFA9B4CC);

  /// Gold that stays readable as *text* on a light background.
  static const Color goldOnLight = Color(0xFF8A6417);

  // ---- Semantic -------------------------------------------------------
  static const Color success = Color(0xFF2FBF86);
  static const Color danger = Color(0xFFE5604A);
  static const Color warning = Color(0xFFD4A94F);

  // ---- Suits ----------------------------------------------------------
  static const Color suitRed = Color(0xFFD0342C);
  static const Color suitBlack = Color(0xFF0F1A2E);

  // ---- Gradients ------------------------------------------------------
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDeep],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient backgroundDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F1B36), Color(0xFF0A1226), navyDeep],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient backgroundLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8F9FD), Color(0xFFEEF0F7)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF223A72), Color(0xFF14224A), Color(0xFF0D1730)],
  );

  static const RadialGradient feltGradient = RadialGradient(
    center: Alignment(0, -0.15),
    radius: 1.05,
    colors: [feltLight, felt, feltDeep],
    stops: [0.0, 0.55, 1.0],
  );

  /// Gold that reads on the current theme (bright on dark, deep on light).
  static Color goldText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? gold : goldOnLight;
}

/// Shared shadow recipes so depth looks the same everywhere.
abstract class AppShadows {
  static List<BoxShadow> soft(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> goldGlow([double strength = 0.35]) => [
        BoxShadow(
          color: AppColors.gold.withValues(alpha: strength),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ];
}
