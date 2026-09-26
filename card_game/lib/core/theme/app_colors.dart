import 'package:flutter/material.dart';

/// Central color palette. Every screen pulls from here — never a raw
/// hex literal in feature code. Matches the navy/gold direction agreed
/// in the visual mockups.
abstract class AppColors {
  // Brand
  static const Color navy = Color(0xFF12213B);
  static const Color navyDeep = Color(0xFF0B1526);
  static const Color blue = Color(0xFF2451B5);
  static const Color gold = Color(0xFFC79A3D);
  static const Color goldLight = Color(0xFFEFD9A0);

  // Table felt (used behind the game table screen, Phase 05)
  static const Color felt = Color(0xFF0F3D2C);

  // Surfaces
  static const Color surfaceLight = Color(0xFFF3F5FA);
  static const Color surfaceDark = Color(0xFF1B2A4D);
  static const Color cardSurfaceLight = Colors.white;
  static const Color cardSurfaceDark = Color(0xFF16233F);

  // Text
  static const Color textPrimaryLight = Color(0xFF1B1F27);
  static const Color textSecondaryLight = Color(0xFF5A6472);
  static const Color textPrimaryDark = Color(0xFFF3F5FA);
  static const Color textSecondaryDark = Color(0xFFA9B4CC);

  // Semantic
  static const Color success = Color(0xFF1E8E5A);
  static const Color danger = Color(0xFFD85A30);
  static const Color warning = Color(0xFFC79A3D);

  // Suit colors (used by the card widget in later phases)
  static const Color suitRed = Color(0xFFD85A30);
  static const Color suitBlack = Color(0xFF12213B);
}
