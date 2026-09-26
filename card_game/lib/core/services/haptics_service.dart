import 'dart:async';

import 'package:flutter/services.dart';

/// Wraps Flutter's `HapticFeedback` behind a settings-aware gate so
/// call sites (e.g. "card played", "illegal move") never have to
/// check the user's preference themselves.
class HapticsService {
  bool enabled = true;

  void light() {
    if (enabled) unawaited(HapticFeedback.lightImpact());
  }

  void medium() {
    if (enabled) unawaited(HapticFeedback.mediumImpact());
  }

  void selection() {
    if (enabled) unawaited(HapticFeedback.selectionClick());
  }

  void notification() {
    if (enabled) unawaited(HapticFeedback.vibrate());
  }
}
