import 'package:card_game/features/profile/domain/models/achievements.dart';
import 'package:flutter/material.dart';

/// Visual identity for each card back. Kept out of the domain enum so the
/// domain layer stays free of Flutter imports.
extension CardBackStyleTheme on CardBackStyle {
  Color get base {
    switch (this) {
      case CardBackStyle.classic:
        return const Color(0xFF2451B5); // identical to the pre-Phase-09 back
      case CardBackStyle.crimson:
        return const Color(0xFF8E1B2D);
      case CardBackStyle.emerald:
        return const Color(0xFF14724A);
      case CardBackStyle.midnight:
        return const Color(0xFF1A1033);
      case CardBackStyle.royal:
        return const Color(0xFF4B2A8A);
      case CardBackStyle.slate:
        return const Color(0xFF3B4656);
      case CardBackStyle.sunset:
        return const Color(0xFFB4532A);
    }
  }

  Color get accent {
    switch (this) {
      case CardBackStyle.classic:
        return Colors.white;
      case CardBackStyle.royal:
      case CardBackStyle.midnight:
        return const Color(0xFFEFD9A0);
      case CardBackStyle.crimson:
      case CardBackStyle.emerald:
      case CardBackStyle.slate:
      case CardBackStyle.sunset:
        return const Color(0xFFFFE9C2);
    }
  }

  IconData get icon {
    switch (this) {
      case CardBackStyle.classic:
        return Icons.style_outlined;
      case CardBackStyle.crimson:
        return Icons.diamond_outlined;
      case CardBackStyle.emerald:
        return Icons.eco_outlined;
      case CardBackStyle.midnight:
        return Icons.nightlight_outlined;
      case CardBackStyle.royal:
        return Icons.workspace_premium_outlined;
      case CardBackStyle.slate:
        return Icons.shield_outlined;
      case CardBackStyle.sunset:
        return Icons.wb_twilight;
    }
  }
}

extension AchievementTheme on Achievement {
  IconData get icon {
    switch (this) {
      case Achievement.firstWin:
        return Icons.emoji_events_outlined;
      case Achievement.hotStreak:
        return Icons.local_fire_department_outlined;
      case Achievement.nilMaster:
        return Icons.exposure_zero;
      case Achievement.giantSlayer:
        return Icons.psychology_outlined;
      case Achievement.veteran:
        return Icons.military_tech_outlined;
      case Achievement.domination:
        return Icons.bolt;
    }
  }
}
